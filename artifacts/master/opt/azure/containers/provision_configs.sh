#!/bin/bash
NODE_INDEX=$(hostname | tail -c 2)
NODE_NAME=$(hostname)
PRIVATE_IP=$(hostname -I | cut -d' ' -f1)
ETCD_PEER_URL="https://${PRIVATE_IP}:2380"
ETCD_CLIENT_URL="https://${PRIVATE_IP}:2379"

systemctlEnableAndStart() {
    systemctl_restart 100 5 30 $1
    RESTART_STATUS=$?
    systemctl status $1 --no-pager -l > /var/log/azure/$1-status.log
    if [ $RESTART_STATUS -ne 0 ]; then
        echo "$1 could not be started"
        return 1
    fi
    retrycmd_if_failure 120 5 25 systemctl enable $1
    if [ $? -ne 0 ]; then
        echo "$1 could not be enabled by systemctl"
        return 1
    fi
}

configureEtcdUser(){
    useradd -U "etcd"
    usermod -p "$(head -c 32 /dev/urandom | base64)" "etcd"
    passwd -u "etcd"
    id "etcd"
}

configureSecrets(){
    APISERVER_PRIVATE_KEY_PATH="/etc/kubernetes/certs/apiserver.key"
    touch "${APISERVER_PRIVATE_KEY_PATH}"
    chmod 0600 "${APISERVER_PRIVATE_KEY_PATH}"
    chown root:root "${APISERVER_PRIVATE_KEY_PATH}"

    CA_PRIVATE_KEY_PATH="/etc/kubernetes/certs/ca.key"
    touch "${CA_PRIVATE_KEY_PATH}"
    chmod 0600 "${CA_PRIVATE_KEY_PATH}"
    chown root:root "${CA_PRIVATE_KEY_PATH}"

    ETCD_SERVER_PRIVATE_KEY_PATH="/etc/kubernetes/certs/etcdserver.key"
    touch "${ETCD_SERVER_PRIVATE_KEY_PATH}"
    chmod 0600 "${ETCD_SERVER_PRIVATE_KEY_PATH}"
    if [[ -z "${COSMOS_URI}" ]]; then
      chown etcd:etcd "${ETCD_SERVER_PRIVATE_KEY_PATH}"
    fi

    ETCD_CLIENT_PRIVATE_KEY_PATH="/etc/kubernetes/certs/etcdclient.key"
    touch "${ETCD_CLIENT_PRIVATE_KEY_PATH}"
    chmod 0600 "${ETCD_CLIENT_PRIVATE_KEY_PATH}"
    chown root:root "${ETCD_CLIENT_PRIVATE_KEY_PATH}"

    ETCD_PEER_PRIVATE_KEY_PATH="/etc/kubernetes/certs/etcdpeer${NODE_INDEX}.key"
    touch "${ETCD_PEER_PRIVATE_KEY_PATH}"
    chmod 0600 "${ETCD_PEER_PRIVATE_KEY_PATH}"
    if [[ -z "${COSMOS_URI}" ]]; then
      chown etcd:etcd "${ETCD_PEER_PRIVATE_KEY_PATH}"
    fi

    ETCD_SERVER_CERTIFICATE_PATH="/etc/kubernetes/certs/etcdserver.crt"
    touch "${ETCD_SERVER_CERTIFICATE_PATH}"
    chmod 0644 "${ETCD_SERVER_CERTIFICATE_PATH}"
    chown root:root "${ETCD_SERVER_CERTIFICATE_PATH}"

    ETCD_CLIENT_CERTIFICATE_PATH="/etc/kubernetes/certs/etcdclient.crt"
    touch "${ETCD_CLIENT_CERTIFICATE_PATH}"
    chmod 0644 "${ETCD_CLIENT_CERTIFICATE_PATH}"
    chown root:root "${ETCD_CLIENT_CERTIFICATE_PATH}"

    ETCD_PEER_CERTIFICATE_PATH="/etc/kubernetes/certs/etcdpeer${NODE_INDEX}.crt"
    touch "${ETCD_PEER_CERTIFICATE_PATH}"
    chmod 0644 "${ETCD_PEER_CERTIFICATE_PATH}"
    chown root:root "${ETCD_PEER_CERTIFICATE_PATH}"

    set +x
    echo "${APISERVER_PRIVATE_KEY}" | base64 --decode > "${APISERVER_PRIVATE_KEY_PATH}"
    echo "${CA_PRIVATE_KEY}" | base64 --decode > "${CA_PRIVATE_KEY_PATH}"
    echo "${ETCD_SERVER_PRIVATE_KEY}" | base64 --decode > "${ETCD_SERVER_PRIVATE_KEY_PATH}"
    echo "${ETCD_CLIENT_PRIVATE_KEY}" | base64 --decode > "${ETCD_CLIENT_PRIVATE_KEY_PATH}"
    echo "${ETCD_PEER_KEY}" | base64 --decode > "${ETCD_PEER_PRIVATE_KEY_PATH}"
    echo "${ETCD_SERVER_CERTIFICATE}" | base64 --decode > "${ETCD_SERVER_CERTIFICATE_PATH}"
    echo "${ETCD_CLIENT_CERTIFICATE}" | base64 --decode > "${ETCD_CLIENT_CERTIFICATE_PATH}"
    echo "${ETCD_PEER_CERT}" | base64 --decode > "${ETCD_PEER_CERTIFICATE_PATH}"
}

