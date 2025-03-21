# k8s-diy-dev

## Overview
This project is designed to help you get started with Kubernetes dev environment by providing step-by-step instructions.

#### Inspired by https://pkg.go.dev/sigs.k8s.io/controller-runtime@v0.19.3/pkg/envtest

## Getting Started
This section will guide you through the basics of setting up and running the project on a Mac with Apple ARM.

## Installation
To install and set up the project, follow these steps:

Mac users:
```
podman machine init dev                                                                                 
podman machine start dev
podman machine ssh dev
sudo rpm-ostree install dnf zsh wget vim
```
linux:
```
sudo apt install zsh git
```
ohmyzsh to make work simplier
```
sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
```
Install K9S to manage the cluster
```
curl -sS https://webi.sh/k9s | sh
```

### Install kubebuilder-tools
```
mkdir -p ./kubebuilder/bin && \
    curl -L https://storage.googleapis.com/kubebuilder-tools/kubebuilder-tools-1.30.0-linux-amd64.tar.gz -o kubebuilder-tools.tar.gz && \
    tar -C ./kubebuilder --strip-components=1 -zvxf kubebuilder-tools.tar.gz && \
    rm kubebuilder-tools.tar.gz
```

### Download arm64/amd64 kubelet
```
echo "Downloading kubelet..."
#curl -L "https://dl.k8s.io/v1.30.0/bin/linux/amd64/kubelet" -o kubebuilder/bin/kubelet
curl -L "https://dl.k8s.io/v1.30.0/bin/linux/arm64/kubelet" -o kubebuilder/bin/kubelet 
```

