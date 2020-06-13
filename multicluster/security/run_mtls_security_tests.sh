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
source ./util/util.sh

# Before running the security tests in this script:
# 1) The master+master control planes should have been installed in two clusters
# with contexts ${CTX_1} and ${CTX_2}, respectively. ${CTX_1} and ${CTX_2} are
# defined in the script.
# 2) The authentication for the project hosting the two clusters should have been conducted successfully, e.g., through
# gcloud auth login
# gcloud config set project ${PROJECT_ID}
# 3) The environmental variables in ./setup_security_test.sh must be configured
# based on your multicluster installation before running the test.

# Exit immediately for non zero status
set -e
# Check unset variables
set -u
# Print commands
set -x

WD=$(dirname "$0")
WD=$(cd "$WD"; pwd)
mkdir -p ${WD}/asm-example-svc
cd ${WD}/asm-example-svc
pwd
# Download package that contains example service deployment files.
# Here Istio is istio-1.5.2-asm.0-linux.tar.gz. If you are testing
# a different Istio release, you need to change the version of Istio release.
# gsutil cp gs://asm-staging-images/asm/istio-1.5.2-asm.0-linux.tar.gz .
tar xzf istio-1.5.2-asm.0-linux.tar.gz
export ISTIO=${WD}/asm-example-svc/istio-1.5.2-asm.0

if [[ -z "${PROJECT_ID}" || -z "${MASTER_NAME01}" || -z "${MASTER_NAME02}" || -z "${MASTER_LOCATION01}" || -z "${MASTER_LOCATION02}" ]]; then
    echo "Error: PROJECT_ID, MASTER_NAME01, MASTER_NAME02, MASTER_LOCATION01, MASTER_LOCATION02 must be set."
    exit 1
fi
export CTX_1=gke_${PROJECT_ID}_${MASTER_LOCATION01}_${MASTER_NAME01}
export CTX_2=gke_${PROJECT_ID}_${MASTER_LOCATION02}_${MASTER_NAME02}
gcloud container clusters get-credentials ${MASTER_NAME01} --zone ${MASTER_LOCATION01} --project ${PROJECT_ID}
gcloud container clusters get-credentials ${MASTER_NAME02} --zone ${MASTER_LOCATION02} --project ${PROJECT_ID}

# Deploy helloworld and sleep services under master+master control planes.
kubectl create --context=${CTX_1} namespace sample
kubectl label --context=${CTX_1} namespace sample \
  istio-injection=enabled
kubectl create --context=${CTX_2} namespace sample
kubectl label --context=${CTX_2} namespace sample \
  istio-injection=enabled
kubectl create --context=${CTX_1} \
  -f ${ISTIO}/samples/helloworld/helloworld.yaml -n sample
kubectl create --context=${CTX_2} \
  -f ${ISTIO}/samples/helloworld/helloworld.yaml -n sample
kubectl apply --context=${CTX_1} \
  -f ${ISTIO}/samples/sleep/sleep.yaml -n sample
kubectl apply --context=${CTX_2} \
  -f ${ISTIO}/samples/sleep/sleep.yaml -n sample

# Verify the helloworld and sleep deployments are ready
waitForPodsInContextReady sample ${CTX_1} "2/2"
waitForPodsInContextReady sample ${CTX_2} "2/2"

# Verify cross-cluster load balancing from cluster 1.
# The response set should include those from 4 instances in all clusters.
verifyResponseSet 10 0 4 kubectl exec --context=${CTX_1} -it -n sample -c sleep \
  $(kubectl get pod --context=${CTX_1} -n sample -l \
  app=sleep -o jsonpath='{.items[0].metadata.name}') -- curl \
  helloworld.sample:5000/hello

# Verify cross-cluster load balancing from cluster 2
# The response set should include those from 4 instances in all clusters.
verifyResponseSet 10 0 4 kubectl exec --context=${CTX_2} -it -n sample -c sleep \
  $(kubectl get pod --context=${CTX_2} -n sample -l \
  app=sleep -o jsonpath='{.items[0].metadata.name}') -- curl \
  helloworld.sample:5000/hello

# Deploy mTLS strict policy for cluster 1 and 2
kubectl apply --context=$CTX_1 -f - <<EOF
apiVersion: "authentication.istio.io/v1alpha1"
kind: "MeshPolicy"
metadata:
  name: "default"
