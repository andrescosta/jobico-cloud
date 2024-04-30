
. $(dirname "$0")/utils.sh 

readonly WORK_DIR="work"
readonly DOWNLOADS_DIR="${WORK_DIR}/downloads"
readonly EXTRAS_DIR="extras"
readonly HOSTSFILE="${WORK_DIR}/hosts"
readonly CA_CONF="${WORK_DIR}/ca.conf"
readonly MAKE=make
readonly STATUS_FILE=${WORK_DIR}/jobico_status
readonly CLUSTER_NAME=jobico-cloud
readonly WORKER_NAME=node
readonly SERVER_NAME=server
readonly MACHINES_DB="${WORK_DIR}/cluster.txt"
readonly DOWNLOADS_TBL=${EXTRAS_DIR}/downloads/downloads_amd64.txt
readonly JOBICO_CLUSTER_TBL=${MACHINES_DB}
readonly ENCRYPTION_KEY=$(head -c 32 /dev/urandom | base64)
readonly BEGIN_HOSTS_FILE="#B> Kubernetes Cluster"
readonly END_HOSTS_FILE="#E> Kubernetes Cluster"
_DEBUG="off"

jobico::kube::cluster(){
    local number_of_nodes=$1
    local number_of_cpl_nodes=$2
    jobico::kube::init_local_files
    jobico::kube::dao::gen_databases $number_of_nodes $number_of_cpl_nodes
    DEBUG jobico::kube::print_databases_info
    jobico::kube::create_vms
    jobico::kube::download_deps
    jobico::kube::create_cluster
}
jobico::kube::init_local_files(){
    mkdir -p ${WORK_DIR}
    touch ${STATUS_FILE}
}
jobico::kube::dao::gen_databases(){
    local number_of_nodes=$1
    local number_of_cpl_nodes=$2
    jobico::kube::dao::gen_db $number_of_nodes $number_of_cpl_nodes
    jobico::kube::dao::gen_cluster_db
}
jobico::kube::create_vms(){
    if ! grep -q "machines" ${STATUS_FILE}; then
        jobico::kube::create_kvm_vms
        jobico::kube::wait_for_vms_ssh
        jobico::kube::set_done "machines"
    fi
}
jobico::kube::download_deps(){
    if ! grep -q "deps" "${STATUS_FILE}"; then
        mkdir -p ${DOWNLOADS_DIR}
        wget -q --https-only -P  ${DOWNLOADS_DIR} -i ${DOWNLOADS_TBL}
        jobico::kube::set_done "deps"
    fi
}
jobico::kube::create_cluster(){
    # DNS
    if ! grep -q "host" ${STATUS_FILE}; then
        jobico::kube::gen_hostsfile
        jobico::kube::update_local_etc_hosts
        jobico::kube::update_ssh_known_hosts
        jobico::kube::cluster::set_hostname
        jobico::kube::cluster::update_etc_hosts
        jobico::kube::set_done "host"
    fi
    # TLS
    if ! grep -q "tls_certs" ${STATUS_FILE}; then
        jobico::kube::tls::gen_ca_conf
        jobico::kube::tls::gen_ca
        jobico::kube::tls::gen_certs
        jobico::kube::tls::deploy_certs_to_nodes
        jobico::kube::tls::deploy_certs_to_server
        jobico::kube::set_done "tls_certs"
    fi
    # Kubeconfig
    if ! grep -q "kubeconfig" ${STATUS_FILE}; then
        jobico::kube::kubeconfig::gen_for_nodes
        jobico::kube::kubeconfig::gen_for_controlplane
        jobico::kube::kubeconfig::gen_locally_for_kube_admin
        jobico::kube::kubeconfig::deploy_to_nodes
        jobico::kube::kubeconfig::deploy_to_server
        jobico::kube::set_done "kubeconfig"
    fi
    # Gen key for encryption at rest
    if ! grep -q "encatrest" ${STATUS_FILE}; then
        jobico::kube::encryption::gen_key
        jobico::kube::encryption::deploy_key_to_server
        jobico::kube::set_done "encatrest"
    fi
    # Etcd
    if ! grep -q "etcddb" ${STATUS_FILE}; then
        jobico::kube::etcd::gen_etcd_services
        jobico::kube::etcd::install_to_server
        jobico::kube::set_done "etcddb"
    fi
    # Control Plane deployment
    if ! grep -q "deploy_server" ${STATUS_FILE}; then
        jobico::kube::deploy_deps_to_server
        jobico::kube::set_done "deploy_server"
    fi
    # Worker deployment
    if ! grep -q "deploy_nodes" ${STATUS_FILE}; then
        jobico::kube::deploy_deps_to_nodes
        jobico::kube::set_done "deploy_nodes"
    fi
    # Add routes
    if ! grep -q "add_routes" ${STATUS_FILE}; then
        jobico::kube::cluster::add_routes
        jobico::kube::set_done "add_routes"
    fi
}

