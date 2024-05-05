kube::init(){
    kube::local::init_fs
    kube::do_init
}
kube::do_init(){
    if ! grep -q "doinit" "${STATUS_FILE}"; then
        local number_of_nodes=$1
        local number_of_cpl_nodes=$2
        local number_of_lbs=$3
        kube::dao::gen_databases $number_of_nodes $number_of_cpl_nodes $number_of_lbs
        NOT_DRY_RUN kube::local::download_deps
        NOT_DRY_RUN kube::local::install_kubectl
        kube::set_done "doinit"
    fi
}
kube::create_machines(){
    if ! grep -q "machines" ${STATUS_FILE}; then
        NOT_DRY_RUN kube::machine::create
        NOT_DRY_RUN kube::wait_for_vms_ssh
        kube::set_done "machines"
    fi
}

kube::add_nodes(){
    //Add node to the Databases
    kube::machine::create
    kube::wait_for_vms_ssh
    kube::host::set_machines_hostname
    kube::host::update_machines_etc_hosts
    kube::tls::gen_certs
    kube::tls::deploy_to_nodes
    kube::kubeconfig::gen_for_nodes
    kube::kubeconfig::deploy_to_nodes
    kube::cluster::deploy_to_nodes
    kube::cluster::add_routes
}
kube::create_cluster(){
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
        NOT_DRY_RUN kube::cluster::add_routes
        kube::set_done "routes"
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

kube::wait_for_vms_ssh() {
    local port=22
    local timeout=120 
    local delay=5 
    local elapsed_time=0
    
    echo "Waiting for servers to start..."
    
    while read IP FQDN HOST SUBNET TYPE; do
        if [ $TYPE != "lbvip" ]; then
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
        fi
    done < ${JOBICO_CLUSTER_TBL}
}

kube::set_done(){
    echo "|$1|" >> ${WORK_DIR}/jobico_status
}
