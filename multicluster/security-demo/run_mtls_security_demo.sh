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


# In the shell, configure your multicluster project ID, in which you have
# installed Istio master+master multicluster.
export PROJECT_ID=lt-multicluster-t1-6-16-2020
# Configure the first cluster name in your multicluster project.
export CLUSTER_1=master01
# Configure the first cluster location in your multicluster project.
export LOCATION_1=us-central1-a
# Configure the second cluster name in your multicluster project.
export CLUSTER_2=master02
# Configure the second cluster location in your multicluster project.
export LOCATION_2=us-central1-a
export CTX_1=gke_${PROJECT_ID}_${LOCATION_1}_${CLUSTER_1}
export CTX_2=gke_${PROJECT_ID}_${LOCATION_2}_${CLUSTER_2}
gcloud container clusters get-credentials ${CLUSTER_1} --zone ${LOCATION_1} --project ${PROJECT_ID}
gcloud container clusters get-credentials ${CLUSTER_2} --zone ${LOCATION_2} --project ${PROJECT_ID}

# Deploy sample services (helloworld, sleep, httpbin) and require mTLS
# policy for the services.
./deploy_mtls_demo.sh

# Wait 60 seconds for the mTLS policy to take effect
echo "Wait 60 seconds for the mTLS policy to take effect."
sleep 60

# Confirm that plain-text requests fail as mutual TLS is required for helloworld with the following command.
kubectl exec --context=$CTX_1 \
  $(kubectl get --context=$CTX_1 pod -n sample -l app=sleep -o jsonpath={.items..metadata.name})\
   -n sample -c istio-proxy -- curl -s helloworld.sample:5000/hello
# Example output: command terminated with exit code 56

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

# Sleep 60 seconds for the DestinationRule to take effect.
sleep 60

# Under mTLS, verify cross-cluster load balancing from cluster 1.
# The response set should include those from 4 instances in all clusters.
for i in {1..6}
do
  kubectl exec --context=${CTX_1} -it -n sample -c sleep \
    $(kubectl get pod --context=${CTX_1} -n sample -l \
    app=sleep -o jsonpath='{.items[0].metadata.name}') -- curl \
    helloworld.sample:5000/hello
done
# Example output:
# Hello version: v2, instance: helloworld-v2-776f74c475-rhkbx
# Hello version: v1, instance: helloworld-v1-578dd69f69-hrb9p
# Hello version: v2, instance: helloworld-v2-776f74c475-9mx2q
# Hello version: v1, instance: helloworld-v1-578dd69f69-cxw65
# Hello version: v2, instance: helloworld-v2-776f74c475-rhkbx
# Hello version: v1, instance: helloworld-v1-578dd69f69-hrb9p

# Under mTLS, verify cross-cluster load balancing from cluster 2.
# The response set should include those from 4 instances in all clusters.
for i in {1..6}
do
  kubectl exec --context=${CTX_2} -it -n sample -c sleep \
    $(kubectl get pod --context=$CTX_2 -n sample -l \
    app=sleep -o jsonpath='{.items[0].metadata.name}') -- curl \
    helloworld.sample:5000/hello
done
# Example output:
# Hello version: v1, instance: helloworld-v1-578dd69f69-cxw65
# Hello version: v2, instance: helloworld-v2-776f74c475-rhkbx
# Hello version: v2, instance: helloworld-v2-776f74c475-rhkbx
# Hello version: v1, instance: helloworld-v1-578dd69f69-hrb9p
# Hello version: v2, instance: helloworld-v2-776f74c475-9mx2q
# Hello version: v1, instance: helloworld-v1-578dd69f69-cxw65

# Test certificates and mTLS from sleep in cluster 1 to httpbin.
# The presence of the X-Forwarded-Client-Cert header shows that the certificate and mutual TLS are used.
kubectl exec --context=${CTX_1} -n sample -c sleep \
  $(kubectl get --context=${CTX_1} pod -n sample -l \
  app=sleep -o jsonpath='{.items[0].metadata.name}') -- curl \
  http://httpbin.sample:8000/headers -s

# Test certificates and mTLS from sleep in cluster 2 to httpbin.
# The presence of the X-Forwarded-Client-Cert header shows that the certificate and mutual TLS are used.
kubectl exec --context=${CTX_2} -n sample -c sleep \
  $(kubectl get --context=${CTX_2} pod -n sample -l \
  app=sleep -o jsonpath='{.items[0].metadata.name}') -- curl \
  http://httpbin.sample:8000/headers -s

# Clean up the resources created for the demo and deploy the services for authz demo
./cleanup_mtls_security_demo.sh; ./deploy_authz_demo.sh
