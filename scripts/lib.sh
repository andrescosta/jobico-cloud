
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
readonly LB_NAME=lb
readonly MACHINES_DB="${WORK_DIR}/cluster.txt"
readonly DOWNLOADS_TBL=${EXTRAS_DIR}/downloads/downloads_amd64.txt
readonly JOBICO_CLUSTER_TBL=${MACHINES_DB}
readonly ENCRYPTION_KEY=$(head -c 32 /dev/urandom | base64)
readonly BEGIN_HOSTS_FILE="#B> Kubernetes Cluster"
readonly END_HOSTS_FILE="#E> Kubernetes Cluster"
_DEBUG="off"
_DRY_RUN=false

# Public API

kube::cluster(){
    local number_of_nodes=$1
    local number_of_cpl_nodes=$2
    local number_of_lbs=$3
    kube::init_local_files
    kube::dao::gen_databases $number_of_nodes $number_of_cpl_nodes $number_of_lbs
    DEBUG kube::debug::print
    kube::create_vms
    kube::download_all
    kube::create_cluster
}

kube::destroy_cluster(){
    if [ ! -e ${MACHINES_DB} ]; then
        echo "${MACHINES_DB} does not exist"
        exit 1
    fi
    if [ ! -e ${WORK_DIR}/db.txt ]; then
        echo "${WORK_DIR}/db.txt does not exist"
        exit 1
    fi
    NOT_DRY_RUN kube::destroy_vms
    NOT_DRY_RUN kube::host::restore_local_etc_hosts
}

kube::gen_local_deps(){
    kube::init::locals
    kube::kubeconfig::gen_locally_for_kube_admin
}

# Controllers

