# k8s-diy-dev

<div align="center">
  <img src="docs/images/logo.png" alt="k8s-diy-dev logo" width="400"/>
  <p><em>Build your own Kubernetes development environment from scratch</em></p>
</div>

## Overview
This project helps you understand Kubernetes internals by providing step-by-step instructions to build a development environment from scratch. It's perfect for developers who want to:
- Learn how Kubernetes components work together
- Set up a local development environment
- Understand the inner workings of kubelet, kube-apiserver, and other components
- Experiment with Kubernetes without using minikube or kind

#### Inspired by [controller-runtime's envtest](https://pkg.go.dev/sigs.k8s.io/controller-runtime@v0.19.3/pkg/envtest)

## Features
- Complete local Kubernetes development environment
- Step-by-step component setup
- Support for both ARM64 and AMD64 architectures
- Built-in debugging and troubleshooting tools
- Customizable configuration options

## Prerequisites
- Mac with Apple Silicon (M1/M2) or Intel processor
- Podman installed (for Mac users)
- Basic understanding of Kubernetes concepts
- Terminal with sudo privileges

## Getting Started

### 1. Initial Setup

#### For Mac Users:
```bash
# Initialize and start Podman machine
podman machine init dev
podman machine start dev
podman machine ssh dev

# Install basic tools
sudo rpm-ostree install dnf zsh wget vim
```

#### For Linux Users:
```bash
sudo apt install zsh git
```

### 2. Development Environment Setup

#### Install Oh My Zsh for better terminal experience:
```bash
sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
```

#### Install K9S for cluster management:
```bash
curl -sS https://webi.sh/k9s | sh
```

### 3. Kubernetes Components Setup

#### Install kubebuilder-tools:
```bash
mkdir -p ./kubebuilder/bin && \
    curl -L https://storage.googleapis.com/kubebuilder-tools/kubebuilder-tools-1.30.0-linux-amd64.tar.gz -o kubebuilder-tools.tar.gz && \
    tar -C ./kubebuilder --strip-components=1 -zvxf kubebuilder-tools.tar.gz && \
    rm kubebuilder-tools.tar.gz
```

#### Download kubelet:
```bash
echo "Downloading kubelet..."
# For AMD64:
# curl -L "https://dl.k8s.io/v1.30.0/bin/linux/amd64/kubelet" -o kubebuilder/bin/kubelet
# For ARM64:
curl -L "https://dl.k8s.io/v1.30.0/bin/linux/arm64/kubelet" -o kubebuilder/bin/kubelet
```

#### Generate service account key pair:
```bash
echo "Generating service account key pair..." && \
openssl genrsa -out /tmp/sa.key 2048 && \
openssl rsa -in /tmp/sa.key -pubout -out /tmp/sa.pub
```

#### Generate token:
```bash
echo "Generating token file..." && \
    TOKEN="1234567890" && \
    echo "${TOKEN},admin,admin,system:masters" > /tmp/token.csv
```

#### Set up kubeconfig:
```bash
sudo kubebuilder/bin/kubectl config set-credentials test-user --token=1234567890
sudo kubebuilder/bin/kubectl config set-cluster test-env --server=https://127.0.0.1:6443 --insecure-skip-tls-verify
sudo kubebuilder/bin/kubectl config set-context test-context --cluster=test-env --user=test-user --namespace=default 
sudo kubebuilder/bin/kubectl config use-context test-context
```

### 4. Start Core Components

#### Get the container's IP address:
```bash
HOST_IP=$(hostname -I | awk '{print $1}')
```

#### Start etcd:
```bash
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

#### Verify etcd health:
```bash
curl http://127.0.0.1:2379/health
```

#### Start kube-apiserver:
```bash
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
    --service-account-signing-key-file=/tmp/sa.key &
```

#### Verify API server health:
```bash
kubebuilder/bin/kubectl get --raw='/readyz'
```

### 5. Container Runtime Setup

#### Install containerd:
```bash
echo "Installing containerd..."
sudo mkdir -p /opt/cni/bin
sudo mkdir -p /etc/cni/net.d

# For ARM64:
wget https://github.com/containerd/containerd/releases/download/v2.1.0-beta.0/containerd-2.1.0-beta.0-linux-arm64.tar.gz

# Download runc
sudo curl -L "https://github.com/opencontainers/runc/releases/download/v1.2.6/runc.amd64" -o /opt/cni/bin/runc

# Download CNI plugins
wget https://github.com/containernetworking/plugins/releases/download/v1.6.2/cni-plugins-linux-arm-v1.6.2.tgz

