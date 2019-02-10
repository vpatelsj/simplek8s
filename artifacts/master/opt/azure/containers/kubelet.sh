#!/bin/bash
set -e


# Redirect ILB (4443) traffic to port 443 (ELB) in the prerouting chain
iptables -t nat -A PREROUTING -p tcp --dport 4443 -j REDIRECT --to-port 443


sed -i "s|<img>|k8s.gcr.io/kube-addon-manager-amd64:v8.6|g" /etc/kubernetes/manifests/kube-addon-manager.yaml
for a in "/etc/kubernetes/manifests/kube-apiserver.yaml /etc/kubernetes/manifests/kube-controller-manager.yaml /etc/kubernetes/manifests/kube-scheduler.yaml"; do
  sed -i "s|<img>|k8s.gcr.io/hyperkube-amd64:v1.10.12|g" $a
done
a=/etc/kubernetes/manifests/kube-apiserver.yaml
sed -i "s|<args>|\"--advertise-address=<advertiseAddr>\", \"--allow-privileged=true\", \"--anonymous-auth=false\", \"--audit-log-maxage=30\", \"--audit-log-maxbackup=10\", \"--audit-log-maxsize=100\", \"--audit-log-path=/var/log/kubeaudit/audit.log\", \"--audit-policy-file=/etc/kubernetes/addons/audit-policy.yaml\", \"--authorization-mode=Node,RBAC\", \"--bind-address=0.0.0.0\", \"--client-ca-file=/etc/kubernetes/certs/ca.crt\", \"--cloud-config=/etc/kubernetes/azure.json\", \"--cloud-provider=azure\", \"--enable-admission-plugins=NamespaceLifecycle,LimitRanger,ServiceAccount,DefaultStorageClass,DefaultTolerationSeconds,MutatingAdmissionWebhook,ValidatingAdmissionWebhook,ResourceQuota,ExtendedResourceToleration\", \"--enable-bootstrap-token-auth=true\", \"--etcd-cafile=/etc/kubernetes/certs/ca.crt\", \"--etcd-certfile=/etc/kubernetes/certs/etcdclient.crt\", \"--etcd-keyfile=/etc/kubernetes/certs/etcdclient.key\", \"--etcd-servers=https://<etcdEndPointUri>:2379\", \"--insecure-port=8080\", \"--kubelet-client-certificate=/etc/kubernetes/certs/client.crt\", \"--kubelet-client-key=/etc/kubernetes/certs/client.key\", \"--profiling=false\", \"--proxy-client-cert-file=/etc/kubernetes/certs/proxy.crt\", \"--proxy-client-key-file=/etc/kubernetes/certs/proxy.key\", \"--repair-malformed-updates=false\", \"--requestheader-allowed-names=\", \"--requestheader-client-ca-file=/etc/kubernetes/certs/proxy-ca.crt\", \"--requestheader-extra-headers-prefix=X-Remote-Extra-\", \"--requestheader-group-headers=X-Remote-Group\", \"--requestheader-username-headers=X-Remote-User\", \"--secure-port=443\", \"--service-account-key-file=/etc/kubernetes/certs/apiserver.key\", \"--service-account-lookup=true\", \"--service-cluster-ip-range=172.30.0.0/16\", \"--storage-backend=etcd3\", \"--tls-cert-file=/etc/kubernetes/certs/apiserver.crt\", \"--tls-private-key-file=/etc/kubernetes/certs/apiserver.key\", \"--v=4\"|g" $a

sed -i "s|<etcdEndPointUri>|127.0.0.1|g" $a

sed -i "s|<advertiseAddr>|10.240.255.15|g" $a
sed -i "s|<args>|\"--allocate-node-cidrs=true\", \"--cloud-config=/etc/kubernetes/azure.json\", \"--cloud-provider=azure\", \"--cluster-cidr=172.31.0.0/16\", \"--cluster-name=underlay1\", \"--cluster-signing-cert-file=/etc/kubernetes/certs/ca.crt\", \"--cluster-signing-key-file=/etc/kubernetes/certs/ca.key\", \"--configure-cloud-routes=true\", \"--controllers=*,bootstrapsigner,tokencleaner\", \"--feature-gates=LocalStorageCapacityIsolation=true,ServiceNodeExclusion=true\", \"--kubeconfig=/var/lib/kubelet/kubeconfig\", \"--leader-elect=true\", \"--node-monitor-grace-period=40s\", \"--pod-eviction-timeout=5m0s\", \"--profiling=false\", \"--root-ca-file=/etc/kubernetes/certs/ca.crt\", \"--route-reconciliation-period=20m\", \"--service-account-private-key-file=/etc/kubernetes/certs/apiserver.key\", \"--terminated-pod-gc-threshold=5000\", \"--use-service-account-credentials=true\", \"--v=2\"|g" /etc/kubernetes/manifests/kube-controller-manager.yaml
sed -i "s|<args>|\"--kubeconfig=/var/lib/kubelet/kubeconfig\", \"--leader-elect=true\", \"--profiling=false\", \"--v=2\"|g" /etc/kubernetes/manifests/kube-scheduler.yaml
sed -i "s|<img>|k8s.gcr.io/hyperkube-amd64:v1.10.12|g; s|<CIDR>|172.31.0.0/16|g" /etc/kubernetes/addons/kube-proxy-daemonset.yaml
KUBEDNS=/etc/kubernetes/addons/kube-dns-deployment.yaml

sed -i "s|<img>|k8s.gcr.io/k8s-dns-kube-dns-amd64:1.14.13|g; s|<imgMasq>|k8s.gcr.io/k8s-dns-dnsmasq-nanny-amd64:1.14.8|g; s|<imgSidecar>|k8s.gcr.io/k8s-dns-sidecar-amd64:1.14.8|g; s|<domain>|cluster.local|g; s|<clustIP>|172.30.0.10|g" $KUBEDNS















sed -i "s|apparmor_parser|d|g" /etc/systemd/system/kubelet.service