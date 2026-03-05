#!/bin/bash
echo "Hello from OpenTofu (Machine 0)!" > /tmp/hello.txt

wget https://github.com/k0sproject/k0sctl/releases/download/v0.28.0/k0sctl-linux-amd64
sudo cp k0sctl-linux-amd64 /usr/local/bin/k0sctl
sudo chmod 755 /usr/local/bin/k0sctl 

cat <<EOF > k0sctl.yaml
apiVersion: k0sctl.k0sproject.io/v1beta1
kind: Cluster
metadata:
  name: k0s-cluster
  user: admin
spec:
  hosts:
  - ssh:
      address: 10.0.1.10
      user: adminuser
      port: 22
      keyPath: /home/adminuser/id_rsa
    role: controller
  - ssh:
      address: 10.0.1.11
      user: adminuser
      port: 22
      keyPath: /home/adminuser/id_rsa
    role: worker
  - ssh:
      address: 10.0.1.12
      user: adminuser
      port: 22
      keyPath: /home/adminuser/id_rsa
    role: worker
  options:
    wait:
      enabled: true
    drain:
      enabled: true
      gracePeriod: 2m0s
      timeout: 5m0s
      force: true
      ignoreDaemonSets: true
      deleteEmptyDirData: true
      podSelector: ""
      skipWaitForDeleteTimeout: 0s
    concurrency:
      limit: 30
      workerDisruptionPercent: 10
      uploads: 5
    evictTaint:
      enabled: false
      taint: k0sctl.k0sproject.io/evict=true
      effect: NoExecute
      controllerWorkers: false
  k0s:
    config:
      spec:
        api:
          externalAddress: 10.0.1.9
EOF

# k0sctl apply --config k0sctl.yaml
# k0sctl kubeconfig > kubeconfig