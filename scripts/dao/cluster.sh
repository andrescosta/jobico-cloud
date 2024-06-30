jobico::dao::cluster::machines() {
    jobico::dao::cluster::get_type_is_not "lbvip"
}
jobico::dao::cluster::nodes() {
    jobico::dao::cluster::get_type_is "node"
}
jobico::dao::cluster::servers() {
    jobico::dao::cluster::get_type_is "server"
}
jobico::dao::cluster::members() {
    jobico::dao::cluster::nodes
    jobico::dao::cluster::servers
}
jobico::dao::cluster::all() {
    local db=$(jobico::dao::cluster::curr_db)
    cat ${db}
}
jobico::dao::cluster::lb() {
    local lb=$(awk -v value="lbvip" -v col="$1" '$5 == value {print $col}' ${MACHINES_DB})
    if [ -z ${lb} ]; then
        lb=$(awk -v value="server" -v col="$1" '$5 == value {print $col}' ${MACHINES_DB})
    fi
    echo "${lb}"
}
jobico::dao::cluster::get_type_is_not() {
    local db=$(jobico::dao::cluster::curr_db)
    local result=$(awk -v value="$1" '$5 != value {print $0}' ${db})
    if [[ ! -z "$result" ]]; then
        echo "$result"
    fi
}
jobico::dao::cluster::get_type_is() {
    local db=$(jobico::dao::cluster::curr_db)
    local result=$(awk -v value="$1" '$5 == value {print $0}' ${db})
    if [[ ! -z "$result" ]]; then
        echo "$result"
    fi
}
jobico::dao::cluster::schedulables() {
    jobico::dao::cluster::get_schedule_is "schedulable"
}
jobico::dao::cluster::get_schedule_is() {
    local db=$(jobico::dao::cluster::curr_db)
    local result=$(awk -v value="$1" '$6 == value {print $0}' ${db})
    echo "$result"
}
jobico::dao::cluster::get() {
    local db=$(jobico::dao::cluster::curr_db)
    local values=($(awk -v value="$1" -v col="$2" '$5 == value {print $col}' ${db}))
    for e in "${values[@]}"; do
        echo "$e"
    done
}
jobico::dao::cluster::curr_nodes() {
    local result=$(awk '$5 == "node" {print $0}' ${MACHINES_DB})
    if [[ ! -z "$result" ]]; then
        echo "$result"
    fi
    local result=$(awk '$5 == "server" {print $0}' ${MACHINES_DB})
    if [[ ! -z "$result" ]]; then
        echo "$result"
    fi
}
jobico::dao::cluster::count() {
    local db=$(jobico::dao::cluster::curr_db)
    local value=$(awk -v value="$1" '$5 == value {count++} END {print count}' ${db})
    if [ ! -z "$value" ]; then
        echo "$value"
    else
        echo "0"
    fi
}

jobico::dao::cluster::curr_db() {
    if [ -f "${MACHINES_NEW_DB}" ]; then
        echo "${MACHINES_NEW_DB}"
        return
    fi
    echo "${MACHINES_DB}"
}
jobico::dao::cluster::lock() {
    mv ${MACHINES_DB} ${MACHINES_DB_LOCK}
}
jobico::dao::cluster::unlock() {
    if [ -f "${MACHINES_DB_LOCK}" ]; then
        mv ${MACHINES_DB_LOCK} ${MACHINES_DB}
    fi
}
jobico::dao::cluster::is_locked() {
    if [ -f "${MACHINES_DB_LOCK}" ]; then
        echo true
    else
        echo false
    fi
}