### Generating service account key pair
```
echo "Generating service account key pair..." && \
openssl genrsa -out /tmp/sa.key 2048 && \
openssl rsa -in /tmp/sa.key -pubout -out /tmp/sa.pub
```
### Generating token
```
echo "Generating token file..." && \
    TOKEN="1234567890" && \
    echo "${TOKEN},admin,admin,system:masters" > /tmp/token.csv
```
### Set up kubeconfig
```
sudo kubebuilder/bin/kubectl config set-credentials test-user --token=1234567890
sudo kubebuilder/bin/kubectl config set-cluster test-env --server=https://127.0.0.1:6443 --insecure-skip-tls-verify
sudo kubebuilder/bin/kubectl config set-context test-context --cluster=test-env --user=test-user --namespace=default 
sudo kubebuilder/bin/kubectl config use-context test-context
```
### Get the container's IP address
```
HOST_IP=$(hostname -I | awk '{print $1}')
```
### Start etcd
```
echo "Starting etcd..."
kubebuilder/bin/etcd \
    --advertise-client-urls http://$HOST_IP:2379 \
    --listen-client-urls http://0.0.0.0:2379 \
    --data-dir ./etcd \
    --listen-peer-urls http://0.0.0.0:2380 \
    --initial-cluster default=http://$HOST_IP:2380 \
    --initial-advertise-peer-urls http://$HOST_IP:2380 \
    --initial-cluster-state new \
    --initial-cluster-token test-token &
```
### Wait for etcd to be ready
```
curl http://127.0.0.1:2379/health

# Start kube-apiserver
echo "Starting kube-apiserver..."
sudo kubebuilder/bin/kube-apiserver \
    --etcd-servers=http://$HOST_IP:2379 \
    --service-cluster-ip-range=10.0.0.0/24 \
    --bind-address=0.0.0.0 \
    --secure-port=6443 \
    --advertise-address=$HOST_IP \
    --authorization-mode=AlwaysAllow \
    --token-auth-file=/tmp/token.csv \
    --enable-priority-and-fairness=false \
    --allow-privileged=true \
    --profiling=false \
    --storage-backend=etcd3 \
    --storage-media-type=application/json \
    --v=0 \
    --service-account-issuer=https://kubernetes.default.svc.cluster.local \
    --service-account-key-file=/tmp/sa.pub \
    --service-account-signing-key-file=/tmp/sa.key&
```
### Wait for API server to be ready
```
kubebuilder/bin/kubectl get --raw='/readyz'
```
### Install containerd
#### https://github.com/containerd/containerd/blob/main/docs/getting-started.md
```
echo "Installing containerd..."
sudo mkdir -p /opt/cni/bin
sudo mkdir -p /etc/cni/net.d
```
```
#wget https://github.com/containerd/containerd/releases/download/v2.1.0-beta.0/containerd-2.1.0-beta.0-linux-amd64.tar.gz
wget https://github.com/containerd/containerd/releases/download/v2.1.0-beta.0/containerd-2.1.0-beta.0-linux-arm64.tar.gz
```
```
sudo curl -L "https://github.com/opencontainers/runc/releases/download/v1.2.6/runc.amd64" -o /opt/cni/bin/runc
```
```
#wget https://github.com/containernetworking/plugins/releases/download/v1.6.2/cni-plugins-linux-amd64-v1.6.2.tgz
wget https://github.com/containernetworking/plugins/releases/download/v1.6.2/cni-plugins-linux-arm-v1.6.2.tgz
```
```
curl -L "https://dl.k8s.io/v1.30.0/bin/linux/amd64/kube-controller-manager" -o kubebuilder/bin/kube-controller-manager
curl -L "https://dl.k8s.io/v1.30.0/bin/linux/arm64/kube-controller-manager" -o kubebuilder/bin/kube-controller-manager
```
```
curl -L "https://dl.k8s.io/v1.30.0/bin/linux/amd64/kube-scheduler" -o kubebuilder/bin/kube-scheduler
```
```
sudo tar zxf containerd-2.1.0-beta.0-linux-amd64.tar.gz -C /opt/cni/
sudo tar zxf containerd-2.1.0-beta.0-linux-arm64.tar.gz -C /opt/cni/
sudo tar zxf cni-plugins-linux-amd64-v1.6.2.tgz -C /opt/cni/bin/
```
```
cat <<EOF > 10-mynet.conf
{
    "cniVersion": "0.3.1",
    "name": "mynet",
    "type": "bridge",
    "bridge": "cni0",
    "isGateway": true,
    "ipMasq": true,
    "ipam": {
        "type": "host-local",
        "subnet": "10.22.0.0/16",
        "routes": [
            { "dst": "0.0.0.0/0" }
        ]
    }
}
EOF

sudo mv 10-mynet.conf /etc/cni/net.d/10-mynet.conf
```
```
sudo chmod +x /opt/cni/bin/runc
sudo chmod +x kubebuilder/bin/kube-controller-manager
sudo chmod +x kubebuilder/bin/kubelet 
sudo chmod +x kubebuilder/bin/kube-scheduler
```
```
sudo mkdir -p /etc/containerd/
cat <<EOF > config.toml
version = 2

[plugins]
  [plugins."io.containerd.grpc.v1.cri"]
    [plugins."io.containerd.grpc.v1.cri".containerd]
      snapshotter = "overlayfs"
      [plugins."io.containerd.grpc.v1.cri".containerd.default_runtime]
        runtime_type = "io.containerd.runc.v2"
        [plugins."io.containerd.grpc.v1.cri".containerd.default_runtime.options]
          SystemdCgroup = true
EOF
sudo mv config.toml /etc/containerd/config.toml
```

