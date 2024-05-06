
kube::debug::print(){
    local n_servers=$(kube::dao::cluster::count server)
    local comps=($(kube::dao::cpl::get gencert 3))
    local workers=($(kube::dao::cpl::get worker))
    local vip=$(kube::dao::cluster::lb 1)
    local vipdns=$(kube::dao::cluster::lb 2)
    local viphost=$(kube::dao::cluster::lb 3)
    local cluster=$(kube::etcd::get_etcd_cluster)
    local serversip=($(kube::dao::cluster::get server 1))
    local nodes=($(kube::dao::cluster::get node 3))
    local serversfqdn=($(kube::dao::cluster::get server 2))
    local servershost=($(kube::dao::cluster::get server 3))
    local lbs=($(kube::dao::cluster::get lb 1))
    local servers=($(kube::dao::cpl::get control_plane))
    local gencert=($(kube::dao::cpl::get gencert 3))
    local kubeconfig=($(kube::dao::cpl::get genkubeconfig 4))
    local etcd_servers=$(kube::etcd::get_etcd_servers)
    echo "------------all--------------"
    kube::dao::cluster::all | while read IP FQDN HOST SUBNET TYPE; do
        echo "$IP $FQDN $HOST $SUBNET $TYPE"
    done 
    echo "---------- nodes ------------"
    print_array "${nodes[@]}"
    echo "----------notvip------------"
    kube::dao::cluster::get_type_is "server" | while read IP FQDN HOST SUBNET TYPE; do
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
