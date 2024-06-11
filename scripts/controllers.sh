kube::init(){
    kube::local::init_fs
    if ! grep -q "init" "${STATUS_FILE}"; then
        kube::dao::gen_databases "$@"
        NOT_DRY_RUN kube::local::download_deps
        NOT_DRY_RUN kube::local::install_kubectl
        kube::set_done "init"
    fi
}
kube::create_cluster(){
    # Machines
    if ! grep -q "machines" ${STATUS_FILE}; then
        NOT_DRY_RUN kube::machine::create
        NOT_DRY_RUN kube::wait_for_vms_ssh
        kube::set_done "machines"
    fi
    # DNS
    if ! grep -q "host" ${STATUS_FILE}; then
        kube::host::gen_hostsfile
        NOT_DRY_RUN kube::host::update_local_etc_hosts
        NOT_DRY_RUN kube::host::update_local_known_hosts
        NOT_DRY_RUN kube::host::set_machines_hostname
        NOT_DRY_RUN kube::host::update_machines_etc_hosts
        kube::set_done "host"
    fi
    # TLS
    if ! grep -q "tls_certs" ${STATUS_FILE}; then
        kube::tls::gen_ca_conf
        kube::tls::gen_ca
        kube::tls::gen_certs
        NOT_DRY_RUN kube::tls::deploy_to_nodes
        NOT_DRY_RUN kube::tls::deploy_to_server
        kube::set_done "tls_certs"
    fi
    # HAProxy
    if ! grep -q "haproxy" ${STATUS_FILE}; then
        kube::haproxy::gen_cfg
        NOT_DRY_RUN kube::haproxy::deploy
        kube::set_done "haproxy"
    fi
    # Kubeconfig
    if ! grep -q "kubeconfig" ${STATUS_FILE}; then
        kube::kubeconfig::gen_for_nodes
        kube::kubeconfig::gen_for_controlplane
        kube::kubeconfig::gen_for_kube_admin
        NOT_DRY_RUN kube::kubeconfig::deploy_to_nodes
        NOT_DRY_RUN kube::kubeconfig::deploy_to_server
        kube::set_done "kubeconfig"
    fi
    # Gen key for encryption at rest
    if ! grep -q "encatrest" ${STATUS_FILE}; then
        kube::encryption::gen_key
        NOT_DRY_RUN kube::encryption::deploy
        kube::set_done "encatrest"
    fi
    # Etcd
    if ! grep -q "etcddb" ${STATUS_FILE}; then
        kube::etcd::gen_etcd_service
        NOT_DRY_RUN kube::etcd::deploy
        kube::set_done "etcddb"
    fi
    # Control plane components
    if ! grep -q "cpl" ${STATUS_FILE}; then
        kube::cpl::gen_kubeapiserver_service
        kube::set_done "cpl"
    fi
    # Control Plane deployment
    if ! grep -q "deploy_server" ${STATUS_FILE}; then
        NOT_DRY_RUN kube::cluster::deploy_to_server
        kube::set_done "deploy_server"
    fi
    # Nodes deployment
    if ! grep -q "deploy_nodes" ${STATUS_FILE}; then
        NOT_DRY_RUN kube::cluster::deploy_to_nodes
        kube::set_done "deploy_nodes"
    fi
    # Routes
    if ! grep -q "routes" ${STATUS_FILE}; then
        NOT_DRY_RUN kube::net::init
        NOT_DRY_RUN kube::net::add_routes
        kube::set_done "routes"
    fi
    if ! grep -q "lock" ${STATUS_FILE}; then
        NOT_DRY_RUN kube::dao::cluster::lock
        kube::set_done "lock"
    fi
}
kube::add_nodes(){
    if ! grep -q "add_machines" ${STATUS_FILE}; then
        NOT_DRY_RUN kube::machine::create
        NOT_DRY_RUN kube::wait_for_vms_ssh
        kube::set_done "add_machines"
    fi
    # DNS
    if ! grep -q "add_host" ${STATUS_FILE}; then
        kube::host::add_new_nodes_to_hostsfile
        NOT_DRY_RUN kube::host::update_local_etc_hosts
        NOT_DRY_RUN kube::host::update_local_known_hosts
        NOT_DRY_RUN kube::host::set_machines_hostname
        NOT_DRY_RUN kube::host::update_machines_etc_hosts
        kube::set_done "add_host"
    fi
    # TLS
    if ! grep -q "add_tls" ${STATUS_FILE}; then
        kube::tls::add_nodes_to_ca_conf
        kube::tls::gen_certs
        NOT_DRY_RUN kube::tls::deploy_to_nodes
        kube::set_done "add_tls"
    fi
    # Kubeconfig
    if ! grep -q "add_kubeconfig" ${STATUS_FILE}; then
        kube::kubeconfig::gen_for_nodes
        NOT_DRY_RUN kube::kubeconfig::deploy_to_nodes
        kube::set_done "add_kubeconfig"
    fi
    # Deployment
    if ! grep -q "add_deploy_nodes" ${STATUS_FILE}; then
        NOT_DRY_RUN kube::cluster::deploy_to_nodes
        kube::set_done "add_deploy_nodes"
    fi
    # Routes
    if ! grep -q "add_routes" ${STATUS_FILE}; then
        NOT_DRY_RUN kube::net::init
        #NOT_DRY_RUN kube::net::add_routes
        NOT_DRY_RUN kube::net::add_routes_to_added_node
        kube::set_done "add_routes"
    fi
    # Merge DBs
    if ! grep -q "add_merge_db" ${STATUS_FILE}; then
        NOT_DRY_RUN kube::dao::merge_dbs
        kube::set_done "add_merge_db"
    fi
    # Lock
    if ! grep -q "add_lock" ${STATUS_FILE}; then
        NOT_DRY_RUN kube::dao::cluster::lock
        kube::set_done "add_lock"
    fi
}
kube::init_for_add(){
    local number_of_nodes=$1
    if ! grep -q "add_init" ${STATUS_FILE}; then
        kube::dao::gen_add_db ${number_of_nodes}
        kube::dao::gen_add_cluster_db
        kube::set_done "add_init"
    fi
}
kube::local(){
    if ! grep -q "locals" "${STATUS_FILE}"; then
        kube::local::download_local_deps
        kube::local::install_kubectl
        kube::kubeconfig::gen_for_kube_admin
        kube::set_done "locals"
    fi
}
kube::destroy_machines(){
    NOT_DRY_RUN kube::machine::destroy
}
kube::restore_local_env(){
    NOT_DRY_RUN kube::host::restore_local_etc_hosts
}
kube::install_all_addons(){
    local action=$1
    local base_dir=$2
    if ! grep -q $action ${STATUS_FILE}; then
        kube::install_addons $base_dir/core
        kube::install_addons $base_dir/extras
        kube::set_done $action
        echo "Finished installing addons."
    fi
}
kube::install_addons(){
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
kube::wait_for_vms_ssh() {
    local port=22
    local timeout=120 
    local delay=5 
    local elapsed_time=0
    
    echo "Waiting for servers to start..."
    
    kube::dao::cluster::machines | while read IP FQDN HOST SUBNET TYPE SCH; do
          echo "Waiting for $IP to start listening on port $port..."
          start_time=$(date +%s)
          while ! nc -z "$IP" "$port" >/dev/null 2>&1; do
              current_time=$(date +%s)
              elapsed_time=$((current_time - start_time))
              if [ "$elapsed_time" -ge "$timeout" ]; then
                  echo "Timeout exceeded for $IP"
                  break
              fi
          
              sleep "$delay"
          done
      
          if [ "$elapsed_time" -lt "$timeout" ]; then
              echo "$IP is now listening on port $port"
          fi
    done 
}

kube::set_done(){
    echo "|$1|" >> ${WORK_DIR}/jobico_status
}
kuve::remove_add_commands(){
    sed -i '/^|add_/d' ${WORK_DIR}/jobico_status
}
kube::unlock_cluster(){
    NOT_DRY_RUN kube::dao::cluster::unlock
}
kube::add_was_executed(){
    if grep -qs '^|add_' ${WORK_DIR}/jobico_status; then
        echo true
    else
        echo false
    fi
}

