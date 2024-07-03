#! /bin/bash


NAMESPACE=cloudbees-core
#see https://docs.cloudbees.com/docs/cloudbees-ci/latest/cloud-admin-guide/kubernetes-self-signed-certificates


kubectl api-versions | grep admissionregistration.k8s.io/v1

#copy certs
kubectl cp -n $NAMESPACE  cjoc-0:etc/pki/ca-trust/extracted/pem/tls-ca-bundle.pem ./ca-certificates.crt
kubectl cp -n $NAMESPACE  cjoc-0:etc/pki/ca-trust/extracted/java/cacerts ./cacerts

#Add root CA to system certificate bundle:
#cat mycertificate.pem >> ca-certificates.crt

#Add root CA to Java cacerts:
#keytool -import -noprompt -keystore cacerts -file mycertificate.pem -storepass changeit -alias service-mycertificate;

kubectl delete configmap ca-bundles -n $NAMESPACE
kubectl create configmap --from-file=ca-certificates.crt,cacerts ca-bundles -n $NAMESPACE

kubectl create namespace cloudbees-sidecar-injector

helm repo update
helm upgrade -i cloudbees-sidecar-injector cloudbees/cloudbees-sidecar-injector --namespace cloudbees-sidecar-injector

kubectl --namespace cloudbees-sidecar-injector get all


kubectl label namespace $NAMESPACE sidecar-injector=enabled

kubectl get namespace -L sidecar-injector
#kubectl apply -f testpod.yaml -n $NAMESPACE

kubectl -n $NAMESPACE apply -f  - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: example-pod
spec:
  containers:
    - name: example-container
      image: busybox
      command: ["/bin/sh", "-c", "sleep 3600"]
EOF

kubectl describe pod example-pod  -n $NAMESPACE |grep -o  /etc/ssl/ca-bundle.pem