# Download kube-controller-manager and kube-scheduler
curl -L "https://dl.k8s.io/v1.30.0/bin/linux/arm64/kube-controller-manager" -o kubebuilder/bin/kube-controller-manager
curl -L "https://dl.k8s.io/v1.30.0/bin/linux/arm64/kube-scheduler" -o kubebuilder/bin/kube-scheduler

# Extract and install components
sudo tar zxf containerd-2.1.0-beta.0-linux-arm64.tar.gz -C /opt/cni/
sudo tar zxf cni-plugins-linux-arm-v1.6.2.tgz -C /opt/cni/bin/
```

#### Configure CNI:
```bash
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

#### Set permissions:
```bash
sudo chmod +x /opt/cni/bin/runc
sudo chmod +x kubebuilder/bin/kube-controller-manager
sudo chmod +x kubebuilder/bin/kubelet 
sudo chmod +x kubebuilder/bin/kube-scheduler
```

#### Configure containerd:
```bash
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

### 6. Start Remaining Components

#### Start containerd:
```bash
export PATH=$PATH:/opt/cni/bin:kubebuilder/bin
echo "Starting containerd..."
sudo export PATH=$PATH:/opt/cni/bin
sudo PATH=$PATH:/opt/cni/bin /opt/cni/bin/containerd -c /etc/containerd/config.toml &
```

#### Start kube-scheduler:
```bash
echo "Starting kube-scheduler..."
sudo kubebuilder/bin/kube-scheduler \
    --kubeconfig=/var/lib/kubelet/kubeconfig \
    --leader-elect=false \
    --v=2 \
    --bind-address=0.0.0.0 &
```

#### Create kubelet directories:
```bash
echo "Creating kubelet directories..."
sudo mkdir -p /var/lib/kubelet
sudo mkdir -p /etc/kubernetes/manifests
sudo mkdir -p /var/log/kubernetes
```

#### Generate CA certificate:
```bash
echo "Generating CA certificate for kubelet..."
openssl genrsa -out /tmp/ca.key 2048
openssl req -x509 -new -nodes -key /tmp/ca.key -subj "/CN=kubelet-ca" -days 365 -out /tmp/ca.crt
sudo cp /tmp/ca.crt /var/lib/kubelet/ca.crt
```

#### Configure kubelet:
```bash
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

#### Set up kubelet kubeconfig:
```bash
sudo cp ~/.kube/config /var/lib/kubelet/kubeconfig
export KUBECONFIG=~/.kube/config
cp /tmp/sa.pub /tmp/ca.crt
```

#### Create service account and configmap:
```bash
sudo kubebuilder/bin/kubectl create sa default
sudo kubebuilder/bin/kubectl create configmap kube-root-ca.crt --from-file=ca.crt=/tmp/ca.crt -n default
```

#### Start kubelet:
```bash
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

#### Verify kubelet status:
```bash
kubebuilder/bin/kubectl get nodes 
kubebuilder/bin/kubectl get all -A
```

#### Start kube-controller-manager:
```bash
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

#### Check component statuses:
```bash
kubebuilder/bin/kubectl get componentstatuses
```

### 7. Test the Setup

#### Create a test pod:
```bash
kubectl apply -f -<<EOF
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

#### Access the pod:
```bash
sudo /opt/cni/bin/ctr -n k8s.io c ls
sudo /opt/cni/bin/ctr -n k8s.io tasks exec -t --exec-id m 543350944cf0bec0ca8d10873d5b9d258ce155c2b3d5c334cf1fc711580dd2d2 sh
```

## Architecture
The project sets up the following Kubernetes components:
- etcd: Key-value store for cluster data
- kube-apiserver: Kubernetes API server
- kube-controller-manager: Controller manager
- kube-scheduler: Pod scheduler
- kubelet: Node agent
- containerd: Container runtime

## Troubleshooting
Common issues and their solutions:

1. **etcd Connection Issues**
   - Check if etcd is running: `curl http://127.0.0.1:2379/health`
   - Verify network connectivity
   - Check logs: `journalctl -u etcd`

2. **kubelet Problems**
   - Check kubelet status: `systemctl status kubelet`
   - View logs: `journalctl -u kubelet`
   - Verify containerd is running: `systemctl status containerd`

3. **API Server Issues**
   - Check API server health: `kubectl get --raw='/readyz'`
   - Verify certificates and tokens
   - Check logs: `journalctl -u kube-apiserver`

## Contributing
Contributions are welcome! Please feel free to submit a Pull Request.

## License
This project is licensed under the MIT License.

## Acknowledgments
- Kubernetes community for their excellent documentation
- controller-runtime team for inspiration
- All contributors who have helped improve this project
