readonly DOWNLOADS_TBL_TMPL=${EXTRAS_DIR}/downloads_db/downloads_amd64.txt.tmpl
readonly DOWNLOADS_TBL=${DOWNLOADS_DIR}/downloads_amd64.txt
readonly DOWNLOADS_VERSIONS=${EXTRAS_DIR}/downloads_db/vers.txt
readonly DOWNLOADS_LOCAL_TBL_TMPL=${EXTRAS_DIR}/downloads_db/downloads_local_amd64.txt.tmpl

jobico::local::init_fs() {
    mkdir -p ${WORK_DIR}
    touch ${STATUS_FILE}
}
jobico::local::download_deps() {
    if [ ! -d ${DOWNLOADS_DIR} ]; then
        mkdir -p ${DOWNLOADS_DIR}
        jobico::local::preparefile $DOWNLOADS_TBL_TMPL $DOWNLOADS_TBL $DOWNLOADS_VERSIONS
        jobico::local::download_files $DOWNLOADS_TBL
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
jobico::local::download_files(){
    while IFS= read -r line; do
        url="${line%%##*}"
        custom_name="${line##*##}"
        if [[ -z "$custom_name" || "$custom_name" == "$line" ]]; then
            custom_name=$(basename "$url")
        fi
        wget -q --https-only -O "${DOWNLOADS_DIR}/$custom_name" "$url"
    done < $1
}

jobico::local::preparefile() {
    local tmpl=$1
    local file=$2
    local vers=$3
    cp $tmpl $file
    while read ver; do
        var=${ver%%=*}
        val=${ver#*=}
        sed -i "s/"{${var}}"/${val}/g" $file
    done <${vers}
}