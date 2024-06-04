readonly MACHINES_DB="${WORK_DIR}/cluster.txt"
readonly MACHINES_NEW_DB="${WORK_DIR}/cluster_patch.txt"
readonly MACHINES_DB_LOCK="${WORK_DIR}/cluster_lock.txt"
readonly JOBICO_CLUSTER_TBL=${MACHINES_DB}
readonly FROM_HOST=7
readonly SCHEDULABLE="schedulable"
readonly NO_SCHEDULABLE="no_schedulable"
readonly TAINTED="tainted"

kube::dao::gen_databases(){
    local number_of_nodes=$1
    local number_of_cpl_nodes=$2
    local number_of_lbs=$3
    local schedulable_server=$4
    kube::dao::gen_db $number_of_nodes $number_of_cpl_nodes $number_of_lbs
    kube::dao::gen_cluster_db $schedulable_server
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
            echo "$SERVER_NAME-$i control_plane gencert" >> ${WORK_DIR}/db.txt
        done
    else
        echo "server control_plane gencert" >> ${WORK_DIR}/db.txt
    fi
    for ((i=0;i<total_workers;i++)); do
        echo "$WORKER_NAME-$i worker gencert" >> ${WORK_DIR}/db.txt
    done
}
kube::dao::gen_add_db(){
    local total_nodes=$(grep -c 'node-*' ${WORK_DIR}/db.txt || true)
    local total_workers=$1
    ((total_workers=total_workers + total_nodes))
    for ((i=total_nodes;i<total_workers;i++)); do
        echo "$WORKER_NAME-$i worker gencert" >> ${WORK_DIR}/db_patch.txt
    done
}
kube::dao::gen_add_cluster_db(){
    local total_nodes=$(grep -c 'node-*' ${WORK_DIR}/db.txt || true) 
    local workers=($(kube::dao::cpl::get worker))
    local total=$(wc -l < $MACHINES_DB)
    ((host_1=total + FROM_HOST))
    ((host_2=total_nodes + 1))
    for wkr in "${workers[@]}"; do
        echo "192.168.122.${host_1} ${wkr}.kubernetes.local ${wkr} 10.200.${host_2}.0/24 node $SCHEDULABLE" >> ${MACHINES_NEW_DB}
        ((host_1=host_1+1))
        ((host_2=host_2+1))
    done
}
kube::dao::merge_dbs(){
    cat ${MACHINES_NEW_DB} >> ${MACHINES_DB} 
    cat ${WORK_DIR}/db_patch.txt >> ${WORK_DIR}/db.txt
    rm ${MACHINES_NEW_DB} ${WORK_DIR}/db_patch.txt
}
kube::dao::gen_cluster_db(){
    rm -f ${MACHINES_DB}
    local workers=($(kube::dao::cpl::get worker))
    local servers=($(kube::dao::cpl::get control_plane))
    local lbs=($(kube::dao::cpl::get lb))
    local lbvip=$(kube::dao::cpl::get lbvip)
    local host_1=${FROM_HOST}
    local host_2=0
    local schedulable_server=$1
    local svr_type=$TAINTED
    if [ $schedulable_server == true ]; then
        svr_type=$SCHEDULABLE
    fi
    if [ "${#servers[@]}" -gt 1 ]; then
        if [ -n "$lbvip" ]; then 
            echo "192.168.122.${host_1} ${lbvip}.kubernetes.local ${lbvip} 0.0.0.0/24 lbvip $NO_SCHEDULABLE" >> ${MACHINES_DB}
            ((host_1=host_1+1))
        fi
        for lb in "${lbs[@]}"; do
            echo "192.168.122.${host_1} ${lb}.kubernetes.local ${lb} 0.0.0.0/24 lb $NO_SCHEDULABLE" >> ${MACHINES_DB}
            ((host_1=host_1+1))
        done
        for svr in "${servers[@]}"; do
            echo "192.168.122.${host_1} ${svr}.kubernetes.local ${svr} 10.200.${host_2}.0/24 server $svr_type" >> ${MACHINES_DB}
            ((host_1=host_1+1))
            ((host_2=host_2+1))
        done
    else
        svr=${servers[0]}
        echo "192.168.122.${host_1} ${svr}.kubernetes.local ${svr} 10.200.${host_2}.0/24 server $svr_type" >> ${MACHINES_DB}
        ((host_1=host_1+1))
        ((host_2=host_2+1))
    fi
    for wkr in "${workers[@]}"; do
        echo "192.168.122.${host_1} ${wkr}.kubernetes.local ${wkr} 10.200.${host_2}.0/24 node $SCHEDULABLE" >> ${MACHINES_DB}
        ((host_1=host_1+1))
        ((host_2=host_2+1))
    done
}
kue::dao::merge_dbs(){
    cat ${MACHINES_NEW_DB} >> ${MACHINES_DB}
    rm ${MACHINES_NEW_DB}
    cat ${WORK_DIR}/db_patch.txt >> ${WORK_DIR}/db.txt
    rm ${WORK_DIR}/db_patch.txt
}
kube::dao::cpl::control_plane(){
    local db=${WORK_DIR}/db.txt
    local values=($(awk '$2 == "control_plane" {print $1}' ${db}))
    for e in "${values[@]}"; do
        echo "$e"
    done
}
kube::dao::cpl::curr_workers(){
    local values=($(awk '$2 == "worker" {print $1}' ${WORK_DIR}/db.txt))
    for e in "${values[@]}"; do
        echo "$e"
    done
}
kube::dao::cpl::all_workers(){
    local values=($(awk '$2 == "worker" {print $1}' ${WORK_DIR}/db.txt))
    if [ -f ${WORK_DIR}/db_patch.txt ]; then
        values2=($(awk '$2 == "worker" {print $1}' ${WORK_DIR}/db_patch.txt))
        values=("${values[@]}" "${values2[@]}")
    fi
    for e in "${values[@]}"; do
        echo "$e"
    done
}
kube::dao::cluster::all_nodes(){
    echo "$(kube::dao::cluster::curr_nodes)"
    if [ -f "${MACHINES_NEW_DB}" ]; then
        echo "$(kube::dao::cluster::nodes)"
    fi
}
kube::dao::cpl::get(){
    local db=$(kube::dao::cpl::curr_db)
    local colf="${2:-2}"
    local values=($(awk -v value="$1" -v col="1" -v cole="$colf" '$cole == value {print $col}' ${db}))
    for e in "${values[@]}"; do
        echo "$e"
    done
}
kube::dao::cpl::getby(){
    local db=$(kube::dao::cpl::curr_db)
    local values=$(awk -v value="$1" '$2 == value {print $0}' ${db})
    echo "$values"
}

