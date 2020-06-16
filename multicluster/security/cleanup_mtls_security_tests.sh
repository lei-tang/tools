#!/usr/local/bin/bash

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

source ./setup_security_test.sh

# Exit immediately for non zero status
set -e
# Check unset variables
set -u
# Print commands
set -x

if [[ -z "${PROJECT_ID}" || -z "${MASTER_NAME01}" || -z "${MASTER_NAME02}" || -z "${MASTER_LOCATION01}" || -z "${MASTER_LOCATION02}" ]]; then
    echo "Error: PROJECT_ID, MASTER_NAME01, MASTER_NAME02, MASTER_LOCATION01, MASTER_LOCATION02 must be set."
    exit 1
fi
export CTX_1=gke_${PROJECT_ID}_${MASTER_LOCATION01}_${MASTER_NAME01}
export CTX_2=gke_${PROJECT_ID}_${MASTER_LOCATION02}_${MASTER_NAME02}
gcloud container clusters get-credentials ${MASTER_NAME01} --zone ${MASTER_LOCATION01} --project ${PROJECT_ID}
gcloud container clusters get-credentials ${MASTER_NAME02} --zone ${MASTER_LOCATION02} --project ${PROJECT_ID}

# Cleanup
kubectl delete --context=${CTX_1} namespace sample
kubectl delete --context=${CTX_2} namespace sample
