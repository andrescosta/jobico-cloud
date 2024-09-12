jobico::kubeconfig::gen_for_nodes() {
    local lb=$(jobico::dao::cluster::lb 2)
    jobico::dao::cluster::members | while read IP FQDN HOST SUBNET TYPE SCH; do
        kubectl config set-cluster ${CLUSTER_NAME} \
            --certificate-authority=$(work_dir)/ca.crt \
            --embed-certs=true \
            --server=https://${lb}:6443 \
            --kubeconfig=$(work_dir)/${HOST}.kubeconfig

        kubectl config set-credentials system:node:${HOST} \
            --client-certificate=$(work_dir)/${HOST}.crt \
            --client-key=$(work_dir)/${HOST}.key \
            --embed-certs=true \
            --kubeconfig=$(work_dir)/${HOST}.kubeconfig

        kubectl config set-context default \
            --cluster=${CLUSTER_NAME} \
            --user=system:node:${HOST} \
            --kubeconfig=$(work_dir)/${HOST}.kubeconfig

        kubectl config use-context default --kubeconfig=$(work_dir)/${HOST}.kubeconfig
    done
}
jobico::kubeconfig::gen_for_controlplane() {
    local comps=($(jobico::dao::cpl::get genkubeconfig 4))
    local lb=$(jobico::dao::cluster::lb 2)
    for comp in ${comps[@]}; do
        kubectl config set-cluster ${CLUSTER_NAME} \
            --certificate-authority=$(work_dir)/ca.crt \
            --embed-certs=true \
            --server=https://${lb}:6443 \
            --kubeconfig=$(work_dir)/${comp}.kubeconfig

        kubectl config set-credentials system:${comp} \
            --client-certificate=$(work_dir)/${comp}.crt \
            --client-key=$(work_dir)/${comp}.key \
            --embed-certs=true \
            --kubeconfig=$(work_dir)/${comp}.kubeconfig

        kubectl config set-context default \
            --cluster=${CLUSTER_NAME} \
            --user=system:${comp} \
            --kubeconfig=$(work_dir)/${comp}.kubeconfig

        kubectl config use-context default --kubeconfig=$(work_dir)/${comp}.kubeconfig
    done
}

jobico::kubeconfig::gen_for_kube_admin() {
    kubectl config set-cluster ${CLUSTER_NAME} \
        --certificate-authority=$(work_dir)/ca.crt \
        --embed-certs=true \
        --server=https://server.kubernetes.local:6443

    kubectl config set-credentials admin \
        --client-certificate=$(work_dir)/admin.crt \
        --client-key=$(work_dir)/admin.key

    kubectl config set-context ${CLUSTER_NAME} \
        --cluster=${CLUSTER_NAME} \
        --user=admin

    kubectl config use-context ${CLUSTER_NAME}
}

jobico::kubeconfig::deploy_to_nodes() {
    jobico::dao::cluster::members | while read IP FQDN HOST SUBNET TYPE SCH; do
        SSH -n root@$HOST "mkdir -p /var/lib/{kube-proxy,kubelet}"
        SCP $(work_dir)/kube-proxy.kubeconfig \
            root@$HOST:/var/lib/kube-proxy/kubeconfig
        SCP $(work_dir)/${HOST}.kubeconfig \
            root@$HOST:/var/lib/kubelet/kubeconfig
    done
}

jobico::kubeconfig::deploy_to_servers() {
    local servers=($(jobico::dao::cluster::get server 3))
    for host in ${servers[@]}; do
        SCP $(work_dir)/admin.kubeconfig \
            $(work_dir)/kube-controller-manager.kubeconfig \
            $(work_dir)/kube-scheduler.kubeconfig \
            root@$host:~/
    done
}