kube::dao::cluster::machines(){
    kube::dao::cluster::get_type_is_not "lbvip"
}
kube::dao::cluster::nodes(){
    kube::dao::cluster::get_type_is "node"
}
kube::dao::cluster::servers(){
    kube::dao::cluster::get_type_is "server"
}
kube::dao::cluster::members(){
    kube::dao::cluster::nodes
    kube::dao::cluster::servers
}
kube::dao::cluster::all(){
    local db=$(kube::dao::cluster::curr_db)
    cat ${db}
}
kube::dao::cluster::lb(){
    local lb=$(awk -v value="lbvip" -v col="$1"  '$5 == value {print $col}' ${MACHINES_DB})
    if [ -z ${lb} ]; then 
        lb=$(awk -v value="server" -v col="$1"  '$5 == value {print $col}' ${MACHINES_DB})
    fi
    echo "${lb}"
}
kube::dao::cluster::get_type_is_not(){ 
    local db=$(kube::dao::cluster::curr_db)
    local result=$(awk -v value="$1" '$5 != value {print $0}' ${db})
    if [[ ! -z "$result" ]]; then
        echo "$result"
    fi
}
kube::dao::cluster::get_type_is(){ 
    local db=$(kube::dao::cluster::curr_db)
    local result=$(awk -v value="$1" '$5 == value {print $0}' ${db})
    if [[ ! -z "$result" ]]; then
        echo "$result"
    fi
}
kube::dao::cluster::schedulables(){
    kube::dao::cluster::get_schedule_is "schedulable"
}
kube::dao::cluster::get_schedule_is(){ 
    local db=$(kube::dao::cluster::curr_db)
    local result=$(awk -v value="$1" '$6 == value {print $0}' ${db})
    echo "$result"
}
kube::dao::cluster::get(){
    local db=$(kube::dao::cluster::curr_db)
    local values=($(awk -v value="$1" -v col="$2"  '$5 == value {print $col}' ${db}))
    for e in "${values[@]}"; do
        echo "$e"
    done
}
kube::dao::cluster::curr_nodes(){
    local result=$(awk '$5 == "node" {print $0}' ${MACHINES_DB})
    if [[ ! -z "$result" ]]; then
        echo "$result"
    fi
    local result=$(awk '$5 == "server" {print $0}' ${MACHINES_DB})
    if [[ ! -z "$result" ]]; then
        echo "$result"
    fi
}
kube::dao::cluster::count(){
    local db=$(kube::dao::cluster::curr_db)
    local value=$(awk -v value="$1" '$5 == value {count++} END {print count}' ${db})
    if [ ! -z "$value" ]; then
        echo "$value"
    else
        echo "0"
    fi
}
kube::dao::cpl::curr_db(){
    if [ -f ${WORK_DIR}/db_patch.txt ]; then
        echo "${WORK_DIR}/db_patch.txt" 
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
kube::dao::cluster::lock(){
    mv ${MACHINES_DB} ${MACHINES_DB_LOCK}
}
kube::dao::cluster::unlock(){
    if [ -f "${MACHINES_DB_LOCK}" ]; then 
        mv ${MACHINES_DB_LOCK} ${MACHINES_DB} 
    fi
}
kube::dao::cluster::is_locked(){
    if [ -f ${MACHINES_DB_LOCK} ]; then
        echo true
    else
        echo false
    fi
}
