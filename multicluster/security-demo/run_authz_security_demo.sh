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

# Deploy sample services (helloworld, sleep)
./deploy_authz_demo.sh

# When no deny policies are deployed, verify sleep in authz-ns1 of cluster 1
# can reach the helloworld service in authz-ns1 of both clusters.
# The response set should include those from 4 instances in all clusters.
for i in {1..6}
do
  kubectl exec --context=${CTX_1} -it -n authz-ns1 -c sleep \
  $(kubectl get pod --context=${CTX_1} -n authz-ns1 -l \
  app=sleep -o jsonpath='{.items[0].metadata.name}') -- curl \
  helloworld.authz-ns1:5000/hello
done
# Example output:
# Hello version: v1, instance: helloworld-v1-578dd69f69-dnpll
# Hello version: v2, instance: helloworld-v2-776f74c475-w7pmr
# Hello version: v1, instance: helloworld-v1-578dd69f69-d7l5x
# Hello version: v2, instance: helloworld-v2-776f74c475-whbsm
# Hello version: v1, instance: helloworld-v1-578dd69f69-dnpll
# Hello version: v2, instance: helloworld-v2-776f74c475-w7pmr

# When no deny policies are deployed, verify sleep in authz-ns1 of cluster 1
# can reach the helloworld service in authz-ns2 of both clusters.
# The response set should include those from 4 instances in all clusters.
for i in {1..6}
do
  kubectl exec --context=${CTX_1} -it -n authz-ns1 -c sleep \
  $(kubectl get pod --context=${CTX_1} -n authz-ns1 -l \
  app=sleep -o jsonpath='{.items[0].metadata.name}') -- curl \
  helloworld.authz-ns2:5000/hello
done
# Example output:
# Hello version: v1, instance: helloworld-v1-578dd69f69-kfmbh
# Hello version: v2, instance: helloworld-v2-776f74c475-sgvmk
# Hello version: v1, instance: helloworld-v1-578dd69f69-wz5gp
# Hello version: v2, instance: helloworld-v2-776f74c475-cvwv5
# Hello version: v1, instance: helloworld-v1-578dd69f69-kfmbh
# Hello version: v2, instance: helloworld-v2-776f74c475-sgvmk

# When no deny policies are deployed, verify sleep in authz-ns1 of cluster 2
# can reach the helloworld service in authz-ns1 of both clusters.
# The response set should include those from 4 instances in all clusters.
for i in {1..6}
do
  kubectl exec --context=${CTX_2} -it -n authz-ns1 -c sleep \
  $(kubectl get pod --context=${CTX_2} -n authz-ns1 -l \
  app=sleep -o jsonpath='{.items[0].metadata.name}') -- curl \
  helloworld.authz-ns1:5000/hello
done
# Example output:
# Hello version: v1, instance: helloworld-v1-578dd69f69-dnpll
# Hello version: v1, instance: helloworld-v1-578dd69f69-dnpll
# Hello version: v2, instance: helloworld-v2-776f74c475-w7pmr
# Hello version: v2, instance: helloworld-v2-776f74c475-w7pmr
# Hello version: v1, instance: helloworld-v1-578dd69f69-d7l5x
# Hello version: v2, instance: helloworld-v2-776f74c475-whbsm

# When no deny policies are deployed, verify sleep in authz-ns1 of cluster 2
# can reach the helloworld service in authz-ns2 of both clusters.
# The response set should include those from 4 instances in all clusters.
for i in {1..6}
do
  kubectl exec --context=${CTX_2} -it -n authz-ns1 -c sleep \
  $(kubectl get pod --context=${CTX_2} -n authz-ns1 -l \
  app=sleep -o jsonpath='{.items[0].metadata.name}') -- curl \
  helloworld.authz-ns2:5000/hello
done
# Example output:
# Hello version: v1, instance: helloworld-v1-578dd69f69-wz5gp
# Hello version: v1, instance: helloworld-v1-578dd69f69-kfmbh
# Hello version: v2, instance: helloworld-v2-776f74c475-sgvmk
# Hello version: v2, instance: helloworld-v2-776f74c475-cvwv5
# Hello version: v1, instance: helloworld-v1-578dd69f69-kfmbh
# Hello version: v1, instance: helloworld-v1-578dd69f69-wz5gp