configureEtcd() {
    set -x

    ETCD_SETUP_FILE=/opt/azure/containers/setup-etcd.sh
    wait_for_file 1200 1 $ETCD_SETUP_FILE || exit $ERR_ETCD_CONFIG_FAIL
    $ETCD_SETUP_FILE > /opt/azure/containers/setup-etcd.log 2>&1
    RET=$?
    if [ $RET -ne 0 ]; then
        exit $RET
    fi

    MOUNT_ETCD_FILE=/opt/azure/containers/mountetcd.sh
    wait_for_file 1200 1 $MOUNT_ETCD_FILE || exit $ERR_ETCD_CONFIG_FAIL
    $MOUNT_ETCD_FILE || exit $ERR_ETCD_VOL_MOUNT_FAIL
    systemctlEnableAndStart etcd || exit $ERR_ETCD_START_TIMEOUT
    for i in $(seq 1 600); do
        MEMBER="$(sudo etcdctl member list | grep -E ${NODE_NAME} | cut -d':' -f 1)"
        if [ "$MEMBER" != "" ]; then
            break
        else
            sleep 1
        fi
    done
    retrycmd_if_failure 120 5 25 sudo etcdctl member update $MEMBER ${ETCD_PEER_URL} || exit $ERR_ETCD_CONFIG_FAIL
}

ensureRPC() {
    systemctlEnableAndStart rpcbind || exit $ERR_SYSTEMCTL_START_FAIL
    systemctlEnableAndStart rpc-statd || exit $ERR_SYSTEMCTL_START_FAIL
}

runAptDaily() {
    wait_for_apt_locks
    /usr/lib/apt/apt.systemd.daily
}

generateAggregatedAPICerts() {
    AGGREGATED_API_CERTS_SETUP_FILE=/etc/kubernetes/generate-proxy-certs.sh
    wait_for_file 1200 1 $AGGREGATED_API_CERTS_SETUP_FILE || exit $ERR_FILE_WATCH_TIMEOUT
    $AGGREGATED_API_CERTS_SETUP_FILE
}

