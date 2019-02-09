#!/bin/bash

kubectl delete deploy httpbin
kubectl delete svc httpbin
kubectl delete secret sdstokensecret

# If you need to delete the Istio deployment, run the following command also.
kubectl delete ns istio-system
kubectl delete crd --all
