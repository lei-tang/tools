#!/bin/bash

# Copyright 2020 Istio Authors

#   Licensed under the Apache License, Version 2.0 (the "License");
#   you may not use this file except in compliance with the License.
#   You may obtain a copy of the License at

#       http://www.apache.org/licenses/LICENSE-2.0

#   Unless required by applicable law or agreed to in writing, software
#   distributed under the License is distributed on an "AS IS" BASIS,
#   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#   See the License for the specific language governing permissions and
#   limitations under the License.

# collectResponsesWithRetries collect different responses from
# running a given command at most ${1} times with ${2} sleep between each run
# until the response size reaching the specified size ${3}.
# For example, collectResponsesWithRetries 10 1 4 myFunc param1 param2
# runs "myFunc param1 param2" up to 10 times with 1 second sleep in between,
# until the response size reaching 4.
collectResponsesWithRetries() {
    local max_retries=${1}
    local sleep_sec=${2}
    local size=${3}
    local n=0
    local k=""
    declare -A vals
    shift
    shift
    shift
    while (( $n < ${max_retries} ))
    do
      echo "RUNNING $*"
      k=$("${@}")
      vals["$k"]=1
      if (( "${#vals[@]}" >= size )); then
        break
      fi
      n=$(( n+1 ))
      echo "Tried $n times, sleeping ${sleep_sec} seconds and retrying..."
      sleep "${sleep_sec}"
    done
    if (( n == max_retries ))
    then
      die "$* does not have a response size ${size} after retrying ${max_retries} times."
    fi
    echo "Succeeded."
}

# Parameter 1: namespace
# Parameter 2: cluster context
# Parameter 3: expected container running status (e.g., 1/1, 2/2, and etc).
waitForPodsInContextReady() {
    echo "Waiting for pods to be ready in ${1} of context ${2} ..."
    withRetriesMaxTime 600 10 _waitForPodsInContextReady "${1}" "${2}" "${3}"
    echo "All pods ready."
}

_waitForPodsInContextReady() {
    pods_str=$(kubectl -n "${1}" --context="${2}" get pods | tail -n +2 )
    arr=()
    while read -r line; do
       arr+=("$line")
    done <<< "$pods_str"

    ready="true"
    for line in "${arr[@]}"; do
        if [[ ${line} != *"${3}"*"Running"* && ${line} != *"Completed"* ]]; then
            ready="false"
        fi
    done
    if [  "${ready}" = "true" ]; then
        return 0
    fi

    echo "${pods_str}"
    return 1
}

# withRetriesMaxTime retries the given command repeatedly with ${2} sleep between retries until ${1} seconds have elapsed.
# e.g. withRetries 300 60 myFunc param1 param2
#   runs "myFunc param1 param2" for up 300 seconds with 60 sec sleep in between.
withRetriesMaxTime() {
    local total_time_max=${1}
    local sleep_sec=${2}
    local start_time=${SECONDS}
    shift
    shift
    while (( SECONDS - start_time <  total_time_max )); do
      echo "RUNNING $*" ; "${@}" && break
      echo "Failed, sleeping ${sleep_sec} seconds and retrying..."
      sleep "${sleep_sec}"
    done

    if (( SECONDS - start_time >=  total_time_max )); then die "$* failed after retrying for ${total_time_max} seconds."; fi
    echo "Succeeded."
}