jobico::kube::destroy_cluster(){
    jobico::kube::destroy_vms
    jobico::kube::restore_local_etc_hosts
}

## VMs

jobico::kube::create_kvm_vms(){
    while read IP FQDN HOST SUBNET TYPE; do
        if [ $TYPE != "lbvip" ]; then
            make -f scripts/Makefile.vm new-vm-${TYPE} VM_IP=${IP} VM_NAME=${HOST}
        fi
    done < ${JOBICO_CLUSTER_TBL}
}

jobico::kube::destroy_vms(){
    while read IP FQDN HOST SUBNET TYPE; do
        if [ $TYPE != "lbvip" ]; then
            make -f scripts/Makefile.vm destroy-vm VM_IP=${IP} VM_NAME=${HOST}
        fi
    done < ${JOBICO_CLUSTER_TBL}
}

## Databases

jobico::kube::dao::gen_db(){
    local total_workers=$1
    local total_cpl_nodes=$2
    cp ${EXTRAS_DIR}/db/db.txt.tmpl ${WORK_DIR}/db.txt
    for ((i=0;i<total_cpl_nodes;i++)); do
        echo "$SERVER_NAME-$i control_plane" >> ${WORK_DIR}/db.txt
    done
    for ((i=0;i<total_workers;i++)); do
        echo "$WORKER_NAME-$i worker gencert" >> ${WORK_DIR}/db.txt
    done
}

jobico::kube::dao::query_db(){
    values=($(grep "$1" ${WORK_DIR}/db.txt | cut -d " " -f 1))
    for e in "${values[@]}"; do
        echo "$e"
    done
}

jobico::kube::dao::query_cluster_db(){
    values=($(grep "$1" ${WORK_DIR}/cluster.txt | cut -d " " -f $2))
    for e in "${values[@]}"; do
        echo "$e"
    done
}

jobico::kube::dao::gen_cluster_db(){
    rm -f ${MACHINES_DB}
    local workers=($(jobico::kube::dao::query_db worker))
    local servers=($(jobico::kube::dao::query_db control_plane))
    local id1=7
    local id2=0
    if [ "${#servers[@]}" -gt 1 ]; then
        echo "192.168.122.${id1} lb.kubernetes.local lb 0.0.0.0/24 lbvip" >> ${MACHINES_DB}
        ((id1++))
        ((id2++))
        echo "192.168.122.${id1} lb-0.kubernetes.local lb-0 0.0.0.0/24 lb" >> ${MACHINES_DB}
        ((id1++))
        ((id2++))
        echo "192.168.122.${id1} lb-1.kubernetes.local lb-1 0.0.0.0/24 lb" >> ${MACHINES_DB}
        ((id1++))
        ((id2++))
    fi
    for e in "${servers[@]}"; do
        echo "192.168.122.${id1} ${e}.kubernetes.local ${e} 0.0.0.0/24 server" >> ${MACHINES_DB}
        ((id1++))
        ((id2++))
    done
    
    id2=0
    for e in "${workers[@]}"; do
        echo "192.168.122.${id1} ${e}.kubernetes.local ${e} 10.200.${id2}.0/24 node" >> ${MACHINES_DB}
        ((id1++))
        ((id2++))
    done
}