### Start containerd
```
export PATH=$PATH:/opt/cni/bin:kubebuilder/bin
echo "Starting containerd..."
sudo export PATH=$PATH:/opt/cni/bin
sudo PATH=$PATH:/opt/cni/bin /opt/cni/bin/containerd -c /etc/containerd/config.toml&
```
### Start kube-scheduler
```
echo "Starting kube-scheduler..."
sudo kubebuilder/bin/kube-scheduler \
    --kubeconfig=/var/lib/kubelet/kubeconfig \
    --leader-elect=false \
    --v=2 \
    --bind-address=0.0.0.0 &
```
### Create necessary directories for kubelet
```
echo "Creating kubelet directories..."
sudo mkdir -p /var/lib/kubelet
sudo mkdir -p /etc/kubernetes/manifests
sudo mkdir -p /var/log/kubernetes
```
### Generate CA certificate for kubelet
```
echo "Generating CA certificate for kubelet..."
openssl genrsa -out /tmp/ca.key 2048
openssl req -x509 -new -nodes -key /tmp/ca.key -subj "/CN=kubelet-ca" -days 365 -out /tmp/ca.crt
sudo cp /tmp/ca.crt /var/lib/kubelet/ca.crt
```
```
cat << EOF | sudo tee /var/lib/kubelet/config.yaml
apiVersion: kubelet.config.k8s.io/v1beta1
kind: KubeletConfiguration
authentication:
  anonymous:
    enabled: true
  webhook:
    enabled: true
  x509:
    clientCAFile: "/var/lib/kubelet/ca.crt"
authorization:
  mode: AlwaysAllow
clusterDomain: "cluster.local"
clusterDNS:
  - "10.0.0.10"
resolvConf: "/etc/resolv.conf"
runtimeRequestTimeout: "15m"
failSwapOn: false
seccompDefault: true
serverTLSBootstrap: true
containerRuntimeEndpoint: "unix:///run/containerd/containerd.sock"
staticPodPath: "/etc/kubernetes/manifests"
EOF
```
### Create kubelet kubeconfig
```
sudo cp ~/.kube/config /var/lib/kubelet/kubeconfig
export KUBECONFIG=~/.kube/config
cp /tmp/sa.pub /tmp/ca.crt
```
### Create sa and ca configmap
```
sudo kubebuilder/bin/kubectl create sa default
sudo kubebuilder/bin/kubectl create configmap kube-root-ca.crt --from-file=ca.crt=/tmp/ca.crt -n default
```
### Start kubelet
```
echo "Starting kubelet..."
sudo PATH=$PATH:/opt/cni/bin:/usr/sbin kubebuilder/bin/kubelet \
    --kubeconfig=/var/lib/kubelet/kubeconfig \
    --config=/var/lib/kubelet/config.yaml \
    --root-dir=/var/lib/kubelet \
    --cert-dir=/var/lib/kubelet/pki \
    --hostname-override=$(hostname)\
    --pod-infra-container-image=registry.k8s.io/pause:3.10 \
    --node-ip=$HOST_IP \
    --cgroup-driver=cgroupfs \
    --max-pods=4  \
    --v=1 &
```
### Wait for kubelet to be ready
```
kubebuilder/bin/kubectl get nodes 
kubebuilder/bin/kubectl get all -A
```
### Start kube-controller-manager
```
echo "Starting kube-controller-manager..."
sudo kubebuilder/bin/kube-controller-manager \
    --kubeconfig=/var/lib/kubelet/kubeconfig \
    --leader-elect=false \
    --allocate-node-cidrs=true \
    --cluster-cidr=10.0.0.0/24 \
    --service-cluster-ip-range=10.0.0.0/24 \
    --cluster-name=kubernetes \
    --root-ca-file=/var/lib/kubelet/ca.crt \
    --service-account-private-key-file=/tmp/sa.key \
    --use-service-account-credentials=true \
    --v=2 &
```
### Show component statuses
```
kubebuilder/bin/kubectl get componentstatuses
```
### Create a pod
```
k apply -f -<<EOF
apiVersion: v1
kind: Pod
metadata:
  name: test-pod-2
spec:
  containers:
    - name: test-container-nginx
      image: nginx:1.21
      securityContext:
        privileged: true
EOF
```
### Exec into the pod
```
sudo /opt/cni/bin/ctr -n k8s.io c ls
sudo /opt/cni/bin/ctr -n k8s.io tasks exec -t --exec-id m 543350944cf0bec0ca8d10873d5b9d258ce155c2b3d5c334cf1fc711580dd2d2 sh
```
