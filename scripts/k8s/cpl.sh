jobico::cpl::gen_kubeapiserver_service() {
    local etcd_servers=$(escape $(jobico::etcd::get_servers))
    local n_servers=$(jobico::dao::cluster::count server)
    local gates=$(get_gates "kube-apiserver")
    cp ${EXTRAS_DIR}/units/kube-apiserver.service.tmpl $(work_dir)/kube-apiserver.service
    sed -i "s/{ETCD_SERVERS}/${etcd_servers}/g" $(work_dir)/kube-apiserver.service
    sed -i "s/{SERVERS}/${n_servers}/g" $(work_dir)/kube-apiserver.service
    sed -i "s/{GATES}/${gates}/g" $(work_dir)/kube-apiserver.service
    
}

jobico::cpl::gen_kube_controller_manager() {
    local gates=$(get_gates "kube-controller-manager")
    cp ${EXTRAS_DIR}/units/kube-controller-manager.service.tmpl $(work_dir)/kube-controller-manager.service
    sed -i "s/{GATES}/${gates}/g" $(work_dir)/kube-controller-manager.service
}

jobico::cpl::gen_kube_proxy() {
    local gates=$(get_gates "kube-proxy")
    cp ${EXTRAS_DIR}/units/kube-proxy.service.tmpl $(work_dir)/kube-proxy.service
    sed -i "s/{GATES}/${gates}/g" $(work_dir)/kube-proxy.service
}

jobico::cpl::gen_kube_scheduler() {
    local gates=$(get_gates "kube-scheduler")
    cp ${EXTRAS_DIR}/units/kube-scheduler.service.tmpl $(work_dir)/kube-scheduler.service
    sed -i "s/{GATES}/${gates}/g" $(work_dir)/kube-scheduler.service
}

jobico::cpl::gen_kubelet() {
    local gates=$(get_gates "kubelet")
    cp ${EXTRAS_DIR}/units/kubelet.service.tmpl $(work_dir)/kubelet.service
    sed -i "s/{GATES}/${gates}/g" $(work_dir)/kubelet.service
}