## Hosts files

jobico::kube::gen_hostsfile(){
    echo ${BEGIN_HOSTS_FILE} > ${HOSTSFILE}
    while read IP FQDN HOST SUBNET TYPE; do
        entry="${IP} ${FQDN} ${HOST}"
        echo ${entry} >> ${HOSTSFILE}
    done < ${JOBICO_CLUSTER_TBL}
    echo  ${END_HOSTS_FILE}>> ${HOSTSFILE}
}

jobico::kube::update_local_etc_hosts(){
    local cmd="cat ${HOSTSFILE} >> /etc/hosts"
    sudo bash -c "$cmd"
}

jobico::kube::restore_local_etc_hosts(){
    sed "/${BEGIN_HOSTS_FILE}/,/${END_HOSTS_FILE}/d" /etc/hosts > ${WORK_DIR}/uhosts
    sudo bash -c "cp ${WORK_DIR}/uhosts /etc/hosts"
}
jobico::kube::update_ssh_known_hosts(){
    while read IP FQDN HOST SUBNET TYPE; do
        ssh-keyscan -H ${HOST} >> ~/.ssh/known_hosts
        ssh-keyscan -H ${IP} >> ~/.ssh/known_hosts
    done < ${JOBICO_CLUSTER_TBL}
}
jobico::kube::cluster::set_hostname(){
    while read IP FQDN HOST SUBNET TYPE; do
        # -o "StrictHostKeyChecking=no"
        cmd="sed -i 's/^127.0.0.1.*/127.0.1.1\t${FQDN} ${HOST}/' /etc/hosts"
        ssh -n root@${IP} "${cmd}"
        ssh -n root@${IP} hostnamectl hostname ${HOST}
    done < ${JOBICO_CLUSTER_TBL}
}

jobico::kube::cluster::update_etc_hosts(){
    while read IP FQDN HOST SUBNET TYPE; do
        scp  ${HOSTSFILE} root@${HOST}:~/
        ssh -n \
        root@${HOST} "cat hosts >> /etc/hosts"
    done < ${JOBICO_CLUSTER_TBL}
}

## TLS

jobico::kube::tls::gen_ca_conf(){
    cp ${EXTRAS_DIR}/tls/ca.conf.tmpl ${CA_CONF}
    workers=($(jobico::kube::dao::query_db worker))
    new_ca=""
    for e in "${workers[@]}"; do
        node_req=$(sed "s/{NAME}/${e}/g" "${EXTRAS_DIR}/tls/ca.conf.nodes.tmpl")
        new_ca="${new_ca}\n\n${node_req}"
    done
    echo -e "${new_ca}">>${CA_CONF}

    local ips=""
    local dns=""
    local i=1
    while read IP FQDN HOST SUBNET TYPE; do
        if [ "${TYPE}" == "server" ]; then
            ips="${ips}IP.${i}=${IP}\n"
            dns="${dns}DNS.${i}=${FQDN}\n"
            ((i++))
        fi
    done < ${WORK_DIR}/cluster.txt
    sed -i "s/{ETCD_IPS}/$ips/g" "${CA_CONF}"
    sed -i "s/{ETCD_DNS}/$dns/g" "${CA_CONF}"
    sed -i "s/{API_SERVER_IPS}/$ips/g" "${CA_CONF}"
   
    vip=$(jobico::kube::dao::get_lb_data 1)
    vipdns=$(jobico::kube::dao::get_lb_data 2)
    sed -i "s/{LB_IP}/${vip}/g" "${CA_CONF}"
    sed -i "s/{LB_DNS}/${vipdns}/g" "${CA_CONF}"
}
jobico::kube::dao::get_lb_data(){
    vip=$(jobico::kube::dao::query_cluster_db lbvip $1)
    echo "${lb}"
}
jobico::kube::tls::gen_ca(){
    openssl genrsa -out ${WORK_DIR}/ca.key 4096
    openssl req -x509 -new -sha512 -noenc \
    -key ${WORK_DIR}/ca.key -days 3653 \
    -config ${CA_CONF}\
    -out ${WORK_DIR}/ca.crt
}

