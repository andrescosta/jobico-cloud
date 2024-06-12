jobico::init() {
    jobico::local::init_fs
    if [ $(jobico::was_done "init") == false ]; then
        jobico::dao::gen_databases "$@"
        NOT_DRY_RUN jobico::local::download_deps
        NOT_DRY_RUN jobico::local::install_kubectl
        jobico::set_done "init"
    fi
}
jobico::create_cluster() {
    # Machines
    if [ $(jobico::was_done "machines") == false ]; then
        NOT_DRY_RUN jobico::vm::create
        NOT_DRY_RUN jobico::vm::wait_until_all_up
        jobico::set_done "machines"
    fi
    # DNS
    if [ $(jobico::was_done "host") == false ]; then
        jobico::host::gen_hostsfile
        NOT_DRY_RUN jobico::host::update_local_etc_hosts
        NOT_DRY_RUN jobico::host::update_local_known_hosts
        NOT_DRY_RUN jobico::host::set_machines_hostname
        NOT_DRY_RUN jobico::host::update_machines_etc_hosts
        jobico::set_done "host"
    fi
    # TLS
    if [ $(jobico::was_done "tls_certs") == false ]; then
        jobico::tls::gen_ca_conf
        jobico::tls::gen_ca
        jobico::tls::gen_certs
        NOT_DRY_RUN jobico::tls::deploy_to_nodes
        NOT_DRY_RUN jobico::tls::deploy_to_server
        jobico::set_done "tls_certs"
    fi
    # HAProxy
    if [ $(jobico::was_done "haproxy") == false ]; then
        jobico::haproxy::gen_cfg
        NOT_DRY_RUN jobico::haproxy::deploy
        jobico::set_done "haproxy"
    fi
    # Kubeconfig
    if [ $(jobico::was_done "kubeconfig") == false ]; then
        jobico::kubeconfig::gen_for_nodes
        jobico::kubeconfig::gen_for_controlplane
        jobico::kubeconfig::gen_for_kube_admin
        NOT_DRY_RUN jobico::kubeconfig::deploy_to_nodes
        NOT_DRY_RUN jobico::kubeconfig::deploy_to_servers
        jobico::set_done "kubeconfig"
    fi
    # Gen key for encryption at rest
    if [ $(jobico::was_done "encatrest") == false ]; then
        jobico::encryption::gen_key
        NOT_DRY_RUN jobico::encryption::deploy
        jobico::set_done "encatrest"
    fi
    # Etcd
    if [ $(jobico::was_done "etcddb") == false ]; then
        jobico::etcd::gen_service
        NOT_DRY_RUN jobico::etcd::deploy
        jobico::set_done "etcddb"
    fi
    # Control plane components
    if [ $(jobico::was_done "cpl") == false ]; then
        jobico::cpl::gen_kubeapiserver_service
        jobico::set_done "cpl"
    fi
    # Control Plane deployment
    if [ $(jobico::was_done "deploy_server") == false ]; then
        NOT_DRY_RUN jobico::cluster::deploy_to_servers
        jobico::set_done "deploy_server"
    fi
    # Nodes deployment
    if [ $(jobico::was_done "deploy_nodes") == false ]; then
        NOT_DRY_RUN jobico::cluster::deploy_to_nodes
        jobico::set_done "deploy_nodes"
    fi
    # Routes
    if [ $(jobico::was_done "routes") == false ]; then
        NOT_DRY_RUN jobico::net::init
        NOT_DRY_RUN jobico::net::add_routes
        jobico::set_done "routes"
    fi
    if [ $(jobico::was_done "lock") == false ]; then
        NOT_DRY_RUN jobico::dao::cluster::lock
        jobico::set_done "lock"
    fi
}
jobico::create_nodes() {
    if [ $(jobico::was_done "add_machines") == false ]; then
        NOT_DRY_RUN jobico::vm::create
        NOT_DRY_RUN jobico::vm::wait_until_all_up
        jobico::set_done "add_machines"
    fi
    # DNS
    if [ $(jobico::was_done "add_host") == false ]; then
        jobico::host::add_new_nodes_to_hostsfile
        NOT_DRY_RUN jobico::host::update_local_etc_hosts
        NOT_DRY_RUN jobico::host::update_local_known_hosts
        NOT_DRY_RUN jobico::host::set_machines_hostname
        NOT_DRY_RUN jobico::host::update_machines_etc_hosts
        jobico::set_done "add_host"
    fi
    # TLS
    if [ $(jobico::was_done "add_tls") == false ]; then
        jobico::tls::add_nodes_to_ca_conf
        jobico::tls::gen_certs
        NOT_DRY_RUN jobico::tls::deploy_to_nodes
        jobico::set_done "add_tls"
    fi
    # Kubeconfig
    if [ $(jobico::was_done "add_kubeconfig") == false ]; then
        jobico::kubeconfig::gen_for_nodes
        NOT_DRY_RUN jobico::kubeconfig::deploy_to_nodes
        jobico::set_done "add_kubeconfig"
    fi
    # Deployment
    if [ $(jobico::was_done "add_deploy_nodes") == false ]; then
        NOT_DRY_RUN jobico::cluster::deploy_to_nodes
        jobico::set_done "add_deploy_nodes"
    fi
    # Routes
    if [ $(jobico::was_done "add_routes") == false ]; then
        NOT_DRY_RUN jobico::net::init
        #NOT_DRY_RUN jobico::net::add_routes
        NOT_DRY_RUN jobico::net::add_routes_to_added_node
        jobico::set_done "add_routes"
    fi
    # Merge DBs
    if [ $(jobico::was_done "add_merge_db") == false ]; then
        NOT_DRY_RUN jobico::dao::merge_dbs
        jobico::set_done "add_merge_db"
    fi
    # Lock
    if [ $(jobico::was_done "add_lock") == false ]; then
        NOT_DRY_RUN jobico::dao::cluster::lock
        jobico::set_done "add_lock"
    fi
}
jobico::init_for_add() {
    local number_of_nodes=$1
    if [ $(jobico::was_done "add_init") == false ]; then
        jobico::dao::gen_add_db ${number_of_nodes}
        jobico::dao::gen_add_cluster_db
        jobico::set_done "add_init"
    fi
}
jobico::local() {
    if [ $(jobico::was_done "locals") == false ]; then
        jobico::local::download_local_deps
        jobico::local::install_kubectl
        jobico::kubeconfig::gen_for_kube_admin
        jobico::set_done "locals"
    fi
}
jobico::destroy_vms() {
    NOT_DRY_RUN jobico::vm::destroy
}
jobico::restore_local_env() {
    NOT_DRY_RUN jobico::host::restore_local_etc_hosts
}
jobico::install_all_addons() {
    local action=$1
    local base_dir=$2
    if [ $(jobico::was_done $action) == false ]; then
        jobico::install_addons $base_dir/core
        jobico::install_addons $base_dir/extras
        jobico::set_done $action
        echo "Finished installing addons."
    fi
}
jobico::install_addons() {
    local addons_dir=$1
    local dirs=$(find $addons_dir -mindepth 1 -maxdepth 1 -type d)
    local err=0
    for dir in $dirs; do
        local script="${dir}/main.sh"
        local disabled="${dir}/disabled"
        if [[ -f $script && ! -f $disabled ]]; then
            echo "[*] Installing addon with $script ..."
            if [[ $(IS_DRY_RUN) == false ]]; then
                local output=$(bash $script ${dir} 2>&1) || err=$?
                echo "Addon result:"
                echo "$output"
                if [[ $err != 0 ]]; then
                    echo "Warning: the addon $script returned an error $err"
                fi
                echo "[*] Addon: $script installed."
                echo ""
            fi
        else
            echo "Warning: $dir was not installed."
        fi
    done
}
jobico::set_done() {
    echo "|$1|" >>${STATUS_FILE}
}
jobico::was_done() {
    if grep -q $1 ${STATUS_FILE}; then
        echo true
    else
        echo false
    fi
}
jobico::add_cmd_was_done() {
    if grep -q '^|add_' ${STATUS_FILE}; then
        echo true
    else
        echo false
    fi
}
kuve::remove_add_commands() {
    sed -i '/^|add_/d' ${STATUS_FILE}
}
jobico::unlock_cluster() {
    NOT_DRY_RUN jobico::dao::cluster::unlock
}
