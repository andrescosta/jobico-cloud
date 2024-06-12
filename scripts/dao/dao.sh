readonly MACHINES_DB="${WORK_DIR}/cluster.txt"
readonly MACHINES_NEW_DB="${WORK_DIR}/cluster_patch.txt"
readonly MACHINES_DB_LOCK="${WORK_DIR}/cluster_lock.txt"
readonly JOBICO_CLUSTER_TBL=${MACHINES_DB}
readonly FROM_HOST=7
readonly SCHEDULABLE="schedulable"
readonly NO_SCHEDULABLE="no_schedulable"
readonly TAINTED="tainted"

jobico::dao::gen_databases() {
    local number_of_nodes=$1
    local number_of_cpl_nodes=$2
    local number_of_lbs=$3
    local schedulable_server=$4
    jobico::dao::gen_db $number_of_nodes $number_of_cpl_nodes $number_of_lbs
    jobico::dao::gen_cluster_db $schedulable_server
}

jobico::dao::gen_db() {
    local total_workers=$1
    local total_cpl_nodes=$2
    local total_of_lbs=$3
    cp ${EXTRAS_DIR}/db/db.txt.tmpl ${WORK_DIR}/db.txt
    if [ $total_cpl_nodes -gt 1 ]; then
        echo "server lbvip" >>${WORK_DIR}/db.txt
        for ((i = 0; i < total_of_lbs; i++)); do
            echo "$LB_NAME-$i lb" >>${WORK_DIR}/db.txt
        done
        for ((i = 0; i < total_cpl_nodes; i++)); do
            echo "$SERVER_NAME-$i control_plane gencert" >>${WORK_DIR}/db.txt
        done
    else
        echo "server control_plane gencert" >>${WORK_DIR}/db.txt
    fi
    for ((i = 0; i < total_workers; i++)); do
        echo "$WORKER_NAME-$i worker gencert" >>${WORK_DIR}/db.txt
    done
}
jobico::dao::gen_add_db() {
    local total_nodes=$(grep -c 'node-*' ${WORK_DIR}/db.txt || true)
    local total_workers=$1
    ((total_workers = total_workers + total_nodes))
    for ((i = total_nodes; i < total_workers; i++)); do
        echo "$WORKER_NAME-$i worker gencert" >>${WORK_DIR}/db_patch.txt
    done
}
jobico::dao::gen_add_cluster_db() {
    local total_nodes=$(grep -c 'node-*' ${WORK_DIR}/db.txt || true)
    local workers=($(jobico::dao::cpl::get worker))
    local total=$(wc -l <$MACHINES_DB)
    ((host_1 = total + FROM_HOST))
    ((host_2 = total_nodes + 1))
    for wkr in "${workers[@]}"; do
        echo "192.168.122.${host_1} ${wkr}.kubernetes.local ${wkr} 10.200.${host_2}.0/24 node $SCHEDULABLE" >>${MACHINES_NEW_DB}
        ((host_1 = host_1 + 1))
        ((host_2 = host_2 + 1))
    done
}
jobico::dao::merge_dbs() {
    cat ${MACHINES_NEW_DB} >>${MACHINES_DB}
    rm ${MACHINES_NEW_DB}
    cat ${WORK_DIR}/db_patch.txt >>${WORK_DIR}/db.txt
    rm ${MACHINES_NEW_DB} ${WORK_DIR}/db_patch.txt
}
jobico::dao::gen_cluster_db() {
    rm -f ${MACHINES_DB}
    local workers=($(jobico::dao::cpl::get worker))
    local servers=($(jobico::dao::cpl::get control_plane))
    local lbs=($(jobico::dao::cpl::get lb))
    local lbvip=$(jobico::dao::cpl::get lbvip)
    local host_1=${FROM_HOST}
    local host_2=0
    local schedulable_server=$1
    local svr_type=$TAINTED
    if [ $schedulable_server == true ]; then
        svr_type=$SCHEDULABLE
    fi
    if [ "${#servers[@]}" -gt 1 ]; then
        if [ -n "$lbvip" ]; then
            echo "192.168.122.${host_1} ${lbvip}.kubernetes.local ${lbvip} 0.0.0.0/24 lbvip $NO_SCHEDULABLE" >>${MACHINES_DB}
            ((host_1 = host_1 + 1))
        fi
        for lb in "${lbs[@]}"; do
            echo "192.168.122.${host_1} ${lb}.kubernetes.local ${lb} 0.0.0.0/24 lb $NO_SCHEDULABLE" >>${MACHINES_DB}
            ((host_1 = host_1 + 1))
        done
        for svr in "${servers[@]}"; do
            echo "192.168.122.${host_1} ${svr}.kubernetes.local ${svr} 10.200.${host_2}.0/24 server $svr_type" >>${MACHINES_DB}
            ((host_1 = host_1 + 1))
            ((host_2 = host_2 + 1))
        done
    else
        svr=${servers[0]}
        echo "192.168.122.${host_1} ${svr}.kubernetes.local ${svr} 10.200.${host_2}.0/24 server $svr_type" >>${MACHINES_DB}
        ((host_1 = host_1 + 1))
        ((host_2 = host_2 + 1))
    fi
    for wkr in "${workers[@]}"; do
        echo "192.168.122.${host_1} ${wkr}.kubernetes.local ${wkr} 10.200.${host_2}.0/24 node $SCHEDULABLE" >>${MACHINES_DB}
        ((host_1 = host_1 + 1))
        ((host_2 = host_2 + 1))
    done
}