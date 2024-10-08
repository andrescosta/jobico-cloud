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
    if [ -f "$(machines_new_db)" ]; then
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
jobico::dao::cpl::curr_db() {
    if [ -f $(work_dir)/db_patch.txt ]; then
        echo "$(work_dir)/db_patch.txt"
        return
    fi
    echo "$(work_dir)/db.txt"
}

jobico::dao::cpl::get_domain() {
    local ingress=$(jobico::dao::cpl::get "ingress")
    local domain=$(awk -v str="$ingress" -v col="1" 'BEGIN { split(str, arr, " "); print arr[col] }')
    echo $(echo "$ingress" | awk '{print $1}')
}