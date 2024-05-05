readonly DOWNLOADS_TBL=${EXTRAS_DIR}/downloads/downloads_amd64.txt
readonly DOWNLOADS_LOCAL_TBL=${EXTRAS_DIR}/downloads/downloads_local_amd64.txt
kube::local::init_fs(){
    mkdir -p ${WORK_DIR}
    touch ${STATUS_FILE}
}
kube::local::download_deps(){
    mkdir -p ${DOWNLOADS_DIR}
    wget -q --https-only -P  ${DOWNLOADS_DIR} -i ${DOWNLOADS_TBL}
}
kube::local::download_local_deps(){
    mkdir -p ${DOWNLOADS_DIR}
    wget -q --https-only -P  ${DOWNLOADS_DIR} -i ${DOWNLOADS_TBL}
}
kube::local::install_kubectl(){
    sudo cp ${DOWNLOADS_DIR}/kubectl /usr/local/bin && \
    sudo chmod +x /usr/local/bin/kubectl
}
