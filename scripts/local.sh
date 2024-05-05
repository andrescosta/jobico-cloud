
kube::local::init_fs(){
    mkdir -p ${WORK_DIR}
    touch ${STATUS_FILE}
}
kube::local::download_deps(){
    mkdir -p ${DOWNLOADS_DIR}
    wget -q --https-only -P  ${DOWNLOADS_DIR} -i ${DOWNLOADS_TBL}
}
kube::local::install_kubectl(){
    sudo cp ${DOWNLOADS_DIR}/kubectl /usr/local/bin && \
    sudo chmod +x /usr/local/bin/kubectl
}
