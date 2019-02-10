#!/bin/bash
set -x

sudo sed -i "1iETCDCTL_ENDPOINTS=https://127.0.0.1:2379" /etc/environment
sudo sed -i "1iETCDCTL_CA_FILE=/etc/kubernetes/certs/ca.crt" /etc/environment
sudo sed -i "1iETCDCTL_KEY_FILE=/etc/kubernetes/certs/etcdclient.key" /etc/environment
sudo sed -i "1iETCDCTL_CERT_FILE=/etc/kubernetes/certs/etcdclient.crt" /etc/environment
/bin/echo DAEMON_ARGS=--name "k8s-master-64789045-0" --peer-client-cert-auth --peer-trusted-ca-file=/etc/kubernetes/certs/ca.crt --peer-cert-file=/etc/kubernetes/certs/etcdpeer0.crt --peer-key-file=/etc/kubernetes/certs/etcdpeer0.key --initial-advertise-peer-urls "https://10.240.255.5:2380" --listen-peer-urls "https://10.240.255.5:2380" --client-cert-auth --trusted-ca-file=/etc/kubernetes/certs/ca.crt --cert-file=/etc/kubernetes/certs/etcdserver.crt --key-file=/etc/kubernetes/certs/etcdserver.key --advertise-client-urls "https://10.240.255.5:2379" --listen-client-urls "https://10.240.255.5:2379,https://127.0.0.1:2379" --initial-cluster-token "k8s-etcd-cluster" --initial-cluster k8s-master-64789045-0=https://10.240.255.5:2380,k8s-master-64789045-1=https://10.240.255.6:2380,k8s-master-64789045-2=https://10.240.255.7:2380 --data-dir "/var/lib/etcddisk" --initial-cluster-state "new" | tee -a /etc/default/etcd