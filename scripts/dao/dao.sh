readonly FROM_HOST=7
readonly SCHEDULABLE="schedulable"
readonly NO_SCHEDULABLE="no_schedulable"
readonly SERVER_TAINTS="[CriticalAddonsOnly]"

machines_db(){
    echo "$(work_dir)/cluster.txt"
}

machines_new_db(){
    echo "$(work_dir)/cluster_patch.txt"
}

machines_db_lock(){
    echo "$(work_dir)/cluster_lock.txt"
}

jobico::dao::gen_databases() {
    local number_of_nodes=$1
    local number_of_cpl_nodes=$2
    local number_of_lbs=$3
    local schedulable_server=$4
    local vers=$5
    local domain=$6
    local str_node_configs=$7
    jobico::dao::gen_db $number_of_nodes $number_of_cpl_nodes $number_of_lbs $domain
    jobico::dao::gen_cluster_db $schedulable_server $str_node_configs 
}

jobico::dao::gen_db() {
    local total_workers=$1
    local total_cpl_nodes=$2
    local total_of_lbs=$3
    local domain=$4

    cp ${EXTRAS_DIR}/db/db.txt.tmpl $(work_dir)/db.txt
    sed -i "s/{DOMAIN}/$domain/g" $(work_dir)/db.txt
    if [ $total_cpl_nodes -gt 1 ]; then
        echo "server lbvip" >>$(work_dir)/db.txt
        for ((i = 0; i < total_of_lbs; i++)); do
            echo "$LB_NAME-$i lb" >>$(work_dir)/db.txt
        done
        for ((i = 0; i < total_cpl_nodes; i++)); do
            echo "$SERVER_NAME-$i control_plane gencert" >>$(work_dir)/db.txt
        done
    else
        echo "server control_plane gencert" >>$(work_dir)/db.txt
    fi
    for ((i = 0; i < total_workers; i++)); do
        echo "$WORKER_NAME-$i worker gencert" >>$(work_dir)/db.txt
    done
}
jobico::dao::gen_add_db() {
    local total_nodes=$(grep -c 'node-*' $(work_dir)/db.txt || true)
    local total_workers=$1
    ((total_workers = total_workers + total_nodes))
    for ((i = total_nodes; i < total_workers; i++)); do
        echo "$WORKER_NAME-$i worker gencert" >>$(work_dir)/db_patch.txt
    done
}
jobico::dao::gen_add_cluster_db() {
    local total_nodes=$(grep -c 'node-*' $(work_dir)/db.txt || true)
    local workers=($(jobico::dao::cpl::get worker))
    local total=$(wc -l <$(machines_db))
    ((host_1 = total + FROM_HOST))
    ((host_2 = total_nodes + 1))
    for wkr in "${workers[@]}"; do
        echo "192.168.122.${host_1} ${wkr}.kubernetes.local ${wkr} 10.200.${host_2}.0/24 node $SCHEDULABLE" >>$(machines_new_db)
        ((host_1 = host_1 + 1))
        ((host_2 = host_2 + 1))
    done
}
jobico::dao::merge_dbs() {
    cat $(machines_new_db) >>$(machines_db)
    cat $(work_dir)/db_patch.txt >>$(work_dir)/db.txt
    rm $(machines_new_db) $(work_dir)/db_patch.txt
}
jobico::dao::gen_cluster_db() {
    rm -f $(machines_db)
    local schedulable_server=$1
    local str_node_configs=$2
    declare -A node_configs
    kv::map::deserialize "$str_node_configs" node_configs
    local workers=($(jobico::dao::cpl::get worker))
    local servers=($(jobico::dao::cpl::get control_plane))
    local lbs=($(jobico::dao::cpl::get lb))
    local lbvip=$(jobico::dao::cpl::get lbvip)
    local host_1=${FROM_HOST}
    local host_2=0
    local svr_taints=$SERVER_TAINTS
    local cgroup_default="cgroupv2"
    if [ $schedulable_server == true ]; then
        svr_taints=$SCHEDULABLE
    fi
    if [ "${#servers[@]}" -gt 1 ]; then
        if [ -n "$lbvip" ]; then
            echo "192.168.122.${host_1} ${lbvip}.kubernetes.local ${lbvip} 0.0.0.0/24 lbvip $NO_SCHEDULABLE ${cgroup_default}" >>$(machines_db)
            ((host_1 = host_1 + 1))
        fi
        for lb in "${lbs[@]}"; do
            echo "192.168.122.${host_1} ${lb}.kubernetes.local ${lb} 0.0.0.0/24 lb $NO_SCHEDULABLE ${cgroup_default}" >>$(machines_db)
            ((host_1 = host_1 + 1))
        done
        for svr in "${servers[@]}"; do
            echo "192.168.122.${host_1} ${svr}.kubernetes.local ${svr} 10.200.${host_2}.0/24 server $svr_taints ${cgroup_default}" >>$(machines_db)
            ((host_1 = host_1 + 1))
            ((host_2 = host_2 + 1))
        done
    else
        svr=${servers[0]}
        echo "192.168.122.${host_1} ${svr}.kubernetes.local ${svr} 10.200.${host_2}.0/24 server $svr_taints ${cgroup_default}" >>$(machines_db)
        ((host_1 = host_1 + 1))
        ((host_2 = host_2 + 1))
    fi
    # Properties:
    # - cgroup: [v1|v2](v2 default)
    # - taints: +[keys](default, schedulable)
    # - size: [small|std] (std, default)
    # ex: --node1=taints=judge0;cgroup=v1;size=small --node0=size=std
    # if --node(n) is not defined, the defaults are used to create it: cgroup=v2, no tains and size standard.
    local taints=$SCHEDULABLE
    local size=""
    local cgroup="v2"
    local node_config
    local node_type
    for wkr in "${workers[@]}"; do
        node_type="node"
        cgroup="v2"
        taints=$SCHEDULABLE
        if [[ -v node_configs[$wkr] ]]; then
            node_config=${node_configs[$wkr]}
            cgroup=$(kv::map::get_param_value "$node_config" "cgroup")
            size=$(kv::map::get_param_value "$node_config" "size")
            taints=$(kv::map::get_param_value "$node_config" "taints")
            if [[ $size == "std" || $size == "" ]]; then
                node_type="node"
            else
                if [[ $size == "small" ]]; then
                    node_type="sm-node"
                else
                    throw "node config size is illegal"
                fi
            fi
            if [[ $taints != "" ]]; then
                taints="[$taints]"
            fi
            if [[ $cgroup == "" ]]; then
                cgroup="v2"
            fi
            if [[ $taints == "" ]]; then
                taints=$SCHEDULABLE
            fi
            if [[ $node_type == "" ]]; then 
                node_type="node"
            fi
        fi
        if [[ $cgroup != "v2" && $cgroup != "" && $cgroup != "v1" ]]; then
            throw "node config cgroup is illegal"
        fi
        echo "192.168.122.${host_1} ${wkr}.kubernetes.local ${wkr} 10.200.${host_2}.0/24 ${node_type} ${taints} cgroup${cgroup}" >>$(machines_db)
        ((host_1 = host_1 + 1))
        ((host_2 = host_2 + 1))
    done
}
