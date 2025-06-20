## This script installs etcdctl and etcdutl, tools for interacting with etcd.
ETCD_VER=v3.6.1
GITHUB_URL=https://github.com/etcd-io/etcd/releases/download
DOWNLOAD_URL=https://storage.googleapis.com/etcd
curl -L ${DOWNLOAD_URL}/${ETCD_VER}/etcd-${ETCD_VER}-linux-amd64.tar.gz -o /tmp/etcd-${ETCD_VER}-linux-amd64.tar.gz
tar --extract --verbose \
    --file=/tmp/etcd-${ETCD_VER}-linux-amd64.tar.gz \
    --directory=kubebuilder/bin \
    --strip-components=1 \
    --no-same-owner \
        etcd-v3.6.1-linux-amd64/etcdctl etcd-v3.6.1-linux-amd64/etcdutl
rm -f /tmp/etcd-${ETCD_VER}-linux-amd64.tar.gz
kubebuilder/bin/etcdutl version
kubebuilder/bin/etcdctl version
## This script installs kubectl, the command-line tool for interacting with Kubernetes clusters.
cat /proc/$(pgrep kube-apiserver)/net/tcp|grep 094B 
sudo kubebuilder/bin/kubectl get po test-pod-2 -o jsonpath='{.metadata.uid}' 

## This script installs ctr, the containerd client.
sudo ctr -n k8s.io c ls
sudo ctr -n k8s.io c info <>
sudo ctr -n k8s.io t kill 
sudo ctr -n k8s.io t
sudo ctr -n k8s.io t ls

# This script lists the cgroup directories for the kubepods.
sudo ls /sys/fs/cgroup/kubepods/besteffort/


# This script lists the cgroup directories for the kubepods with the systemd hierarchy.
kubebuilder/bin/etcdctl --endpoints 127.0.0.1:2379 get /registry/pods --prefix --keys-only
kubebuilder/bin/etcdctl --endpoints 127.0.0.1:2379 get /registry/pods/default/test-pod-2
kubebuilder/bin/etcdctl --endpoints 127.0.0.1:2379 get /registry/pods --prefix --keys-only
kubebuilder/bin/etcdctl --endpoints 127.0.0.1:2379 get /registry/pods/default/test-pod-2
kubebuilder/bin/etcdctl --endpoints 127.0.0.1:2379 etcdctl endpoint status --write-out=table
kubebuilder/bin/etcdctl --endpoints 127.0.0.1:2379 endpoint status --write-out=table
kubebuilder/bin/etcdctl --endpoints 127.0.0.1:2379 get "" --prefix --keys-only | wc -l
kubebuilder/bin/etcdctl --endpoints 127.0.0.1:2379 defrag
kubebuilder/bin/etcdctl --endpoints 127.0.0.1:2379 endpoint status --write-out=table
kubebuilder/bin/etcdctl --endpoints 127.0.0.1:2379 snapshot save /tmp/etcd-backup.db
ll /tmp/etcd-backup.db
kubebuilder/bin/etcdctl --endpoints 127.0.0.1:2379 maintenance status
kubebuilder/bin/etcdutl snapshot status /tmp/etcd-backup.db
kubebuilder/bin/etcdctl --endpoints 127.0.0.1:2379 etcdctl endpoint status --write-out=table
 
# This script lists the API resources available in the Kubernetes cluster.
kubectl get --raw /apis/v1|jq
kubectl get --raw /apis/batch/v1|jq
kubectl get --raw /api/v1/namespaces/default/pods/test-pod-2/status|jq

## This script watches for changes to the pods in the default namespace.
curl  'https://kubernetes.default.svc/api/v1/namespaces/default/pods?watch=true'

# This script runs Swagger UI to visualize the Kubernetes API.
docker run \
  -v $PWD/k8s-openapi-v2.json:/app/swagger.json \
  -p 8081:8080 \
  swaggerapi/swagger-ui
