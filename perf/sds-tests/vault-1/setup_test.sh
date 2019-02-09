#!/bin/bash

set -xe
ISTIO_RELEASE=${ISTIO_RELEASE:?"specify the Istio release"}

# Delete Node Agent daemonset
# kubectl delete ds -n istio-system

sed "s/release-1.1-20190119-09-16/${ISTIO_RELEASE}/" httpbin.yaml > temp-httpbin.yaml
  # kubectl apply -f temp-httpbin.yaml
