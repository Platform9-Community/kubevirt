#!/bin/bash
cd "${0%/*}"

export KV=v0.25.0
export CDI=v1.13.1
export CNAO=0.27.0

# KubeVirt

kubectl create namespace kubevirt
kubectl create configmap -n kubevirt kubevirt-config  --from-literal debug.useEmulation=true --from-literal feature-gates="LiveMigration"
kubectl apply -f https://github.com/kubevirt/kubevirt/releases/download/$KV/kubevirt-operator.yaml
kubectl apply -f https://github.com/kubevirt/kubevirt/releases/download/$KV/kubevirt-cr.yaml


# CDI

kubectl create -f https://github.com/kubevirt/containerized-data-importer/releases/download/$CDI/cdi-operator.yaml
kubectl create -f https://github.com/kubevirt/containerized-data-importer/releases/download/$CDI/cdi-cr.yaml
