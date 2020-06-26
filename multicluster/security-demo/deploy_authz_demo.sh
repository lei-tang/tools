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

source ./setup_security_demo.sh

# Before running the security demo in this script:
# 1) The master+master control planes should have been installed in two clusters
# with contexts ${CTX_1} and ${CTX_2}, respectively. ${CTX_1} and ${CTX_2} are
# defined in the script.
# 2) The authentication for the project hosting the two clusters should have been conducted successfully, e.g., through
# gcloud auth login
# gcloud config set project ${PROJECT_ID}
# 3) The environmental variables in ./setup_security_demo.sh must be configured
# based on your multicluster installation before running the test.

# Exit immediately for non zero status
set -e
# Check unset variables
set -u
# Print commands
set -x

WD=$(dirname "$0")
WD=$(cd "$WD"; pwd)
mkdir -p ${WD}/asm-example-svc-1.6
cd ${WD}/asm-example-svc-1.6
pwd

# gcloud auth login
# gcloud config set project ${PROJECT_ID}

# Download package that contains example service deployment files.
# If you are testing a different ASM release, please replace the ASM release URL accordingly.
#gsutil cp gs://asm-staging-images/asm/istio-1.6.4-asm.8-linux-amd64.tar.gz .
#tar xzf istio-1.6.4-asm.8-linux-amd64.tar.gz
export ISTIO=$(pwd)/istio-1.6.4-asm.8

if [[ -z "${PROJECT_ID}" || -z "${CLUSTER_1}" || -z "${CLUSTER_2}" || -z "${LOCATION_1}" || -z "${LOCATION_2}" ]]; then
    echo "Error: PROJECT_ID, CLUSTER_1, CLUSTER_2, LOCATION_1, LOCATION_2 must be set."
    exit 1
fi
export CTX_1=gke_${PROJECT_ID}_${LOCATION_1}_${CLUSTER_1}
export CTX_2=gke_${PROJECT_ID}_${LOCATION_2}_${CLUSTER_2}
gcloud container clusters get-credentials ${CLUSTER_1} --zone ${LOCATION_1} --project ${PROJECT_ID}
gcloud container clusters get-credentials ${CLUSTER_2} --zone ${LOCATION_2} --project ${PROJECT_ID}

# In cluster 1 and 2, create namespaces authz-ns1 and authz-ns2. In cluster 1 and 2, deploy helloworld and sleep services in namespaces authz-ns1 and authz-ns2.
kubectl create --context=${CTX_1} namespace authz-ns1
kubectl label --context=${CTX_1} namespace authz-ns1 \
  istio-injection=enabled
kubectl create --context=${CTX_1} namespace authz-ns2
kubectl label --context=${CTX_1} namespace authz-ns2 \
  istio-injection=enabled
kubectl create --context=${CTX_1} \
  -f ${ISTIO}/samples/helloworld/helloworld.yaml -n authz-ns1
kubectl create --context=${CTX_1} \
  -f ${ISTIO}/samples/helloworld/helloworld.yaml -n authz-ns2
kubectl apply --context=${CTX_1} \
  -f ${ISTIO}/samples/sleep/sleep.yaml -n authz-ns1
kubectl apply --context=${CTX_1} \
  -f ${ISTIO}/samples/sleep/sleep.yaml -n authz-ns2

kubectl create --context=${CTX_2} namespace authz-ns1
kubectl label --context=${CTX_2} namespace authz-ns1 \
  istio-injection=enabled
kubectl create --context=${CTX_2} namespace authz-ns2
kubectl label --context=${CTX_2} namespace authz-ns2 \
  istio-injection=enabled
kubectl create --context=${CTX_2} \
  -f ${ISTIO}/samples/helloworld/helloworld.yaml -n authz-ns1
kubectl create --context=${CTX_2} \
  -f ${ISTIO}/samples/helloworld/helloworld.yaml -n authz-ns2
kubectl apply --context=${CTX_2} \
  -f ${ISTIO}/samples/sleep/sleep.yaml -n authz-ns1
kubectl apply --context=${CTX_2} \
  -f ${ISTIO}/samples/sleep/sleep.yaml -n authz-ns2

# Verify the helloworld and sleep deployments are ready
kubectl wait --context=${CTX_1} --for=condition=Ready --timeout=1200s pod --all -n authz-ns1
kubectl wait --context=${CTX_1} --for=condition=Ready --timeout=1200s pod --all -n authz-ns2
kubectl wait --context=${CTX_2} --for=condition=Ready --timeout=1200s pod --all -n authz-ns1
kubectl wait --context=${CTX_2} --for=condition=Ready --timeout=1200s pod --all -n authz-ns2