spec:
  peers:
  - mtls: {}
EOF

kubectl apply --context=$CTX_2 -f - <<EOF
apiVersion: "authentication.istio.io/v1alpha1"
kind: "MeshPolicy"
metadata:
  name: "default"
spec:
  peers:
  - mtls: {}
EOF

# Wait 90 seconds for the mTLS policy to take effect
echo "Wait 90 seconds for the mTLS policy to take effect."
sleep 90

# Do not exit immediately for non zero status
set +e
# Confirm that plain-text requests fail as mutual TLS is required for helloworld with the following command.
verifyResponses 5 0 "command terminated with exit code 56" kubectl exec --context=$CTX_1 \
  $(kubectl get --context=$CTX_1 pod -n sample -l app=sleep -o jsonpath={.items..metadata.name})\
   -n sample -c istio-proxy -- curl -s helloworld.sample:5000/hello
# Exit immediately for non zero status
set -e

# Configure the DestinationRule in cluster 1 to use mutual TLS.
kubectl apply --context=$CTX_1 -f - <<EOF
apiVersion: "networking.istio.io/v1alpha3"
kind: "DestinationRule"
metadata:
  name: "default"
  namespace: "sample"
spec:
  host: "*.local"
  trafficPolicy:
    tls:
      mode: ISTIO_MUTUAL
EOF
# Configure the DestinationRule in cluster 2 to use mutual TLS.
kubectl apply --context=$CTX_2 -f - <<EOF
apiVersion: "networking.istio.io/v1alpha3"
kind: "DestinationRule"
metadata:
  name: "default"
  namespace: "sample"
spec:
  host: "*.local"
  trafficPolicy:
    tls:
      mode: ISTIO_MUTUAL
EOF

# To prepare for testing certificates and mTLS, deploy httpbin in cluster 1 and 2.
kubectl apply --context=${CTX_1} \
  -f ${ISTIO}/samples/httpbin/httpbin.yaml -n sample
kubectl apply --context=${CTX_2} \
  -f ${ISTIO}/samples/httpbin/httpbin.yaml -n sample

# Sleep 90 seconds for the DestinationRule and httpbin deployments to take effect.
sleep 90

# Under mTLS, verify cross-cluster load balancing from cluster 1.
# The response set should include those from 4 instances in all clusters.
verifyResponseSet 10 0 4 kubectl exec --context=${CTX_1} -it -n sample -c sleep \
  $(kubectl get pod --context=${CTX_1} -n sample -l \
  app=sleep -o jsonpath='{.items[0].metadata.name}') -- curl \
  helloworld.sample:5000/hello

# Under mTLS, verify cross-cluster load balancing from cluster 2.
# The response set should include those from 4 instances in all clusters.
verifyResponseSet 10 0 4 kubectl exec --context=${CTX_2} -it -n sample -c sleep \
  $(kubectl get pod --context=$CTX_2 -n sample -l \
  app=sleep -o jsonpath='{.items[0].metadata.name}') -- curl \
  helloworld.sample:5000/hello

# Verify the httpbin, helloworld, and sleep deployments are ready
waitForPodsInContextReady sample ${CTX_1} "2/2"
waitForPodsInContextReady sample ${CTX_2} "2/2"

# Test certificates and mTLS from sleep in cluster 1 to httpbin.
# The presence of the X-Forwarded-Client-Cert header shows that the certificate and mutual TLS are used.
verifyResponses 5 0 "X-Forwarded-Client-Cert" kubectl exec --context=${CTX_1} -n sample -c sleep \
  $(kubectl get --context=${CTX_1} pod -n sample -l \
  app=sleep -o jsonpath='{.items[0].metadata.name}') -- curl \
  http://httpbin.sample:8000/headers -s

# Test certificates and mTLS from sleep in cluster 2 to httpbin.
# The presence of the X-Forwarded-Client-Cert header shows that the certificate and mutual TLS are used.
verifyResponses 5 0 "X-Forwarded-Client-Cert" kubectl exec --context=${CTX_2} -n sample -c sleep \
  $(kubectl get --context=${CTX_2} pod -n sample -l \
  app=sleep -o jsonpath='{.items[0].metadata.name}') -- curl \
  http://httpbin.sample:8000/headers -s
