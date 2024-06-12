jobico::cpl::gen_kubeapiserver_service() {
    local etcd_servers=$(escape $(jobico::etcd::get_servers))
    local n_servers=$(jobico::dao::cluster::count server)
    cp ${EXTRAS_DIR}/units/kube-apiserver.service.tmpl ${WORK_DIR}/kube-apiserver.service
    sed -i "s/{ETCD_SERVERS}/${etcd_servers}/g" ${WORK_DIR}/kube-apiserver.service
    sed -i "s/{SERVERS}/${n_servers}/g" ${WORK_DIR}/kube-apiserver.service
}