jobico::kube::tls::gen_certs(){
    local comps=($(jobico::kube::dao::query_db gencert))
    for component in ${comps[*]}; do
        openssl genrsa -out "${WORK_DIR}/${component}.key" 4096
        
        openssl req -new -key "${WORK_DIR}/${component}.key" -sha256 \
        -config ${CA_CONF} -section ${component} \
        -out "${WORK_DIR}/${component}.csr"
        
        openssl x509 -req -days 3653 -in "${WORK_DIR}/${component}.csr" \
        -copy_extensions copyall \
        -sha256 -CA "${WORK_DIR}/ca.crt" \
        -CAkey "${WORK_DIR}/ca.key" \
        -CAcreateserial \
        -out "${WORK_DIR}/${component}.crt"
    done
}

jobico::kube::tls::deploy_certs_to_nodes(){
    local workers=($(jobico::kube::dao::query_db worker))
    for host in ${workers[*]}; do
        ssh root@$host mkdir -p /var/lib/kubelet/
        
        scp ${WORK_DIR}/ca.crt root@$host:/var/lib/kubelet/
        
        scp ${WORK_DIR}/$host.crt \
        root@$host:/var/lib/kubelet/kubelet.crt
        
        scp ${WORK_DIR}/$host.key \
        root@$host:/var/lib/kubelet/kubelet.key
    done
}

jobico::kube::tls::deploy_certs_to_server(){
    local servers=($(jobico::kube::dao::query_cluster_db server 2))
    for host in ${servers[*]}; do
        scp \
            ${WORK_DIR}/ca.key ${WORK_DIR}/ca.crt \
            ${WORK_DIR}/kube-api-server.key ${WORK_DIR}/kube-api-server.crt \
        ${WORK_DIR}/service-accounts.key ${WORK_DIR}/service-accounts.crt \
        ${WORK_DIR}/etcd-server.key ${WORK_DIR}/etcd-server.crt \
        root@$host:~/
    done
}

# Kubeconfig
#--server=https://server.kubernetes.local:6443 \

jobico::kube::kubeconfig::gen_for_nodes(){
    local workers=($(jobico::kube::dao::query_db worker))
    local lb=$(jobico::kube::dao::get_lb_data 2)
    for host in ${workers[*]}; do
        kubectl config set-cluster ${CLUSTER_NAME} \
        --certificate-authority=${WORK_DIR}/ca.crt \
        --embed-certs=true \
        --server=https://${lb}:6443 \
        --kubeconfig=${WORK_DIR}/${host}.kubeconfig
        
        kubectl config set-credentials system:node:${host} \
        --client-certificate=${WORK_DIR}/${host}.crt \
        --client-key=${WORK_DIR}/${host}.key \
        --embed-certs=true \
        --kubeconfig=${WORK_DIR}/${host}.kubeconfig
        
        kubectl config set-context default \
        --cluster=${CLUSTER_NAME} \
        --user=system:node:${host} \
        --kubeconfig=${WORK_DIR}/${host}.kubeconfig
        
        kubectl config use-context default --kubeconfig=${WORK_DIR}/${host}.kubeconfig
    done
}
jobico::kube::kubeconfig::gen_for_controlplane(){
    local comps=($(jobico::kube::dao::query_db genkubeconfig))
    local lb=$(jobico::kube::dao::get_lb_data 2)
    for comp in ${comps[*]}; do
        kubectl config set-cluster ${CLUSTER_NAME} \
        --certificate-authority=${WORK_DIR}/ca.crt \
        --embed-certs=true \
        --server=https://${lb}:6443 \
        --kubeconfig=${WORK_DIR}/${comp}.kubeconfig
        
        kubectl config set-credentials system:${comp} \
        --client-certificate=${WORK_DIR}/${comp}.crt \
        --client-key=${WORK_DIR}/${comp}.key \
        --embed-certs=true \
        --kubeconfig=${WORK_DIR}/${comp}.kubeconfig
        
        kubectl config set-context default \
        --cluster=${CLUSTER_NAME} \
        --user=system:${comp} \
        --kubeconfig=${WORK_DIR}/${comp}.kubeconfig
        
        kubectl config use-context default --kubeconfig=${WORK_DIR}/${comp}.kubeconfig
    done
}

