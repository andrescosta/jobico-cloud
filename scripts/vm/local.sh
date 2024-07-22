readonly DOWNLOADS_TBL=${EXTRAS_DIR}/downloads/downloads_amd64.txt
readonly DOWNLOADS_LOCAL_TBL=${EXTRAS_DIR}/downloads/downloads_local_amd64.txt
jobico::local::init_fs() {
    mkdir -p ${WORK_DIR}
    touch ${STATUS_FILE}
}
jobico::local::download_deps() {
    if [ ! -d ${DOWNLOADS_DIR} ]; then
        mkdir -p ${DOWNLOADS_DIR}
        wget -q --https-only -P ${DOWNLOADS_DIR} -i ${DOWNLOADS_TBL}
    fi
}
jobico::local::download_local_deps() {
    mkdir -p ${DOWNLOADS_DIR}
    wget -q --https-only -P ${DOWNLOADS_DIR} -i ${DOWNLOADS_TBL}
}
jobico::local::install_kubectl() {
    if [ ! -f /usr/local/bin/kubectl ]; then
        sudo cp ${DOWNLOADS_DIR}/kubectl /usr/local/bin &&
            sudo chmod +x /usr/local/bin/kubectl
    fi
}
