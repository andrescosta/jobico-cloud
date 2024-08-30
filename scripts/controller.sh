
readonly HOSTSFILE="$(work_dir)/hosts"
readonly CA_CONF="$(work_dir)/ca.conf"
readonly STATUS_FILE=$(work_dir)/jobico_status

. ${SCRIPTS}/support/plugin.sh
. ${SCRIPTS}/support/utils.sh
. ${SCRIPTS}/support/debug.sh
. ${SCRIPTS}/dao/dao.sh
. ${SCRIPTS}/dao/cpl.sh
. ${SCRIPTS}/dao/cluster.sh
. ${SCRIPTS}/vm/host.sh
. ${SCRIPTS}/vm/local.sh
. ${SCRIPTS}/k8s/kubeconfig.sh
. ${SCRIPTS}/k8s/encryption.sh
. ${SCRIPTS}/k8s/etcd.sh
. ${SCRIPTS}/k8s/cpl.sh
. ${SCRIPTS}/k8s/cluster.sh
. ${SCRIPTS}/api.sh

# Public API
jobico::new_cluster() {
    local number_of_nodes=$1
    local number_of_cpl_nodes=$2
    local number_of_lbs=$3
    local schedulable_server=$4
    local skip_addons=$5
    local addons_list=$6
    local vers=$7
    if [[ $(jobico::dao::cluster::is_locked) == true ]]; then
        echo "A cluster already exists."
        exit 1
    fi
    if [[ ! -f $EXTRAS_DIR/cfg/cloud-init-node.cfg || ! -f  $EXTRAS_DIR/cfg/cloud-init-lb.cfg ]]; then
       echo "The cloud init config files were not generated."
       echo "Run $0 cfg to generate them"
       exit 1
    fi
    if [[ ! -f "$vers" ]]; then
        echo "The file $vers does not exit."
        exit 1
    fi
    jobico::plugin::load ${PLUGINS_CONF_FILE}
    jobico::init $number_of_nodes $number_of_cpl_nodes $number_of_lbs $schedulable_server $vers
    DEBUG jobico::debug::print
    jobico::create_cluster
    if [ $skip_addons == false ]; then
        NOT_DRY_RUN jobico::install_all_addons "new" ${addons_list}
    else
        echo "Skipping adddons installation"
    fi
    NOT_DRY_RUN jobico::dao::cluster::lock
}
jobico::start_cluster() {
    jobico::exec_cmd start
}
jobico::shutdown_cluster() {
    jobico::exec_cmd shutdown
}
jobico::resume_cluster() {
    jobico::exec_cmd resume
}
jobico::suspend_cluster() {
    jobico::exec_cmd suspend
}
jobico::state_cluster() {
    jobico::exec_cmd domstate
}
jobico::list_vms() {
    jobico::plugin::load ${PLUGINS_CONF_FILE}
    jobico::vm::list
}
jobico::info_cluster() {
    jobico::exec_cmd dominfo
}
jobico::exec_cmd() {
    jobico::plugin::load ${PLUGINS_CONF_FILE}
    ret=$(jobico::vm::cmd $1)
    if [[ $ret == false ]]; then
        echo "Error: The cluster was not created."
        exit 1
    fi
}
jobico::destroy_cluster() {
    if [[ $(jobico::dao::cluster::is_locked) == false ]]; then
        if [ ! -e ${MACHINES_DB} ]; then
            echo "Error: The cluster was not created."
            exit 1
        fi
    fi
    if [ ! -e $(work_dir)/db.txt ]; then
        echo "Error: The cluster was not created."
        exit 1
    fi
    jobico::plugin::load ${PLUGINS_CONF_FILE}
    jobico::dao::cluster::unlock
    jobico::destroy_vms
    jobico::restore_local_env
}

jobico::gen_local_env() {
    local vers=$1
     if [[ ! -f "$vers" ]]; then
        echo "The file $vers does not exit."
        exit 1
    fi
    jobico::local $vers
}

jobico::add_nodes() {
    if [[ $(jobico::dao::cluster::is_locked) == true ]]; then
        echo "Error: The cluster is locked. Use --force to add nodes"
        exit 1
    fi
    if [ ! -e ${MACHINES_DB} ]; then
        echo "Error: The cluster was not created."
        exit 1
    fi
    if [ ! -e $(work_dir)/db.txt ]; then
        echo "Error: The cluster was not created."
        exit 1
    fi
    local number_of_nodes=$1
    local skip_addons=$2
    local addons_list=$3
    jobico::plugin::load ${PLUGINS_CONF_FILE}
    jobico::prepare_db $number_of_nodes
    DEBUG jobico::debug::print
    jobico::create_nodes
    if [ $skip_addons == false ]; then
        NOT_DRY_RUN jobico::install_all_addons "add" ${addons_list}
    else
        echo "Skipping adddons installation"
    fi
    NOT_DRY_RUN jobico::dao::merge_dbs
    NOT_DRY_RUN jobico::dao::cluster::lock
}
jobico::prepare_db() {
    local number_of_nodes=$1
    jobico::dao::gen_add_db ${number_of_nodes}
    jobico::dao::gen_add_cluster_db
}
jobico::addons_post(){
    local addons_list=$1
    jobico::dao::cluster::unlock
    NOT_DRY_RUN jobico::install_all_addons "new" ${addons_list}
    jobico::dao::cluster::lock
}
