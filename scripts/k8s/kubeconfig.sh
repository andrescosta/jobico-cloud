kube::kubeconfig::gen_for_nodes(){
    local workers=($(kube::dao::cpl::get worker))
    local lb=$(kube::dao::cluster::lb 2)
    for host in ${workers[@]}; do
        kubectl config set-cluster ${CLUSTER_NAME} \
        --certificate-authority=${WORK_DIR}/ca.crt \
        --embed-certs=true \
        --server=https://${lb}:6443 \
        --kubeconfig=${WORK_DIR}/${host}.kubeconfig
        
        kubectl config set-credentials system:node:${host} \
        --client-certificate=${WORK_DIR}/${host}.crt \
        --client-key=${WORK_DIR}/${host}.key \
        --embed-certs=true \
        --kubeconfig=${WORK_DIR}/${host}.kubeconfig
        
        kubectl config set-context default \
        --cluster=${CLUSTER_NAME} \
        --user=system:node:${host} \
        --kubeconfig=${WORK_DIR}/${host}.kubeconfig
        
        kubectl config use-context default --kubeconfig=${WORK_DIR}/${host}.kubeconfig
    done
}
kube::kubeconfig::gen_for_controlplane(){
    local comps=($(kube::dao::cpl::get genkubeconfig 4))
    local lb=$(kube::dao::cluster::lb 2)
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

kube::kubeconfig::gen_for_kube_admin(){
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

kube::kubeconfig::deploy_to_nodes(){
    local workers=($(kube::dao::cpl::get worker))
    for host in ${workers[@]}; do
        SSH root@$host "mkdir -p /var/lib/{kube-proxy,kubelet}"
        SCP ${WORK_DIR}/kube-proxy.kubeconfig \
        root@$host:/var/lib/kube-proxy/kubeconfig
        SCP ${WORK_DIR}/${host}.kubeconfig \
        root@$host:/var/lib/kubelet/kubeconfig
    done
}

kube::kubeconfig::deploy_to_server(){
    local servers=($(kube::dao::cluster::get server 1))
    for host in ${servers[@]}; do
        SCP ${WORK_DIR}/admin.kubeconfig \
        ${WORK_DIR}/kube-controller-manager.kubeconfig \
        ${WORK_DIR}/kube-scheduler.kubeconfig \
            root@$host:~/
    done
}

