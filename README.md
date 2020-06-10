# KubeVirt Installation Docs
## Table of Contents
- [KubeVirt](#kubevirt-prerequisites)
- [CDI](#cdi-installation)

## KubeVirt Prerequisites

- Privileged containers must be allowed
  - Apiserver flag: `--allow-privileged=true`
- Supported container runtimes:
  - docker
  - crio

## Quickstart

- Run `kubevirt/apply-kubevirt-no-hardware-support.sh` or `kubevirt/apply-kubevirt.sh` as appropriate
- Apply `vm/containerdisk.yaml` to create the 1vCPU/1Gi RAM VM as described below
  - Remember to edit the cloudInitNoCloud cloud-config with your own root password and SSH key

## No hardware virtualization support?
- Run these commands before installing KubeVirt:
  - `kubectl create namespace kubevirt`
  - `kubectl create configmap -n kubevirt kubevirt-config  --from-literal debug.useEmulation=true --from-literal feature-gates="LiveMigration"`

## KubeVirt Installation
- Deploy the KubeVirt operator
  - `kubectl apply -f https://github.com/kubevirt/kubevirt/releases/download/v0.25.0/kubevirt-operator.yaml`
- Create the KubeVirt CR
  - `kubectl apply -f https://github.com/kubevirt/kubevirt/releases/download/v0.25.0/kubevirt-cr.yaml`
- Enable Live Migration
  - `kubectl create configmap -n kubevirt kubevirt-config --from-literal feature-gates="LiveMigration"`
- Optional: Wait until all KubeVirt components come up
  - `kubectl -n kubevirt wait kv kubevirt --for condition=Available --timeout=-1s`
- Optional: Install KubeVirt kubectl plugin
  - Install krew
  - `kubectl krew install virt`
- Optional: Enable VNC proxy
  - `kubectl apply -f kubevirt/vnc.yaml`

## CDI Installation
- Deploy the CDI operator
  - `kubectl apply -f https://github.com/kubevirt/containerized-data-importer/releases/download/v1.13.1/cdi-operator.yaml`
- Create the CDI CR
  - `kubectl create -f https://github.com/kubevirt/containerized-data-importer/releases/download/v1.13.1/cdi-cr.yaml`

## Deploy a VM
- This manifest will deploy a 1 vCPU, 1Gi RAM Ubuntu 16.04 VM
  - It will require ~1 CPU and ~1GB of RAM to be successfully scheduled on a node
- This VM may be live migrated
- The VM uses containerDisk storage, meaning it will not survive the destruction of its pod through any means
  - It uses the Docker scratch space on a Kubernetes node
  - It does not require any persistent storage support (i.e PVC)
  - **Do not run any important workloads on the sample VM!**
- Replace `$YOUR_KEY_HERE` with an SSH public key, and `$YOUR_PASSWORD_HERE` with a root password (for serial console access)
```
apiVersion: kubevirt.io/v1alpha3
kind: VirtualMachine
metadata:
  name: test-vm
  namespace: default
spec:
  running: true
  template:
    metadata:
      labels:
        kubevirt.io/name: test-vm
    spec:
      domain:
        cpu:
          threads: 1
          cores: 1
          sockets: 1
        memory:
          guest: "1G"
        devices:
          autoattachPodInterface: true # true by default, explicitly setting for clarity
          disks:
          - name: bootdisk
            disk:
              bus: virtio
          - name: cloud-init
            disk:
              bus: virtio
          interfaces:
          - name: default
            masquerade: {}
      terminationGracePeriodSeconds: 0
      networks:
      - name: default
        pod: {}
      volumes:
      - name: bootdisk
        containerDisk:
          image: camelcasenotation/ubuntu1604-containerdisk:latest
      - name: cloud-init
        cloudInitNoCloud:
          userData: |-
            #cloud-config
            users:
              - name: root
                ssh-authorized-keys:
                  - $YOUR_KEY_HERE
            ssh_pwauth: True
            password: $YOUR_PASSWORD_HERE
            chpasswd:
              expire: False
              list: |-
                 root:$YOUR_PASSWORD_HERE
```

## Access the VM
- Be careful when exposing VMs externally with a NodePort service and a weak password
- Serial console is only possible with kubectl `virt` plugin
- SSH in as `root` user
- With virt:
  - SSH access: `kubectl virt expose vmi test-vm --port=22 --name=test-vm-ssh --type=NodePort`
  - Serial console: `virtctl console test-vm`
- Without virt:

```
apiVersion: v1
kind: Service
metadata:
  name: test-vm-ssh
  namespace: default
spec:
  ports:
  - name: test-vm-ssh
    protocol: TCP
    port: 22
    targetPort: 22
  selector:
    kubevirt.io/name: test-vm
  type: NodePort
```

- With VNC:
  - If VNC is not enabled yet
    - `kubectl apply -f kubevirt/vnc/vnc.yaml`
  - Look up VNC service nodeport
  - Access VMs at http://NODE_IP:NODEPORT/?namespace=VM_NAMESPACE
    - Only VMs under the namespace `VM_NAMESPACE` will be shown. Choose the namespace that your desired VM is under.

## Test CDI
- Make sure to fill out all the variables in the DataVolume/VM manifests to suit your environment before applying
- Try to create a DataVolume
  - `kubectl apply -f datavolume/datavolume-cirros.yaml`
  - `kubectl apply -f datavolume/datavolume-ubuntu.yaml`
  - `kubectl get datavolumes`
- Use a DataVolume on-the-fly in a VM manifest
  - `kubectl apply -f vm/CDI-PVC.yaml`


## Uninstall
```
export RELEASE=v0.25.0
kubectl delete -n kubevirt kubevirt kubevirt --wait=true # --wait=true should anyway be default
kubectl delete apiservices v1alpha3.subresources.kubevirt.io # this needs to be deleted to avoid stuck terminating namespaces
kubectl delete mutatingwebhookconfigurations virt-api-mutator # not blocking but would be left over
kubectl delete validatingwebhookconfigurations virt-api-validator # not blocking but would be left over
kubectl delete -f https://github.com/kubevirt/kubevirt/releases/download/${RELEASE}/kubevirt-operator.yaml --wait=false
```
- If these commands get stuck, delete the finalizer and rerun the uninstallation commands

### Delete Finalizer
```
kubectl -n kubevirt patch kv kubevirt --type=json -p '[{ "op": "remove", "path": "/metadata/finalizers" }]'
```


## Troubleshooting
- Ensure that Kubernetes has enough spare CPU/RAM to deploy your requested VM
- Ensure that hardware virtualization is supported and available, or that the software virtualization flag is present in the ConfigMap
  - Changing the flag requires a deployment restart
- Ensure that the service selector correctly targets the VM pod
- Check that the Docker MTU and CNI plugin MTU are appropriate for your network
- Use `kubectl virt console $VM_NAME_HERE` to ensure that VM has started and is ready for SSH logins

## References
- [https://kubevirt.io/user-guide/#/installation/installation](https://kubevirt.io/user-guide/#/installation/installation)
- [https://github.com/kubevirt/containerized-data-importer](https://github.com/kubevirt/containerized-data-importer)
- [https://kubevirt.io/2019/Access-Virtual-Machines-graphic-console-using-noVNC.html](https://kubevirt.io/2019/Access-Virtual-Machines-graphic-console-using-noVNC.html)
## Author
- Platform9 SE Clement Liaw [@iExalt](https://github.com/iExalt)
