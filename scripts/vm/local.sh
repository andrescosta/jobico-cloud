jobico::local::init_fs() {
    mkdir -p ${WORK_DIR}
    touch ${STATUS_FILE}
}

jobico::local::download_deps() {
    local downloads_tbl_tmpl=${EXTRAS_DIR}/downloads_db/downloads.txt.tmpl
    local downloads_tbl=${DOWNLOADS_DIR}/downloads.txt
    local downloads_versions=${EXTRAS_DIR}/downloads_db/vers.txt
    if [ ! -d ${DOWNLOADS_DIR} ]; then
        mkdir -p ${DOWNLOADS_DIR}
        vers=${1:-$downloads_versions}
        jobico::local::preparefile $downloads_tbl_tmpl $downloads_tbl $vers
        jobico::local::download_files $downloads_tbl $DOWNLOADS_DIR
    fi
}

jobico::local::download_local_deps() {
    local downloads_versions=${EXTRAS_DIR}/downloads_db/vers.txt
    local downloads_local_tbl_tmpl=${EXTRAS_DIR}/downloads_db/downloads_local.txt.tmpl
    local downloads_local_tbl=${DOWNLOADS_LOCAL_DIR}/downloads_local.txt
    mkdir -p ${DOWNLOADS_LOCAL_DIR}
    local vers=${1:-$downloads_versions}
    jobico::local::preparefile $downloads_local_tbl_tmpl $downloads_local_tbl $vers
    jobico::local::download_files $downloads_local_tbl $DOWNLOADS_LOCAL_DIR
}

jobico::local::install_kubectl() {
    dir=$1
    force=$2
    if [[ force == true || ! -f /usr/local/bin/kubectl ]]; then
        sudo cp $1/kubectl /usr/local/bin &&
            sudo chmod +x /usr/local/bin/kubectl
    fi
}
jobico::local::download_files(){
    local files=$1
    local dir=$2
    while IFS= read -r line; do
        url="${line%%##*}"
        custom_name="${line##*##}"
        if [[ -z "$custom_name" || "$custom_name" == "$line" ]]; then
            custom_name=$(basename "$url")
        fi
        wget -q --https-only -O "${dir}/$custom_name" "$url"
    done < $files
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