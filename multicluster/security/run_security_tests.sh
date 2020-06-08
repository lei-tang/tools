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

source ./util/util.sh

# Exit immediately for non zero status
set -e
# Check unset variables
set -u
# Print commands
set -x

# Before running the security tests in this script:
# 1) The master+master control planes should have been installed in two clusters
# with contexts ${CTX_1} and ${CTX_2}, respectively. ${CTX_1} and ${CTX_2} are
# defined in the script.
# 2) The authentication for the project hosting the two clusters should have been conducted successfully, e.g., through
# gcloud auth login
# gcloud config set project ${PROJECT_ID}
# 3) The following environmental variables must be set before running the script.
# The following is example commands to configure them.
# export PROJECT_ID=YOUR-MULTICLUSTER-PROJECT
# export MASTER_NAME01=master01
# export MASTER_LOCATION01=us-central1-a
# export MASTER_NAME02=master02
# export MASTER_LOCATION02=us-central1-a

if [[ -z "${PROJECT_ID}" || -z "${MASTER_NAME01}" || -z "${MASTER_NAME02}" || -z "${MASTER_LOCATION01}" || -z "${MASTER_LOCATION02}" ]]; then
    echo "Error: PROJECT_ID, MASTER_NAME01, MASTER_NAME02, MASTER_LOCATION01, MASTER_LOCATION02 must be set."
    exit 1
fi

WD=$(dirname "$0")
WD=$(cd "$WD"; pwd)

# After deploying master+master control planes, deploy example services.
mkdir -p ${WD}/asm-example-svc
cd ${WD}/asm-example-svc
pwd

# Download package that contains example service deployment files.
# Here Istio is istio-1.5.2-asm.0-linux.tar.gz. If you are testing
# a different Istio release, you need to change the version of Istio release.
# gsutil cp gs://asm-staging-images/asm/istio-1.5.2-asm.0-linux.tar.gz .
tar xzf istio-1.5.2-asm.0-linux.tar.gz
export ISTIO=${WD}/asm-example-svc/istio-1.5.2-asm.0

export CTX_1=gke_${PROJECT_ID}_${MASTER_LOCATION01}_${MASTER_NAME01}
export CTX_2=gke_${PROJECT_ID}_${MASTER_LOCATION02}_${MASTER_NAME02}

gcloud container clusters get-credentials ${MASTER_NAME01} --zone ${MASTER_LOCATION01} --project ${PROJECT_ID}
gcloud container clusters get-credentials ${MASTER_NAME02} --zone ${MASTER_LOCATION02} --project ${PROJECT_ID}

#kubectl create --context=${CTX_1} namespace sample
#kubectl label --context=${CTX_1} namespace sample \
#  istio-injection=enabled
#
#kubectl create --context=${CTX_2} namespace sample
#kubectl label --context=${CTX_2} namespace sample \
#  istio-injection=enabled
#
## Deploy helloworld and sleep services
#kubectl create --context=${CTX_1} \
#  -f ${ISTIO}/samples/helloworld/helloworld.yaml -n sample
#kubectl create --context=${CTX_2} \
#  -f ${ISTIO}/samples/helloworld/helloworld.yaml -n sample
#kubectl apply --context=${CTX_1} \
#  -f ${ISTIO}/samples/sleep/sleep.yaml -n sample
#kubectl apply --context=${CTX_2} \
#  -f ${ISTIO}/samples/sleep/sleep.yaml -n sample
#
## Verify the helloworld and sleep deployments are ready
#waitForPodsInContextReady sample ${CTX_1} "2/2"
#waitForPodsInContextReady sample ${CTX_2} "2/2"

# Verify cross-cluster load balancing from cluster 1.
collectResponsesWithRetries 10 0 4 kubectl exec --context=${CTX_1} -it -n sample -c sleep \
  $(kubectl get pod --context=${CTX_1} -n sample -l \
  app=sleep -o jsonpath='{.items[0].metadata.name}') -- curl \
  helloworld.sample:5000/hello

# Verify cross-cluster load balancing from cluster 2
collectResponsesWithRetries 10 0 4 kubectl exec --context=${CTX_2} -it -n sample -c sleep \
  $(kubectl get pod --context=${CTX_2} -n sample -l \
  app=sleep -o jsonpath='{.items[0].metadata.name}') -- curl \
  helloworld.sample:5000/hello

## Verify cross-cluster load balancing from cluster 1.
## Need to execute the following command multiple times and verify that
## the hello responses are from instances in both cluster 1 and 2.
#kubectl exec --context=${CTX_1} -it -n sample -c sleep \
#  $(kubectl get pod --context=${CTX_1} -n sample -l \
#  app=sleep -o jsonpath='{.items[0].metadata.name}') -- curl \
#  helloworld.sample:5000/hello
#
## The following is an example output that shows the responses are from # all instances from both cluster 1 and 2.
## helloworld-v1-6757db4ff5-9q2zz and helloworld-v2-85bc988875-br5tf are helloworld instances in cluster 1. Helloworld-v1-6757db4ff5-2jv76 and helloworld-v2-85bc988875-zt8kz are helloworld instances in cluster 2.
## Hello version: v1, instance: helloworld-v1-6757db4ff5-9q2zz
## Hello version: v2, instance: helloworld-v2-85bc988875-br5tf
## Hello version: v1, instance: helloworld-v1-6757db4ff5-2jv76
## Hello version: v2, instance: helloworld-v2-85bc988875-zt8kz
#
## Verify cross-cluster load balancing from cluster 2
## Need to execute the following command multiple times and verify that
## the hello responses are from both cluster 1 and 2.
#kubectl exec --context=${CTX_2} -it -n sample -c sleep \
#  $(kubectl get pod --context=${CTX_2} -n sample -l \
#  app=sleep -o jsonpath='{.items[0].metadata.name}') -- curl \
#  helloworld.sample:5000/hello
#
## The following is an example output that shows the responses are from # all instances from both cluster 1 and 2.
## Hello version: v1, instance: helloworld-v1-6757db4ff5-2jv76
## Hello version: v2, instance: helloworld-v2-85bc988875-zt8kz
## Hello version: v2, instance: helloworld-v2-85bc988875-zt8kz
## Hello version: v1, instance: helloworld-v1-6757db4ff5-9q2zz
## Hello version: v2, instance: helloworld-v2-85bc988875-br5tf


# Cleanup
# kubectl delete --context=${CTX_1} namespace sample
# kubectl delete --context=${CTX_2} namespace sample
# Wait 60 seconds for the cleanup
# sleep 60

