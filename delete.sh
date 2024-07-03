#! /bin/bash

#clean resources

NAMESPACE=cloudbees-core
#see https://docs.cloudbees.com/docs/cloudbees-ci/latest/cloud-admin-guide/kubernetes-self-signed-certificates

kubectl delete configmap ca-bundles -n $NAMESPACE

helm uninstall cloudbees-sidecar-injector  --namespace cloudbees-sidecar-injector

kubectl delete namespace cloudbees-sidecar-injector

kubectl label namespace $NAMESPACE sidecar-injector-

kubectl -n $NAMESPACE delete pod example-pod