jobico::kube::kubeconfig::deploy_to_nodes(){
    local workers=($(jobico::kube::dao::query_db worker))
    for host in ${workers[*]}; do
        ssh root@$host "mkdir -p /var/lib/{kube-proxy,kubelet}"
        scp ${WORK_DIR}/kube-proxy.kubeconfig \
        root@$host:/var/lib/kube-proxy/kubeconfig
        scp ${WORK_DIR}/${host}.kubeconfig \
        root@$host:/var/lib/kubelet/kubeconfig
    done
}

jobico::kube::kubeconfig::deploy_to_server(){
    local servers=($(jobico::kube::dao::query_cluster_db server 2))
    for host in ${servers[*]}; do
        scp ${WORK_DIR}/admin.kubeconfig \
        ${WORK_DIR}/kube-controller-manager.kubeconfig \
        ${WORK_DIR}/kube-scheduler.kubeconfig \
            root@$host:~/
    done
}

# Encryption key

jobico::kube::encryption::gen_key(){
    cat > ${WORK_DIR}/encryption-config.yaml \
<<EOF
  kind: EncryptionConfig
  apiVersion: v1
  resources:
    - resources:
        - secrets
      providers:
        - aescbc:
            keys:
              - name: key1
                secret: ${ENCRYPTION_KEY}
        - identity: {}
EOF
}

jobico::kube::encryption::deploy_key_to_server(){
    local servers=($(jobico::kube::dao::query_cluster_db server 2))
    for host in ${servers[*]}; do
        scp ${WORK_DIR}/encryption-config.yaml root@$host:~/
    done
}

# etcd
jobico::kube::etcd::get_etcd_cluster(){
    local cluster=""
    local i=0
    while read IP FQDN HOST SUBNET TYPE; do
        if [ "${TYPE}" == "server" ]; then
            if [ -n "$cluster" ]; then
                cluster="${cluster},"
            fi
            cluster="${cluster}master-${i}=https://${IP}:2380"
            ((i++))
        fi
    done < ${WORK_DIR}/cluster.txt
    echo "${cluster}"
}
jobico::kube::etcd::gen_etcd_services(){
    local cluster=$(jobico::kube::etcd::get_etcd_cluster)
    local clustere=$(escape ${cluster})
    local i=0
    while read IP FQDN HOST SUBNET TYPE; do
        if [ "${TYPE}" == "server" ]; then
            file=${WORK_DIR}/etcd-${HOST}.service
            cp ${EXTRAS_DIR}/units/etcd.service.tmpl ${file}
            sed -i "s/{IP}/${IP}/g" "${file}"
            sed -i "s/{ETCD_NAME}/${HOST}/g" "${file}" 
            sed -i "s/{CLUSTER}/$clustere/g" "${file}"
        fi
    done < ${WORK_DIR}/cluster.txt
}
jobico::kube::etcd::install_to_server(){
    local i=0
    local servers=($(jobico::kube::dao::query_cluster_db server 3))
    for host in ${servers[*]}; do
        file=${WORK_DIR}/etcd-${host}.service
        scp ${file} root@${host}:~/etcd.service 
        scp ${DOWNLOADS_DIR}/etcd-v3.4.27-linux-amd64.tar.gz root@${host}:~/
        ssh root@$host << 'EOF'
tar -xvf ~/etcd-v3.4.27-linux-amd64.tar.gz
mv ~/etcd-v3.4.27-linux-amd64/etcd* /usr/local/bin
mkdir -p /etc/etcd /var/lib/etcd
cp ca.crt \
kube-api-server.key \
kube-api-server.crt \
etcd-server.crt \
etcd-server.key /etc/etcd/
mv ~/etcd.service /etc/systemd/system
systemctl daemon-reload
systemctl enable etcd
systemctl start etcd
etcdctl member list
EOF

        ((i++))
    done
}

