jobico::debug::print() {
    local n_servers=$(jobico::dao::cluster::count server)
    local comps=($(jobico::dao::cpl::get gencert 3))
    local workers=($(jobico::dao::cpl::get worker))
    local vip=$(jobico::dao::cluster::lb 1)
    local vipdns=$(jobico::dao::cluster::lb 2)
    local viphost=$(jobico::dao::cluster::lb 3)
    local cluster=$(jobico::etcd::get_cluster)
    local serversip=($(jobico::dao::cluster::get server 1))
    local nodes=($(jobico::dao::cluster::get node 3))
    local serversfqdn=($(jobico::dao::cluster::get server 2))
    local servershost=($(jobico::dao::cluster::get server 3))
    local lbs=($(jobico::dao::cluster::get lb 1))
    local servers=($(jobico::dao::cpl::get control_plane))
    local gencert=($(jobico::dao::cpl::get gencert 3))
    local kubeconfig=($(jobico::dao::cpl::get genkubeconfig 4))
    local etcd_servers=$(jobico::etcd::get_servers)
    local ccpl=($(jobico::dao::cpl::control_plane))
    local all_workers=($(jobico::dao::cpl::all_workers))
    local curr_workers=($(jobico::dao::cpl::curr_workers))
    local curr_nodes_cluster=($(jobico::dao::cluster::curr_nodes))
    echo "------------all--------------"
    jobico::dao::cluster::all | while read IP FQDN HOST SUBNET TYPE SCH; do
        echo "$IP $FQDN $HOST $SUBNET $TYPE"
    done
    echo "---------all nodes-------------"
    jobico::dao::cluster::all_nodes | while read IP FQDN HOST SUBNET TYPE SCH; do
        echo "$IP $FQDN $HOST $SUBNET $TYPE"
    done
    echo "------------members--------------"
    jobico::dao::cluster::members | while read IP FQDN HOST SUBNET TYPE SCH; do
        if [[ -z $HOST ]]; then
            echo "ll"
        else
            echo "$HOST"
        fi
    done
    echo "---------cpl-----------------"
    print_array ${ccpl[@]}
    echo "---------all workers---------"
    print_array ${all_workers[@]}
    echo "---------curr workers--------"
    print_array ${curr_workers[@]}
    echo "---------curr nodes----------"
    print_array ${curr_nodes_cluster[@]}
    echo "---------workers------------"
    print_array ${workers[@]}
    echo "---------- nodes ------------"
    print_array "${nodes[@]}"
    echo "-----curr node cluster-------"
    jobico::dao::cluster::curr_nodes | while read IP FQDN HOST SUBNET TYPE SCH; do
        echo "$IP $FQDN $HOST $SUBNET $TYPE"
    done
    echo "----------notvip------------"
    jobico::dao::cluster::get_type_is "server" | while read IP FQDN HOST SUBNET TYPE SCH; do
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
    while read IP FQDN HOST SUBNET TYPE SCH; do
        if [ "${TYPE}" == "server" ]; then
            echo "IP:$IP FQDN:$FQDN HOST:$HOST SUBNET:$SUBNET TYPE:$TYPE"
        fi
    done <$(work_dir)/cluster.txt
    echo "------certificates----------"
    print_array ${gencert[@]}
    echo "--------kubeconfig----------"
    print_array ${kubeconfig[@]}
    echo "---------cluster------------"
    while read IP FQDN HOST SUBNET TYPE SCH; do
        echo "IP:$IP FQDN:$FQDN HOST:$HOST SUBNET:$SUBNET TYPE:$TYPE"
    done <${JOBICO_CLUSTER_TBL}
    echo "---------routes------------"

    for worker1 in "${workers[@]}"; do
        for worker2 in "${workers[@]}"; do
            if [ "$worker1" != "$worker2" ]; then
                node_ip=$(grep ${worker2} ${MACHINES_DB} | cut -d " " -f 1)
                node_subnet=$(grep ${worker2} ${MACHINES_DB} | cut -d " " -f 4)
                echo "SSH root at ${worker1}"
                echo "to add route ${node_subnet} via ${node_ip}"
            fi
        done
    done
}
