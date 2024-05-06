readonly MACHINES_DB="${WORK_DIR}/cluster.txt"
readonly MACHINES_NEW_DB="${WORK_DIR}/cluster_new.txt"
readonly JOBICO_CLUSTER_TBL=${MACHINES_DB}
readonly FROM_HOST=7

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
kube::dao::gen_add_db(){
    local total_nodes=$(grep -c 'node-*' ${WORK_DIR}/db.txt)
    local total_workers=$1
    ((total_workers=total_workers + total_nodes))
    for ((i=total_nodes;i<total_workers;i++)); do
        echo "$WORKER_NAME-$i worker gencert" >> ${WORK_DIR}/db_new.txt
    done
}
kube::dao::gen_add_cluster_db(){
    local total_nodes=$(grep -c 'node-*' ${WORK_DIR}/db.txt)
    local workers=($(kube::dao::cpl::get worker))
    local total=$(wc -l < $MACHINES_DB)
    ((host_1=total + FROM_HOST))
    ((host_2=total_nodes))
    for wkr in "${workers[@]}"; do
        echo "192.168.122.${host_1} ${wkr}.kubernetes.local ${wkr} 10.200.${host_2}.0/24 node" >> ${MACHINES_NEW_DB}
        ((host_1++))
        ((host_2++))
    done
}
kube::dao::merge_dbs(){
    cat ${MACHINES_NEW_DB} >> ${MACHINES_DB} 
    cat ${WORK_DIR}/db_new.txt >> ${WORK_DIR}/db.txt
    rm ${MACHINES_NEW_DB} ${WORK_DIR}/db_new.txt
}
kube::dao::gen_cluster_db(){
    rm -f ${MACHINES_DB}
    local workers=($(kube::dao::cpl::get worker))
    local servers=($(kube::dao::cpl::get control_plane))
    local lbs=($(kube::dao::cpl::get lb))
    local lbvip=$(kube::dao::cpl::get lbvip)
    local host_1=${FROM_HOST}
    if [ "${#servers[@]}" -gt 1 ]; then
        if [ -n "$lbvip" ]; then 
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
kue::dao::merge_dbs(){
    cat ${MACHINES_NEW_DB} >> ${MACHINES_DB}
    rm ${MACHINES_NEW_DB}
    cat ${WORK_DIR}/db_new.txt >> ${WORK_DIR}/db.txt
    rm ${WORK_DIR}/db_new.txt
}
kube::dao::cpl::get(){
    db=$(kube::dao::cpl::curr_db)
    colf="${2:-2}"
    local values=($(awk -v value="$1" -v col="1" -v cole="$colf" '$cole == value {print $col}' ${db}))
    for e in "${values[@]}"; do
        echo "$e"
    done
}
kube::dao::cpl::getby(){
    db=$(kube::dao::cpl::curr_db)
    local values=$(awk -v value="$1" '$2 == value {print $0}' ${db})
    echo "$values"
}

kube::dao::cluster::machines(){
    echo "$(kube::dao::cluster::get_type_is_not "lbvip")"
}
kube::dao::cluster::nodes(){
    echo "$(kube::dao::cluster::get_type_is "node")"
}
kube::dao::cluster::lb(){
    local lb=$(awk -v value="lbvip" -v col="$1"  '$5 == value {print $col}' ${MACHINES_DB})
    if [ -z ${lb} ]; then 
        lb=$(awk -v value="server" -v col="$1"  '$5 == value {print $col}' ${MACHINES_DB})
    fi
    echo "${lb}"
}
kube::dao::cluster::get_type_is_not(){ 
    db=$(kube::dao::cluster::curr_db $1)
    local result=$(awk -v value="$1" '$5 != value {print $0}' ${db})
    echo "$result"
}
kube::dao::cluster::get_type_is(){ 
    db=$(kube::dao::cluster::curr_db $1)
    local result=$(awk -v value="$1" '$5 == value {print $0}' ${db})
    echo "$result"
}
kube::dao::cluster::get(){
    db=$(kube::dao::cluster::curr_db $1)
    local values=($(awk -v value="$1" -v col="$2"  '$5 == value {print $col}' ${db}))
    for e in "${values[@]}"; do
        echo "$e"
    done
}
kube::dao::cluster::count(){
    db=$(kube::dao::cluster::curr_db $1)
    local value=$(awk -v value="$1" '$5 == value {count++} END {print count}' ${db})
    echo "$value"
}
kube::dao::cpl::curr_db(){
    if [ -f ${WORK_DIR}/db_new.txt ]; then
        echo "${WORK_DIR}/db_new.txt" 
        return
    fi
    echo "${WORK_DIR}/db.txt"
}
kube::dao::cluster::curr_db(){
    if [ -f "${MACHINES_NEW_DB}" ]; then
        echo "${MACHINES_NEW_DB}"
        return
    fi
    echo "${MACHINES_DB}"
}
