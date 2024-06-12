jobico::kubeconfig::gen_for_nodes() {
    local lb=$(jobico::dao::cluster::lb 2)
    jobico::dao::cluster::members | while read IP FQDN HOST SUBNET TYPE SCH; do
        kubectl config set-cluster ${CLUSTER_NAME} \
            --certificate-authority=${WORK_DIR}/ca.crt \
            --embed-certs=true \
            --server=https://${lb}:6443 \
            --kubeconfig=${WORK_DIR}/${HOST}.kubeconfig

        kubectl config set-credentials system:node:${HOST} \
            --client-certificate=${WORK_DIR}/${HOST}.crt \
            --client-key=${WORK_DIR}/${HOST}.key \
            --embed-certs=true \
            --kubeconfig=${WORK_DIR}/${HOST}.kubeconfig

        kubectl config set-context default \
            --cluster=${CLUSTER_NAME} \
            --user=system:node:${HOST} \
            --kubeconfig=${WORK_DIR}/${HOST}.kubeconfig

        kubectl config use-context default --kubeconfig=${WORK_DIR}/${HOST}.kubeconfig
    done
}
jobico::kubeconfig::gen_for_controlplane() {
    local comps=($(jobico::dao::cpl::get genkubeconfig 4))
    local lb=$(jobico::dao::cluster::lb 2)
    for comp in ${comps[@]}; do
        kubectl config set-cluster ${CLUSTER_NAME} \
            --certificate-authority=${WORK_DIR}/ca.crt \
            --embed-certs=true \
            --server=https://${lb}:6443 \
            --kubeconfig=${WORK_DIR}/${comp}.kubeconfig

        kubectl config set-credentials system:${comp} \
            --client-certificate=${WORK_DIR}/${comp}.crt \
            --client-key=${WORK_DIR}/${comp}.key \
            --embed-certs=true \
            --kubeconfig=${WORK_DIR}/${comp}.kubeconfig

        kubectl config set-context default \
            --cluster=${CLUSTER_NAME} \
            --user=system:${comp} \
            --kubeconfig=${WORK_DIR}/${comp}.kubeconfig

        kubectl config use-context default --kubeconfig=${WORK_DIR}/${comp}.kubeconfig
    done
}

jobico::kubeconfig::gen_for_kube_admin() {
    kubectl config set-cluster ${CLUSTER_NAME} \
        --certificate-authority=${WORK_DIR}/ca.crt \
        --embed-certs=true \
        --server=https://server.kubernetes.local:6443

    kubectl config set-credentials admin \
        --client-certificate=${WORK_DIR}/admin.crt \
        --client-key=${WORK_DIR}/admin.key

    kubectl config set-context ${CLUSTER_NAME} \
        --cluster=${CLUSTER_NAME} \
        --user=admin

    kubectl config use-context ${CLUSTER_NAME}
}

jobico::kubeconfig::deploy_to_nodes() {
    jobico::dao::cluster::members | while read IP FQDN HOST SUBNET TYPE SCH; do
        SSH -n root@$HOST "mkdir -p /var/lib/{kube-proxy,kubelet}"
        SCP ${WORK_DIR}/kube-proxy.kubeconfig \
            root@$HOST:/var/lib/kube-proxy/kubeconfig
        SCP ${WORK_DIR}/${HOST}.kubeconfig \
            root@$HOST:/var/lib/kubelet/kubeconfig
    done
}

jobico::kubeconfig::deploy_to_servers() {
    local servers=($(jobico::dao::cluster::get server 3))
    for host in ${servers[@]}; do
        SCP ${WORK_DIR}/admin.kubeconfig \
            ${WORK_DIR}/kube-controller-manager.kubeconfig \
            ${WORK_DIR}/kube-scheduler.kubeconfig \
            root@$host:~/
    done
}