# Server deployment

jobico::kube::deploy_deps_to_server(){
    local servers=($(jobico::kube::dao::query_cluster_db server 2))
    for host in ${servers[*]}; do
        scp ${DOWNLOADS_DIR}/kube-apiserver \
        ${DOWNLOADS_DIR}/kube-controller-manager \
        ${DOWNLOADS_DIR}/kube-scheduler \
        ${DOWNLOADS_DIR}/kubectl \
        ${EXTRAS_DIR}/units/kube-apiserver.service \
        ${EXTRAS_DIR}/units/kube-controller-manager.service \
        ${EXTRAS_DIR}/units/kube-scheduler.service \
        ${EXTRAS_DIR}/configs/kube-scheduler.yaml \
        ${EXTRAS_DIR}/configs/kube-apiserver-to-kubelet.yaml root@server:~/
    
        ssh root@$host \
<< 'EOF'
  mkdir -p /etc/kubernetes/config
  chmod +x kube-apiserver \
    kube-controller-manager \
    kube-scheduler kubectl

  mv kube-apiserver \
    kube-controller-manager \
    kube-scheduler kubectl \
    /usr/local/bin

  mkdir -p /var/lib/kubernetes

  mv ca.crt ca.key \
    kube-api-server.key kube-api-server.crt \
    service-accounts.key service-accounts.crt \
    encryption-config.yaml \
    /var/lib/kubernetes

  mv kube-apiserver.service \
    /etc/systemd/system/kube-apiserver.service

  mv kube-controller-manager.kubeconfig /var/lib/kubernetes/
  mv kube-controller-manager.service /etc/systemd/system/
  mv kube-scheduler.kubeconfig /var/lib/kubernetes/
  mv kube-scheduler.yaml /etc/kubernetes/config/
  mv kube-scheduler.service /etc/systemd/system/

  systemctl daemon-reload
  systemctl enable kube-apiserver \
    kube-controller-manager kube-scheduler

  systemctl start kube-apiserver \
    kube-controller-manager kube-scheduler

  sleep 10

  kubectl cluster-info \
    --kubeconfig admin.kubeconfig

  kubectl apply -f kube-apiserver-to-kubelet.yaml \
    --kubeconfig admin.kubeconfig

EOF
    done
}

# Nodes deployment