# Deploy an authorization policy in cluster 1 and 2 to deny traffic to authz-ns2.
kubectl apply --context=${CTX_1} -f - <<EOF
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: deny-authz-ns2
  namespace: authz-ns2
spec:
  {}
EOF

kubectl apply --context=${CTX_2} -f - <<EOF
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: deny-authz-ns2
  namespace: authz-ns2
spec:
  {}
EOF

# Wait 60 seconds for the policies to take effect.
echo "Wait 60 seconds for the policies to take effect."
sleep 60

# Verify traffic from sleep in authz-ns1 of cluster 1 to helloworld.authz-ns2 is denied.
for i in {1..6}
do
  kubectl exec --context=${CTX_1} -it -n authz-ns1 -c sleep \
  $(kubectl get pod --context=${CTX_1} -n authz-ns1 -l \
  app=sleep -o jsonpath='{.items[0].metadata.name}') -- curl \
  helloworld.authz-ns2:5000/hello; echo
done
# Example output: "RBAC: access denied"

# Verify traffic from sleep in authz-ns1 of cluster 2 to helloworld.authz-ns2 is denied.
for i in {1..6}
do
  kubectl exec --context=${CTX_2} -it -n authz-ns1 -c sleep \
  $(kubectl get pod --context=${CTX_2} -n authz-ns1 -l \
  app=sleep -o jsonpath='{.items[0].metadata.name}') -- curl \
  helloworld.authz-ns2:5000/hello; echo
done
# Example output: "RBAC: access denied"

# Verify traffic from sleep in authz-ns2 of cluster 2 is allowed by
# all helloworld service instances in authz-ns1 of both clusters.
# The response set should include those from 4 instances in all clusters.
for i in {1..6}
do
  kubectl exec --context=${CTX_2} -it -n authz-ns2 -c sleep \
  $(kubectl get pod --context=${CTX_2} -n authz-ns2 -l \
  app=sleep -o jsonpath='{.items[0].metadata.name}') -- curl \
  helloworld.authz-ns1:5000/hello
done
# Example output:
# Hello version: v2, instance: helloworld-v2-776f74c475-whbsm
# Hello version: v1, instance: helloworld-v1-578dd69f69-dnpll
# Hello version: v2, instance: helloworld-v2-776f74c475-w7pmr
# Hello version: v1, instance: helloworld-v1-578dd69f69-dnpll
# Hello version: v1, instance: helloworld-v1-578dd69f69-d7l5x
# Hello version: v2, instance: helloworld-v2-776f74c475-whbsm

# Deploy an authorization policy in cluster 1 and 2 to deny traffic to authz-ns1.
kubectl apply --context=${CTX_1} -f - <<EOF
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: deny-authz-ns1
  namespace: authz-ns1
spec:
  {}
EOF

kubectl apply --context=${CTX_2} -f - <<EOF
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: deny-authz-ns1
  namespace: authz-ns1
spec:
  {}
EOF

# Wait 60 seconds for the policies to take effect.
echo "Wait 60 seconds for the policies to take effect."
sleep 60

# Verify traffic from sleep in authz-ns2 of cluster 2 to helloworld.authz-ns1 is denied.
for i in {1..6}
do
  kubectl exec --context=${CTX_2} -it -n authz-ns2 -c sleep \
  $(kubectl get pod --context=${CTX_2} -n authz-ns2 -l \
  app=sleep -o jsonpath='{.items[0].metadata.name}') -- curl \
  helloworld.authz-ns1:5000/hello; echo
done
# Example output: "RBAC: access denied"

# Verify traffic from sleep in authz-ns1 of cluster 1 to helloworld.authz-ns1 is denied.
for i in {1..6}
do
  kubectl exec --context=${CTX_1} -it -n authz-ns1 -c sleep \
  $(kubectl get pod --context=${CTX_1} -n authz-ns1 -l \
  app=sleep -o jsonpath='{.items[0].metadata.name}') -- curl \
  helloworld.authz-ns1:5000/hello; echo
done
# Example output: "RBAC: access denied"

# Clean up the resources created for the demo
./cleanup_authz_security_demo.sh