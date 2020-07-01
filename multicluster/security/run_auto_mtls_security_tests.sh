#!/usr/bin/env bash

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

WD=$(dirname "$0")
WD=$(cd "$WD" || exit; pwd)
# shellcheck disable=SC1090
source "${WD}/setup_security_test.sh"
# shellcheck disable=SC1090
source "${WD}/util/util.sh"

# Before running the security tests in this script:
# 1) The multicluster control planes should have been installed in two clusters
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
mkdir -p "${WD}/asm-example-svc"
pushd "${WD}/asm-example-svc"
pwd

# Download package that contains example service deployment files.
if [[ "$ISTIO_DOWNLOAD_METHOD" == "gsutil" ]]; then
    echo "Download $ISTIO_RELEASE_URL using gsutil"
    gsutil cp "$ISTIO_RELEASE_URL" .
elif [[ "$ISTIO_DOWNLOAD_METHOD" == "curl" ]]; then
    echo "Download $ISTIO_RELEASE_URL using curl"
    curl -LO "${ISTIO_RELEASE_URL}"
else
    echo "Exit due to invalid Istio download method: ${ISTIO_DOWNLOAD_METHOD}."
    exit 1
fi
tar xzf "${ISTIO_RELEASE_PKG}"
export ISTIO=${WD}/asm-example-svc/"${ISTIO_RELEASE_NAME}"
if [ -d "$ISTIO" ]; then
    echo "The Istio pkg is unzipped into ${ISTIO}."
else
    echo "Exit due to the error: the directory ${ISTIO} not found."
    exit 1
fi

if [[ -z "${PROJECT_ID}" || -z "${CLUSTER_1}" || -z "${CLUSTER_2}" || -z "${LOCATION_1}" || -z "${LOCATION_2}" ]]; then
    echo "Error: PROJECT_ID, CLUSTER_1, CLUSTER_2, LOCATION_1, LOCATION_2 must be set."
    exit 1
fi
export CTX_1=gke_${PROJECT_ID}_${LOCATION_1}_${CLUSTER_1}
export CTX_2=gke_${PROJECT_ID}_${LOCATION_2}_${CLUSTER_2}
gcloud container clusters get-credentials "${CLUSTER_1}" --zone "${LOCATION_1}" --project "${PROJECT_ID}"
gcloud container clusters get-credentials "${CLUSTER_2}" --zone "${LOCATION_2}" --project "${PROJECT_ID}"

# Deploy helloworld and sleep services.
kubectl create --context="${CTX_1}" namespace sample
kubectl label --context="${CTX_1}" namespace sample \
  istio-injection=enabled
kubectl create --context="${CTX_2}" namespace sample
kubectl label --context="${CTX_2}" namespace sample \
  istio-injection=enabled
kubectl create --context="${CTX_1}" \
  -f "${ISTIO}"/samples/helloworld/helloworld.yaml -n sample
kubectl create --context="${CTX_2}" \
  -f "${ISTIO}"/samples/helloworld/helloworld.yaml -n sample
kubectl apply --context="${CTX_1}" \
  -f "${ISTIO}"/samples/sleep/sleep.yaml -n sample
kubectl apply --context="${CTX_2}" \
  -f "${ISTIO}"/samples/sleep/sleep.yaml -n sample

# To prepare for testing certificates of auto mTLS, deploy httpbin in cluster 1 and 2.
kubectl apply --context="${CTX_1}" \
  -f "${ISTIO}"/samples/httpbin/httpbin.yaml -n sample
kubectl apply --context="${CTX_2}" \
  -f "${ISTIO}"/samples/httpbin/httpbin.yaml -n sample

# Wait 20 seconds for deployments and auto mTLS policy to take effect
echo "Wait 20 seconds for deployments and auto mTLS policy to take effect."
sleep 20

# Verify the httpbin, helloworld, and sleep deployments are ready
waitForPodsInContextReady sample "${CTX_1}" "2/2"
waitForPodsInContextReady sample "${CTX_2}" "2/2"

# Test certificates and auto mTLS from sleep in cluster 1 to httpbin.
# The presence of the X-Forwarded-Client-Cert header shows that the certificate and auto mTLS are used.
verifyResponses 5 0 "X-Forwarded-Client-Cert" kubectl exec --context="${CTX_1}" -n sample -c sleep \
  $(kubectl get --context="${CTX_1}" pod -n sample -l \
  app=sleep -o jsonpath='{.items[0].metadata.name}') -- curl \
  http://httpbin.sample:8000/headers -s

# Test certificates and auto mTLS from sleep in cluster 2 to httpbin.
# The presence of the X-Forwarded-Client-Cert header shows that the certificate and auto mTLS are used.
verifyResponses 5 0 "X-Forwarded-Client-Cert" kubectl exec --context="${CTX_2}" -n sample -c sleep \
  $(kubectl get --context="${CTX_2}" pod -n sample -l \
  app=sleep -o jsonpath='{.items[0].metadata.name}') -- curl \
  http://httpbin.sample:8000/headers -s

# Verify cross-cluster load balancing under auto mTLS from cluster 1.
# The response set should include those from 4 instances in all clusters.
verifyResponseSet 10 0 4 kubectl exec --context="${CTX_1}" -it -n sample -c sleep \
  $(kubectl get pod --context="${CTX_1}" -n sample -l \
  app=sleep -o jsonpath='{.items[0].metadata.name}') -- curl \
  helloworld.sample:5000/hello

# Verify cross-cluster load balancing under auto mTLS from cluster 2
# The response set should include those from 4 instances in all clusters.
verifyResponseSet 10 0 4 kubectl exec --context="${CTX_2}" -it -n sample -c sleep \
  $(kubectl get pod --context="${CTX_2}" -n sample -l \
  app=sleep -o jsonpath='{.items[0].metadata.name}') -- curl \
  helloworld.sample:5000/hello

# Clean up the resources created after the tests
popd
# shellcheck disable=SC1090
source "${WD}/cleanup_mtls_security_tests.sh"