jobico::kube::deploy_deps_to_nodes(){
    local workers=($(jobico::kube::dao::query_db worker))
    for host in ${workers[*]}; do
        subnets=$(grep $host $MACHINES_DB | cut -d " " -f 4)
        sed "s|SUBNET|${subnets}|g" \
        ${EXTRAS_DIR}/configs/10-bridge.conf > ${WORK_DIR}/10-bridge.conf
        
        sed "s|SUBNET|${subnets}|g" \
        ${EXTRAS_DIR}/configs/kubelet-config.yaml > ${WORK_DIR}/kubelet-config.yaml
        
        scp ${WORK_DIR}/10-bridge.conf \
        ${WORK_DIR}/kubelet-config.yaml \
        root@$host:~/
    done
    
    for host in ${workers[*]}; do
        scp ${DOWNLOADS_DIR}/runc.amd64 \
        ${DOWNLOADS_DIR}/crictl-v1.28.0-linux-amd64.tar.gz \
        ${DOWNLOADS_DIR}/cni-plugins-linux-amd64-v1.3.0.tgz \
        ${DOWNLOADS_DIR}/containerd-1.7.8-linux-amd64.tar.gz \
        ${DOWNLOADS_DIR}/kubectl \
        ${DOWNLOADS_DIR}/kubelet \
        ${DOWNLOADS_DIR}/kube-proxy \
        ${EXTRAS_DIR}/configs/99-loopback.conf \
        ${EXTRAS_DIR}/configs/containerd-config.toml \
        ${EXTRAS_DIR}/configs/kube-proxy-config.yaml \
        ${EXTRAS_DIR}/units/containerd.service \
        ${EXTRAS_DIR}/units/kubelet.service \
        ${EXTRAS_DIR}/units/kube-proxy.service root@$host:~/
    done
    
    for host in ${workers[*]}; do
        ssh root@$host \
<< 'EOF'

  swapoff -a

  mkdir -p \
    /etc/cni/net.d \
    /opt/cni/bin \
    /var/lib/kubelet \
    /var/lib/kube-proxy \
    /var/lib/kubernetes \
    /var/run/kubernetes

  mkdir -p containerd
  tar -xvf crictl-v1.28.0-linux-amd64.tar.gz
  tar -xvf containerd-1.7.8-linux-amd64.tar.gz -C containerd
  tar -xvf cni-plugins-linux-amd64-v1.3.0.tgz -C /opt/cni/bin/
  mv runc.amd64 runc
  chmod +x crictl kubectl kube-proxy kubelet runc
  mv crictl kubectl kube-proxy kubelet runc /usr/local/bin/
  mv containerd/bin/* /bin/

  mv 10-bridge.conf 99-loopback.conf /etc/cni/net.d/
  mkdir -p /etc/containerd/
  mv containerd-config.toml /etc/containerd/config.toml
  mv containerd.service /etc/systemd/system/
  mv kubelet-config.yaml /var/lib/kubelet/
  mv kubelet.service /etc/systemd/system/
  mv kube-proxy-config.yaml /var/lib/kube-proxy/
  mv kube-proxy.service /etc/systemd/system/

  systemctl daemon-reload
  systemctl enable containerd kubelet kube-proxy
  systemctl start containerd kubelet kube-proxy

EOF
        
    done
}

# Local env

jobico::kube::cluster::set_local_deps(){
    jobico::kube::init::locals
    jobico::kube::kubeconfig::gen_locally_for_kube_admin
}
jobico::kube::init::locals(){
    if ! grep -q "locals" "${STATUS_FILE}"; then
        sudo cp ${DOWNLOADS_DIR}/kubectl /usr/local/bin && \
        sudo chmod +x /usr/local/bin/kubectl
        jobico::kube::set_done "locals"
    fi
}
jobico::kube::kubeconfig::gen_locally_for_kube_admin(){
    kubectl config set-cluster ${CLUSTER_NAME} \
    --certificate-authority=${WORK_DIR}/ca.crt \
    --embed-certs=true \
    --server=https://server.kubernetes.local:6443
    
    kubectl config set-credentials admin \
    --client-certificate=${WORK_DIR}/admin.crt \
    --client-key=${WORK_DIR}/admin.key
    
    kubectl config set-context ${CLUSTER_NAME} \
    --cluster=${CLUSTER_NAME} \
    --user=admin
    
    kubectl config use-context ${CLUSTER_NAME}
}

# Routes

jobico::kube::cluster::add_routes(){
    servers=($(jobico::kube::dao::query_db control_plane))
    workers=($(jobico::kube::dao::query_db worker))
    for server in "${servers[@]}"; do
        for worker in "${workers[@]}"; do
            node_ip=$(grep ${worker} ${MACHINES_DB} | cut -d " " -f 1)
            node_subnet=$(grep ${worker} ${MACHINES_DB} | cut -d " " -f 4)
            ssh root@${server} \
<<EOF
    ip route add ${node_subnet} via ${node_ip}
EOF
        done
    done
    
    
    for worker1 in "${workers[@]}"; do
        for worker2 in "${workers[@]}"; do
            if [ "$worker1" != "$worker2" ]; then
                node_ip=$(grep ${worker2} ${MACHINES_DB} | cut -d " " -f 1)
                node_subnet=$(grep ${worker2}  ${MACHINES_DB} | cut -d " " -f 4)
                
                ssh root@${worker1} \
<<EOF
    ip route add ${node_subnet} via ${node_ip}
EOF
                
            fi
        done
    done
}


## Support

jobico::kube::set_done(){
    echo "|$1|" >> ${WORK_DIR}/jobico_status
}
jobico::kube::wait_for_vms_ssh() {
    local port=22
    local timeout=60  
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
## Debug utils
jobico::kube::gen_and_print_databases_info(){
    if [ ! -f "${MACHINES_DB}" ]; then
        jobico::kube::init_local_files
        jobico::kube::dao::gen_databases $1 $2
        jobico::kube::gen_hostsfile
        jobico::kube::etcd::gen_etcd_services
        jobico::kube::tls::gen_ca_conf
        jobico::kube::tls::gen_ca
        jobico::kube::tls::gen_certs
    fi
    jobico::kube::print_databases_info
}
jobico::kube::print_databases_info(){
    workers=($(jobico::kube::dao::query_db worker))
    vip=$(jobico::kube::dao::query_cluster_db lbvip 1)
    vipdns=$(jobico::kube::dao::query_cluster_db lbvip 2)
    cluster=$(jobico::kube::etcd::get_etcd_cluster)
    serversip=($(jobico::kube::dao::query_cluster_db server 1))
    servers=($(jobico::kube::dao::query_db control_plane))
    gencert=($(jobico::kube::dao::query_db gencert))
    kubeconfig=($(jobico::kube::dao::query_db genkubeconfig))
    echo "----------cluster-----------"
    echo "${cluster}"
    echo "------------vip-------------"
    echo "${vip}"
    echo "${vipdns}"
    echo "---------workers------------"
    print_array ${workers[@]}
    echo "---------servers------------"
    print_array ${servers[@]}
    echo "---------servers ips--------"
    print_array ${serversip[@]}
    echo "---------servers ip---------"
    while read IP FQDN HOST SUBNET TYPE; do
        if [ "${TYPE}" == "server" ]; then
            echo "IP:$IP FQDN:$FQDN HOST:$HOST SUBNET:$SUBNET TYPE:$TYPE"
        fi
    done < ${WORK_DIR}/cluster.txt
    echo "------certificates----------"
    print_array ${gencert[@]}
    echo "--------kubeconfig----------"
    print_array ${kubeconfig[@]}
    echo "---------cluster------------"
    while read IP FQDN HOST SUBNET TYPE; do
        echo "IP:$IP FQDN:$FQDN HOST:$HOST SUBNET:$SUBNET TYPE:$TYPE"
    done < ${JOBICO_CLUSTER_TBL}
    echo "---------routes------------"
    
    for worker1 in "${workers[@]}"; do
        for worker2 in "${workers[@]}"; do
            if [ "$worker1" != "$worker2" ]; then
                node_ip=$(grep ${worker2} ${MACHINES_DB} | cut -d " " -f 1)
                node_subnet=$(grep ${worker2}  ${MACHINES_DB} | cut -d " " -f 4)
                echo "ssh root at ${worker1}"
                echo "to add route ${node_subnet} via ${node_ip}"
            fi
        done
    done
}