configureK8s() {
    KUBELET_PRIVATE_KEY_PATH="/etc/kubernetes/certs/client.key"
    touch "${KUBELET_PRIVATE_KEY_PATH}"
    chmod 0600 "${KUBELET_PRIVATE_KEY_PATH}"
    chown root:root "${KUBELET_PRIVATE_KEY_PATH}"

    APISERVER_PUBLIC_KEY_PATH="/etc/kubernetes/certs/apiserver.crt"
    touch "${APISERVER_PUBLIC_KEY_PATH}"
    chmod 0644 "${APISERVER_PUBLIC_KEY_PATH}"
    chown root:root "${APISERVER_PUBLIC_KEY_PATH}"

    AZURE_JSON_PATH="/etc/kubernetes/azure.json"
    touch "${AZURE_JSON_PATH}"
    chmod 0600 "${AZURE_JSON_PATH}"
    chown root:root "${AZURE_JSON_PATH}"

    set +x
    echo "${KUBELET_PRIVATE_KEY}" | base64 --decode > "${KUBELET_PRIVATE_KEY_PATH}"
    echo "${APISERVER_PUBLIC_KEY}" | base64 --decode > "${APISERVER_PUBLIC_KEY_PATH}"
    # Perform the required JSON escaping for special characters " and \
    SERVICE_PRINCIPAL_CLIENT_SECRET=$(echo $SERVICE_PRINCIPAL_CLIENT_SECRET | sed "s|\\\\|\\\\\\\|g")
    SERVICE_PRINCIPAL_CLIENT_SECRET=$(echo $SERVICE_PRINCIPAL_CLIENT_SECRET | sed 's|"|\\"|g')
    cat << EOF > "${AZURE_JSON_PATH}"
{
    "cloud":"${TARGET_ENVIRONMENT}",
    "tenantId": "${TENANT_ID}",
    "subscriptionId": "${SUBSCRIPTION_ID}",
    "aadClientId": "${SERVICE_PRINCIPAL_CLIENT_ID}",
    "aadClientSecret": "${SERVICE_PRINCIPAL_CLIENT_SECRET}",
    "resourceGroup": "${RESOURCE_GROUP}",
    "location": "${LOCATION}",
    "vmType": "${VM_TYPE}",
    "subnetName": "${SUBNET}",
    "securityGroupName": "${NETWORK_SECURITY_GROUP}",
    "vnetName": "${VIRTUAL_NETWORK}",
    "vnetResourceGroup": "${VIRTUAL_NETWORK_RESOURCE_GROUP}",
    "routeTableName": "${ROUTE_TABLE}",
    "primaryAvailabilitySetName": "${PRIMARY_AVAILABILITY_SET}",
    "primaryScaleSetName": "${PRIMARY_SCALE_SET}",
    "cloudProviderBackoff": ${CLOUDPROVIDER_BACKOFF},
    "cloudProviderBackoffRetries": ${CLOUDPROVIDER_BACKOFF_RETRIES},
    "cloudProviderBackoffExponent": ${CLOUDPROVIDER_BACKOFF_EXPONENT},
    "cloudProviderBackoffDuration": ${CLOUDPROVIDER_BACKOFF_DURATION},
    "cloudProviderBackoffJitter": ${CLOUDPROVIDER_BACKOFF_JITTER},
    "cloudProviderRatelimit": ${CLOUDPROVIDER_RATELIMIT},
    "cloudProviderRateLimitQPS": ${CLOUDPROVIDER_RATELIMIT_QPS},
    "cloudProviderRateLimitBucket": ${CLOUDPROVIDER_RATELIMIT_BUCKET},
    "useManagedIdentityExtension": ${USE_MANAGED_IDENTITY_EXTENSION},
    "userAssignedIdentityID": "${USER_ASSIGNED_IDENTITY_ID}",
    "useInstanceMetadata": ${USE_INSTANCE_METADATA},
    "loadBalancerSku": "${LOAD_BALANCER_SKU}",
    "excludeMasterFromStandardLB": ${EXCLUDE_MASTER_FROM_STANDARD_LB},
    "providerVaultName": "${KMS_PROVIDER_VAULT_NAME}",
    "providerKeyName": "k8s",
    "providerKeyVersion": ""
}
EOF
    set -x
    if [[ ! -z "${MASTER_NODE}" ]]; then
        if [[ "${ENABLE_AGGREGATED_APIS}" = True ]]; then
            generateAggregatedAPICerts
        fi
    fi
}

configureCNI() {
    # needed for the iptables rules to work on bridges
    retrycmd_if_failure 120 5 25 modprobe br_netfilter || exit $ERR_MODPROBE_FAIL
    echo -n "br_netfilter" > /etc/modules-load.d/br_netfilter.conf
    if [[ "${NETWORK_PLUGIN}" = "azure" ]]; then
        if [[ "${NETWORK_POLICY}" != "calico" ]]; then
            mv $CNI_BIN_DIR/10-azure.conflist $CNI_CONFIG_DIR/
            chmod 600 $CNI_CONFIG_DIR/10-azure.conflist
        fi
        /sbin/ebtables -t nat --list
    fi
}

setKubeletOpts () {
    KUBELET_DEFAULT_FILE=/etc/default/kubelet
    wait_for_file 1200 1 $KUBELET_DEFAULT_FILE || exit $ERR_FILE_WATCH_TIMEOUT
    sed -i "s#^KUBELET_OPTS=.*#KUBELET_OPTS=${1}#" $KUBELET_DEFAULT_FILE
}

ensureCCProxy() {
    cat $CC_SERVICE_IN_TMP | sed 's#@libexecdir@#/usr/libexec#' > /etc/systemd/system/cc-proxy.service
    cat $CC_SOCKET_IN_TMP sed 's#@localstatedir@#/var#' > /etc/systemd/system/cc-proxy.socket
	echo "Enabling and starting Clear Containers proxy service..."
	systemctlEnableAndStart cc-proxy || exit $ERR_SYSTEMCTL_START_FAIL
}