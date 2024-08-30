jobico::dao::cpl::control_plane() {
    local db=$(work_dir)/db.txt
    local values=($(awk '$2 == "control_plane" {print $1}' ${db}))
    for e in "${values[@]}"; do
        echo "$e"
    done
}
jobico::dao::cpl::curr_workers() {
    local values=($(awk '$2 == "worker" {print $1}' $(work_dir)/db.txt))
    for e in "${values[@]}"; do
        echo "$e"
    done
}
jobico::dao::cpl::all_workers() {
    local values=($(awk '$2 == "worker" {print $1}' $(work_dir)/db.txt))
    if [ -f $(work_dir)/db_patch.txt ]; then
        values2=($(awk '$2 == "worker" {print $1}' $(work_dir)/db_patch.txt))
        values=("${values[@]}" "${values2[@]}")
    fi
    for e in "${values[@]}"; do
        echo "$e"
    done
}
jobico::dao::cluster::all_nodes() {
    echo "$(jobico::dao::cluster::curr_nodes)"
    if [ -f "${MACHINES_NEW_DB}" ]; then
        echo "$(jobico::dao::cluster::nodes)"
    fi
}
jobico::dao::cpl::get() {
    local db=$(jobico::dao::cpl::curr_db)
    local colf="${2:-2}"
    local values=($(awk -v value="$1" -v col="1" -v cole="$colf" '$cole == value {print $col}' ${db}))
    for e in "${values[@]}"; do
        echo "$e"
    done
}
jobico::dao::cpl::getby() {
    local db=$(jobico::dao::cpl::curr_db)
    local values=$(awk -v value="$1" '$2 == value {print $0}' ${db})
    echo "$values"
}
jobico::dao::cpl::curr_db() {
    if [ -f $(work_dir)/db_patch.txt ]; then
        echo "$(work_dir)/db_patch.txt"
        return
    fi
    echo "$(work_dir)/db.txt"
}