kube::create_vms(){
    if ! grep -q "machines" ${STATUS_FILE}; then
        NOT_DRY_RUN kube::create_kvm_vms
        NOT_DRY_RUN kube::wait_for_vms_ssh
        kube::set_done "machines"
    fi
}
kube::download_all(){
    if ! grep -q "downloads" "${STATUS_FILE}"; then
        NOT_DRY_RUN kube::deps::download
        kube::set_done "downloads"
    fi
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

# Implementations

## Local env

kube::init_local_files(){
    mkdir -p ${WORK_DIR}
    touch ${STATUS_FILE}
}

## KVM VMs

kube::create_kvm_vms(){
     kube::dao::cluster::machines | while read IP FQDN HOST SUBNET TYPE; do
        make -f scripts/Makefile.vm new-vm-${TYPE} VM_IP=${IP} VM_NAME=${HOST}
    done 
}

kube::destroy_vms(){
    kube::dao::cluster::machines | while read IP FQDN HOST SUBNET TYPE; do
        make -f scripts/Makefile.vm destroy-vm VM_IP=${IP} VM_NAME=${HOST}
    done 
}

## DAO 

kube::dao::gen_databases(){
    local number_of_nodes=$1
    local number_of_cpl_nodes=$2
    local number_of_lbs=$3
    kube::dao::gen_db $number_of_nodes $number_of_cpl_nodes $number_of_lbs
    kube::dao::gen_cluster_db
}

kube::dao::gen_db(){
    local total_workers=$1
    local total_cpl_nodes=$2
    local total_of_lbs=$3
    cp ${EXTRAS_DIR}/db/db.txt.tmpl ${WORK_DIR}/db.txt
    if [ $total_cpl_nodes -gt 1 ]; then
        echo "server lbvip" >> ${WORK_DIR}/db.txt
        for ((i=0;i<total_of_lbs;i++)); do
            echo "$LB_NAME-$i lb" >> ${WORK_DIR}/db.txt
        done
        for ((i=0;i<total_cpl_nodes;i++)); do
            echo "$SERVER_NAME-$i control_plane" >> ${WORK_DIR}/db.txt
        done
    else
        echo "server control_plane" >> ${WORK_DIR}/db.txt
    fi
    for ((i=0;i<total_workers;i++)); do
        echo "$WORKER_NAME-$i worker gencert" >> ${WORK_DIR}/db.txt
    done
}

kube::dao::gen_cluster_db(){
    rm -f ${MACHINES_DB}
    local workers=($(kube::dao::cpl::get worker))
    local servers=($(kube::dao::cpl::get control_plane))
    local lbs=($(kube::dao::cpl::get lb))
    local lbvip=$(kube::dao::cpl::get lbvip)
    local host_1=7
    if [ "${#servers[@]}" -gt 1 ]; then
        if [ lbvip != "" ]; then 
            echo "192.168.122.${host_1} ${lbvip}.kubernetes.local ${lbvip} 0.0.0.0/24 lbvip" >> ${MACHINES_DB}
            ((host_1++))
        fi
        for lb in "${lbs[@]}"; do
            echo "192.168.122.${host_1} ${lb}.kubernetes.local ${lb} 0.0.0.0/24 lb" >> ${MACHINES_DB}
            ((host_1++))
        done
        for svr in "${servers[@]}"; do
            echo "192.168.122.${host_1} ${svr}.kubernetes.local ${svr} 0.0.0.0/24 server" >> ${MACHINES_DB}
            ((host_1++))
        done
    else
        svr=${servers[0]}
        echo "192.168.122.${host_1} ${svr}.kubernetes.local ${svr} 0.0.0.0/24 server" >> ${MACHINES_DB}
        ((host_1++))
    fi
    local host_2=0
    for wkr in "${workers[@]}"; do
        echo "192.168.122.${host_1} ${wkr}.kubernetes.local ${wkr} 10.200.${host_2}.0/24 node" >> ${MACHINES_DB}
        ((host_1++))
        ((host_2++))
    done
}

kube::dao::cpl::get(){
    colf="${2:-2}"
    local values=($(awk -v value="$1" -v col="1" -v cole="$colf" '$cole == value {print $col}' ${WORK_DIR}/db.txt))
    for e in "${values[@]}"; do
        echo "$e"
    done
}
kube::dao::cpl::getby(){
    local values=$(awk -v value="$1" '$2 == value {print $0}' ${WORK_DIR}/db.txt)
    echo "$values"
}

kube::dao::cluster::machines(){
    echo "$(kube::dao::cluster::get_type_is_not "lbvip")"
}
kube::dao::cluster::lb(){
    local lb=$(kube::dao::cluster::get lbvip $1)
    if [ -z ${lb} ]; then 
        lb=$(kube::dao::cluster::get server $1)
    fi
    echo "${lb}"
}
kube::dao::cluster::get_type_is_not(){ 
    local result=$(awk -v value="$1" '$5 != value {print $0}' ${WORK_DIR}/cluster.txt)
    echo "$result"
}
kube::dao::cluster::get_type_is(){ 
    local result=$(awk -v value="$1" '$5 == value {print $0}' ${WORK_DIR}/cluster.txt)
    echo "$result"
}
kube::dao::cluster::get(){
    local values=($(awk -v value="$1" -v col="$2"  '$5 == value {print $col}' ${WORK_DIR}/cluster.txt))
    for e in "${values[@]}"; do
        echo "$e"
    done
}
kube::dao::cluster::count(){
    local value=$(awk -v value="$1" '$5 == value {count++} END {print count}' ${WORK_DIR}/cluster.txt)
    echo "$value"
}

## Hosts files

kube::host::gen_hostsfile(){
    echo ${BEGIN_HOSTS_FILE} > ${HOSTSFILE}
    while read IP FQDN HOST SUBNET TYPE; do
        entry="${IP} ${FQDN} ${HOST}"
        echo ${entry} >> ${HOSTSFILE}
    done < ${JOBICO_CLUSTER_TBL}
    echo  ${END_HOSTS_FILE}>> ${HOSTSFILE}
}
kube::host::update_local_etc_hosts(){
    local cmd="cat ${HOSTSFILE} >> /etc/hosts"
    sudo bash -c "$cmd"
}
kube::host::restore_local_etc_hosts(){
    sed "/${BEGIN_HOSTS_FILE}/,/${END_HOSTS_FILE}/d" /etc/hosts > ${WORK_DIR}/uhosts
    sudo bash -c "cp ${WORK_DIR}/uhosts /etc/hosts"
}
kube::host::update_local_known_hosts(){
     kube::dao::cluster::machines | while read IP FQDN HOST SUBNET TYPE; do
        ssh-keyscan -H ${HOST} >> ~/.ssh/known_hosts
        ssh-keyscan -H ${IP} >> ~/.ssh/known_hosts
    done 
}
kube::host::set_machines_hostname(){
    kube::dao::cluster::machines | while read IP FQDN HOST SUBNET TYPE; do
        cmd="sed -i 's/^127.0.0.1.*/127.0.1.1\t${FQDN} ${HOST}/' /etc/hosts"
        ssh -n root@${IP} "${cmd}"
        ssh -n root@${IP} hostnamectl hostname ${HOST}
    done 
}
kube::host::update_machines_etc_hosts(){
     kube::dao::cluster::machines | while read IP FQDN HOST SUBNET TYPE; do
        scp  ${HOSTSFILE} root@${IP}:~/
        ssh -n \
            root@${IP} "cat hosts >> /etc/hosts"
    done 
}

## TLS

kube::tls::gen_ca_conf(){
    cp ${EXTRAS_DIR}/tls/ca.conf.tmpl ${CA_CONF}
    local workers=($(kube::dao::cpl::get worker))
    local new_ca=""
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
    done < ${JOBICO_CLUSTER_TBL}
    sed -i "s/{ETCD_IPS}/$ips/g" "${CA_CONF}"
    sed -i "s/{ETCD_DNS}/$dns/g" "${CA_CONF}"
    sed -i "s/{API_SERVER_IPS}/$ips/g" "${CA_CONF}"
   
    local vip=$(kube::dao::cluster::lb 1)
    local vipname=$(kube::dao::cluster::lb 2)
    sed -i "s/{LB_IP}/${vip}/g" "${CA_CONF}"
    sed -i "s/{LB_DNS}/${vipname}/g" "${CA_CONF}"
}
kube::tls::gen_ca(){
    openssl genrsa -out ${WORK_DIR}/ca.key 4096
    openssl req -x509 -new -sha512 -noenc \
    -key ${WORK_DIR}/ca.key -days 3653 \
    -config ${CA_CONF}\
    -out ${WORK_DIR}/ca.crt
}

kube::tls::gen_certs(){
    local comps=($(kube::dao::cpl::get gencert 3))
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

kube::tls::deploy_to_nodes(){
    local workers=($(kube::dao::cpl::get worker))
    for host in ${workers[*]}; do
        ssh root@$host mkdir -p /var/lib/kubelet/
        
        scp ${WORK_DIR}/ca.crt root@$host:/var/lib/kubelet/
        
        scp ${WORK_DIR}/$host.crt \
        root@$host:/var/lib/kubelet/kubelet.crt
        
        scp ${WORK_DIR}/$host.key \
        root@$host:/var/lib/kubelet/kubelet.key
    done
}

kube::tls::deploy_to_server(){
    local servers=($(kube::dao::cluster::get server 1))
    for host in ${servers[*]}; do
        scp \
            ${WORK_DIR}/ca.key ${WORK_DIR}/ca.crt \
            ${WORK_DIR}/kube-api-server.key ${WORK_DIR}/kube-api-server.crt \
        ${WORK_DIR}/service-accounts.key ${WORK_DIR}/service-accounts.crt \
        ${WORK_DIR}/etcd-server.key ${WORK_DIR}/etcd-server.crt \
        root@$host:~/
    done
}

## Kubeconfig

kube::kubeconfig::gen_for_nodes(){
    local workers=($(kube::dao::cpl::get worker))
    local lb=$(kube::dao::cluster::lb 2)
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
kube::kubeconfig::gen_for_controlplane(){
    local comps=($(kube::dao::cpl::get genkubeconfig 4))
    local lb=$(kube::dao::cluster::lb 2)
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

kube::kubeconfig::deploy_to_nodes(){
    local workers=($(kube::dao::cpl::get worker))
    for host in ${workers[*]}; do
        ssh root@$host "mkdir -p /var/lib/{kube-proxy,kubelet}"
        scp ${WORK_DIR}/kube-proxy.kubeconfig \
        root@$host:/var/lib/kube-proxy/kubeconfig
        scp ${WORK_DIR}/${host}.kubeconfig \
        root@$host:/var/lib/kubelet/kubeconfig
    done
}

kube::kubeconfig::deploy_to_server(){
    local servers=($(kube::dao::cluster::get server 1))
    for host in ${servers[*]}; do
        scp ${WORK_DIR}/admin.kubeconfig \
        ${WORK_DIR}/kube-controller-manager.kubeconfig \
        ${WORK_DIR}/kube-scheduler.kubeconfig \
            root@$host:~/
    done
}

## HA Proxy

kube::haproxy::gen_cfg(){
    local vip=$(kube::dao::cluster::lb 1)
    cp  ${EXTRAS_DIR}/configs/haproxy.cfg.tmpl ${WORK_DIR}/haproxy.cfg
    local servers=""
    while read IP FQDN HOST SUBNET TYPE; do
        if [ "${TYPE}" == "server" ]; then
            servers="${servers}    server ${HOST} ${IP}:6443 check fall 3 rise 2\n"
        fi
    done < ${WORK_DIR}/cluster.txt
    sed -i "s/{LB_IPS}/${servers}/g" "${WORK_DIR}/haproxy.cfg" 
    servers=($(kube::dao::cluster::get lb 1))
    for ip1 in ${servers[*]}; do
        file="${WORK_DIR}/keepalived${ip1}.conf"
        cp  ${EXTRAS_DIR}/configs/keepalived.conf.tmpl ${file} 
        sed -i "s/{IP}/${ip1}/g" "${file}" 
        sed -i "s/{VIP}/${vip}/g" "${file}" 
        ips=""
        for ip2 in ${servers[*]}; do
            if [ "${ip1}" != "${ip2}" ]; then
                ips="${ips}    ${ip2}\n"
            fi
        done
        sed -i "s/{LB_IPS}/${ips}/g" "${file}" 
    done
}

kube::haproxy::deploy(){
    local servers=($(kube::dao::cluster::get lb 1))
    for ip in ${servers[*]}; do
        scp ${WORK_DIR}/haproxy.cfg root@${ip}:~/ 
        scp ${WORK_DIR}/keepalived${ip}.conf root@${ip}:~/keepalived.conf
        ssh root@$ip << 'EOF'
cloud-init status --wait > /dev/null
cat ~/haproxy.cfg >> /etc/haproxy/haproxy.cfg
cp ~/keepalived.conf /etc/keepalived
systemctl reload haproxy 
systemctl restart keepalived
EOF
    done
}

# Encryption key

kube::encryption::gen_key(){
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

kube::encryption::deploy(){
    local servers=($(kube::dao::cluster::get server 1))
    for host in ${servers[*]}; do
        scp ${WORK_DIR}/encryption-config.yaml root@$host:~/
    done
}

## etcd

kube::etcd::get_etcd_cluster(){
    local cluster=""
    local i=0
    local n_servers=$(kube::dao::cluster::count server)
    if [ ${n_servers} -eq 1 ]; then
       while read IP FQDN HOST SUBNET TYPE; do
            if [ "${TYPE}" == "server" ]; then
                cluster="${HOST}=https://${IP}:2380"
                break
            fi
       done < ${WORK_DIR}/cluster.txt
    else
       while read IP FQDN HOST SUBNET TYPE; do
            if [ "${TYPE}" == "server" ]; then
                if [ -n "$cluster" ]; then
                    cluster="${cluster},"
                fi
                cluster="${cluster}server-${i}=https://${IP}:2380"
                ((i++))
            fi
        done < ${WORK_DIR}/cluster.txt
    fi
    echo "${cluster}"
}
kube::etcd::get_etcd_servers(){
    local cluster=""
    local i=0
    while read IP FQDN HOST SUBNET TYPE; do
        if [ "${TYPE}" == "server" ]; then
            if [ -n "$cluster" ]; then
                cluster="${cluster},"
            fi
            cluster="${cluster}https://${IP}:2379"
            ((i++))
        fi
    done < ${WORK_DIR}/cluster.txt
    echo "${cluster}"
}
kube::etcd::gen_etcd_service(){
    local cluster=$(kube::etcd::get_etcd_cluster)
    local clustere=$(escape ${cluster})
    local i=0
    while read IP FQDN HOST SUBNET TYPE; do
        if [ "${TYPE}" == "server" ]; then
            file=${WORK_DIR}/etcd-${IP}.service
            cp ${EXTRAS_DIR}/units/etcd.service.tmpl ${file}
            sed -i "s/{IP}/${IP}/g" "${file}"
            sed -i "s/{ETCD_NAME}/${HOST}/g" "${file}" 
            sed -i "s/{CLUSTER}/$clustere/g" "${file}"
        fi
    done < ${WORK_DIR}/cluster.txt
}
kube::etcd::deploy(){
    local i=0
    local servers=($(kube::dao::cluster::get server 1))
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

## Control plane

kube::cpl::gen_kubeapiserver_service(){
    local etcd_servers=$(escape $(kube::etcd::get_etcd_servers))
    local n_servers=$(kube::dao::cluster::count server)
    cp ${EXTRAS_DIR}/units/kube-apiserver.service.tmpl ${WORK_DIR}/kube-apiserver.service   
    sed -i "s/{ETCD_SERVERS}/${etcd_servers}/g" ${WORK_DIR}/kube-apiserver.service 
    sed -i "s/{SERVERS}/${n_servers}/g" ${WORK_DIR}/kube-apiserver.service 
}

## Deps

kube::deps::download(){
    mkdir -p ${DOWNLOADS_DIR}
    wget -q --https-only -P  ${DOWNLOADS_DIR} -i ${DOWNLOADS_TBL}
}

## Cluster set up

kube::cluster::deploy_to_server(){
    local servers=($(kube::dao::cluster::get server 1))
    for host in ${servers[*]}; do
        scp ${DOWNLOADS_DIR}/kube-apiserver \
        ${DOWNLOADS_DIR}/kube-controller-manager \
        ${DOWNLOADS_DIR}/kube-scheduler \
        ${DOWNLOADS_DIR}/kubectl \
        ${WORK_DIR}/kube-apiserver.service \
        ${EXTRAS_DIR}/units/kube-controller-manager.service \
        ${EXTRAS_DIR}/units/kube-scheduler.service \
        ${EXTRAS_DIR}/configs/kube-scheduler.yaml \
        ${EXTRAS_DIR}/configs/kube-apiserver-to-kubelet.yaml root@$host:~/
    
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

## Nodes deployment

kube::cluster::deploy_to_nodes(){
    local workers=($(kube::dao::cpl::get worker))
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

kube::cluster::add_routes(){
    servers=($(kube::dao::cpl::get control_plane))
    workers=($(kube::dao::cpl::get worker))
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

## Local env

kube::init::locals(){
    if ! grep -q "locals" "${STATUS_FILE}"; then
        sudo cp ${DOWNLOADS_DIR}/kubectl /usr/local/bin && \
        sudo chmod +x /usr/local/bin/kubectl
        kube::set_done "locals"
    fi
}
kube::kubeconfig::gen_for_kube_admin(){
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

## Support

kube::set_done(){
    echo "|$1|" >> ${WORK_DIR}/jobico_status
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

## Debug 
kube::debug::print(){
    local n_servers=$(kube::dao::cluster::count server)
    local comps=($(kube::dao::cpl::get gencert 3))
    local workers=($(kube::dao::cpl::get worker))
    local vip=$(kube::dao::cluster::lb 1)
    local vipdns=$(kube::dao::cluster::lb 2)
    local viphost=$(kube::dao::cluster::lb 3)
    local cluster=$(kube::etcd::get_etcd_cluster)
    local serversip=($(kube::dao::cluster::get server 1))
    local serversfqdn=($(kube::dao::cluster::get server 2))
    local servershost=($(kube::dao::cluster::get server 3))
    local lbs=($(kube::dao::cluster::get lb 1))
    local servers=($(kube::dao::cpl::get control_plane))
    local gencert=($(kube::dao::cpl::get gencert 3))
    local kubeconfig=($(kube::dao::cpl::get genkubeconfig 4))
    local etcd_servers=$(kube::etcd::get_etcd_servers)
    echo "----------notvip------------"
    kube::dao::select_type_cluster_db "server" | while read IP FQDN HOST SUBNET TYPE; do
        echo "$IP $FQDN $HOST $SUBNET $TYPE"
    done 
    echo "---------- certss ------------"
    print_array "${comps[@]}"
    echo "---------- etcd ------------"
    echo "$etcd_servers"
    echo "----------n servers --------"
    echo "$n_servers"
    echo "----------cluster-----------"
    echo "${cluster}"
    echo "------------vip-------------"
    echo "${vip}"
    echo "${vipdns}"
    echo "${viphost}"
    echo "---------workers------------"
    print_array ${workers[@]}
    echo "------------lb--------------"
    print_array ${lbs[@]}
    echo "---------servers------------"
    print_array ${servers[@]}
    echo "---------servers ips--------"
    print_array ${serversip[@]}
    echo "---------servers fqdn-------"
    print_array ${serversfqdn[@]}
    echo "--------servers host--------"
    print_array ${servershost[@]}
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
