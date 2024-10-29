#! /bin/bash

#see https://docs.cloudbees.com/docs/cloudbees-ci/latest/cloud-admin-guide/kubernetes-self-signed-certificates

NAMESPACE=cloudbees-core

kubectl api-versions | grep admissionregistration.k8s.io/v1

kubectl create ns $NAMESPACE
#copy certs
kubectl cp -n $NAMESPACE  cjoc-0:etc/pki/ca-trust/extracted/pem/tls-ca-bundle.pem ./ca-certificates.crt
kubectl cp -n $NAMESPACE  cjoc-0:etc/pki/ca-trust/extracted/java/cacerts ./cacerts

#Add root CA to system certificate bundle:
#cat mycertificate.pem >> ca-certificates.crt

#Add root CA to Java cacerts:
#keytool -import -noprompt -keystore cacerts -file mycertificate.pem -storepass changeit -alias service-mycertificate;

kubectl delete configmap ca-bundles -n $NAMESPACE
kubectl create configmap --from-file=ca-certificates.crt,cacerts ca-bundles -n $NAMESPACE
#helm uninstall  cloudbees-sidecar-injector --namespace cloudbees-sidecar-injector
kubectl create namespace cloudbees-sidecar-injector
helm repo update
#helm fetch cloudbees/cloudbees-sidecar-injector --untar
helm upgrade -i cloudbees-sidecar-injector cloudbees/cloudbees-sidecar-injector --namespace cloudbees-sidecar-injector
kubectl --namespace cloudbees-sidecar-injector get all

# We use this patch to make sidecar injection implicit. Other wise it will break certmanager CRD
# see https://docs.cloudbees.com/docs/cloudbees-ci/latest/cloud-admin-guide/kubernetes-self-signed-certificates#_making_injection_explicit
kubectl patch configmap  cloudbees-sidecar-injector  -n cloudbees-sidecar-injector \
 --type='json' -p='[{"op": "replace", "path": "/data/sidecarconfig.yaml", "value": "annotationPrefix: com.cloudbees.sidecar-injector\nrequiresExplicitInjection: true"}]'


kubectl label namespace $NAMESPACE sidecar-injector=enabled
kubectl get namespace -L sidecar-injector

# Explicit injection, see https://docs.cloudbees.com/docs/cloudbees-ci/latest/cloud-admin-guide/kubernetes-self-signed-certificates#_making_injection_explicit
kubectl -n $NAMESPACE apply -f  - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: example-pod
  annotations:
    cluster-autoscaler.kubernetes.io/safe-to-evict: "false"
    com.cloudbees.sidecar-injector/inject: "true"
spec:
  containers:
    - name: example-container
      image: busybox
      command: ["/bin/sh", "-c", "sleep 3600"]
EOF

kubectl describe pod example-pod  -n $NAMESPACE |grep -o  /etc/ssl/ca-bundle.pem
