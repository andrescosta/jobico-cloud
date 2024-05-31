kube::etcd::get_etcd_cluster(){
    local cluster=""
    local i=0
    local n_servers=$(kube::dao::cluster::count server)
    if [ ${n_servers} -eq 1 ]; then
       while read IP FQDN HOST SUBNET TYPE SCH; do
            cluster="${HOST}=https://${IP}:2380"
        done < <(kube::dao::cluster::servers)
    else
        while read IP FQDN HOST SUBNET TYPE SCH; do
           if [ -n "$cluster" ]; then
                 cluster="${cluster},"
           fi
           cluster="${cluster}server-${i}=https://${IP}:2380"
           ((i=i+1))
        done < <(kube::dao::cluster::servers)
    fi
    echo "${cluster}"
}
kube::etcd::get_etcd_servers(){
    local cluster=""
    local i=0
    while read IP FQDN HOST SUBNET TYPE SCH; do
            if [ -n "$cluster" ]; then
                cluster="${cluster},"
            fi
            cluster="${cluster}https://${IP}:2379"
            ((i=i+1))
    done < <(kube::dao::cluster::servers)
    echo "${cluster}"
}
kube::etcd::gen_etcd_service(){
    local cluster=$(kube::etcd::get_etcd_cluster)
    local clustere=$(escape ${cluster})
    local i=0
    while read IP FQDN HOST SUBNET TYPE SCH; do
        file=${WORK_DIR}/etcd-${IP}.service
        cp ${EXTRAS_DIR}/units/etcd.service.tmpl ${file}
        sed -i "s/{IP}/${IP}/g" "${file}"
        sed -i "s/{ETCD_NAME}/${HOST}/g" "${file}" 
        sed -i "s/{CLUSTER}/$clustere/g" "${file}"
    done < <(kube::dao::cluster::servers)
}
kube::etcd::deploy(){
    local i=0
    local servers=($(kube::dao::cluster::get server 1))
    for host in ${servers[*]}; do
        file=${WORK_DIR}/etcd-${host}.service
        SCP ${file} root@${host}:~/etcd.service 
        SCP ${DOWNLOADS_DIR}/etcd-v3.4.27-linux-amd64.tar.gz root@${host}:~/
        SSH root@$host << 'EOF'
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
EOF

        ((i=i+1))
    done
}

