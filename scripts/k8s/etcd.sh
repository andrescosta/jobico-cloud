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

