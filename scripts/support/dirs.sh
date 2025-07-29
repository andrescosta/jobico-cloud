declare -A lcl_dirs

get_dir() {
    local key=$1
    if [[ -v "lcl_dirs[$key]" ]]; then 
        echo "${lcl_dirs[$key]}"
    else
        echo ""
    fi
}

set_dir() {
    local key=$1
    local value=$2
    lcl_dirs[$key]=$value
}

save_dirs() {
    cat > ${DIR}/dirs.conf <<EOF
_work_dir=${lcl_dirs["_work_dir"]}
_infra_dir=${lcl_dirs["_infra_dir"]}
_downloads_dir=${lcl_dirs["_downloads_dir"]}
_downloads_local_dir=${lcl_dirs["_downloads_local_dir"]}
EOF
}

load_dirs() {
    if [[ -f "${DIR}/dirs.conf" ]]; then
        source ${DIR}/dirs.conf
        set_dir "_work_dir" $_work_dir
        set_dir "_infra_dir" $_infra_dir
        set_dir "_downloads_dir" $_downloads_dir
        set_dir "_downloads_local_dir" $_downloads_local_dir
    else
        set_dir "_work_dir" "${HOME}/.jobico/work"
        set_dir "_infra_dir" "${HOME}/.jobico/infra"
        set_dir "_downloads_dir" "${HOME}/.jobico/downloads"
        set_dir "_downloads_local_dir" "${HOME}/.jobico/downloads_local"
    fi
}

reset_dirs(){
    rm -f ${DIR}/dirs.conf
}

work_dir(){
    get_dir "_work_dir"
}

set_work_dir(){
    set_dir "_work_dir" $1
}

infra_dir(){
    get_dir "_infra_dir"
}

set_infra_dir(){
    set_dir "_infra_dir" $1
}


set_support_dir(){
    set_work_dir $1/work
    set_infra_dir $1/infra
    set_downloads_dir $1/downloads
    set_downloads_local_dir $1/downloads_local
}

downloads_dir(){
    get_dir "_downloads_dir"
}

set_downloads_dir(){
    set_dir "_downloads_dir" $1
}

downloads_local_dir(){
    get_dir "_downloads_local_dir"
}

set_downloads_local_dir(){
    set_dir "_downloads_local_dir" $1
}

gate_config_dir(){
    get_dir "_gate_config_dir"
}

set_gate_config_dir(){
    set_dir "_gate_config_dir" $1
}
