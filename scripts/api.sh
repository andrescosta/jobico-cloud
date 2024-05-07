readonly CURR_DIR=$(dirname "$0")
readonly SCRIPTS="${CURR_DIR}/scripts"
readonly WORK_DIR="${CURR_DIR}/work"
readonly DOWNLOADS_DIR="${WORK_DIR}/downloads"
readonly EXTRAS_DIR="${CURR_DIR}/extras"
readonly HOSTSFILE="${WORK_DIR}/hosts"
readonly CA_CONF="${WORK_DIR}/ca.conf"
readonly MAKE=make
readonly STATUS_FILE=${WORK_DIR}/jobico_status
readonly CLUSTER_NAME=jobico-cloud
readonly WORKER_NAME=node
readonly SERVER_NAME=server
readonly LB_NAME=lb
readonly ENCRYPTION_KEY=$(head -c 32 /dev/urandom | base64)
readonly BEGIN_HOSTS_FILE="#B> Kubernetes Cluster"
readonly END_HOSTS_FILE="#E> Kubernetes Cluster"
readonly PLUGINS_CONF_FILE=${CURR_DIR}/plugins.conf
_DEBUG="off"
_DRY_RUN=false

. ${SCRIPTS}/support/plugins.sh 
. ${SCRIPTS}/support/utils.sh 
. ${SCRIPTS}/support/debug.sh 
. ${SCRIPTS}/dao/dao.sh 
. ${SCRIPTS}/machine/host.sh 
. ${SCRIPTS}/machine/local.sh 
. ${SCRIPTS}/k8s/kubeconfig.sh 
. ${SCRIPTS}/k8s/encryption.sh 
. ${SCRIPTS}/k8s/etcd.sh 
. ${SCRIPTS}/k8s/cpl.sh 
. ${SCRIPTS}/k8s/cluster.sh 
. ${SCRIPTS}/controllers.sh 

# Public API

kube::cluster(){
    local number_of_nodes=$1
    local number_of_cpl_nodes=$2
    local number_of_lbs=$3
    clear_dhcp
    kube::init $number_of_nodes $number_of_cpl_nodes $number_of_lbs
    kube::plugins::load ${PLUGINS_CONF_FILE}
    DEBUG kube::debug::print
    kube::create_machines "machines"
    kube::create_cluster
}

kube::destroy_cluster(){
    if [ ! -e ${MACHINES_DB} ]; then
        echo "${MACHINES_DB} does not exist"
        exit 1
    fi
    if [ ! -e ${WORK_DIR}/db.txt ]; then
        echo "${WORK_DIR}/db.txt does not exist"
        exit 1
    fi
    kube::plugins::load ${PLUGINS_CONF_FILE}
    kube::destroy_machines
    kube::restore_local_env
}

kube::gen_local_env(){
    kube::local
}
kube::add(){
    if [ ! -e ${MACHINES_DB} ]; then
        echo "${MACHINES_DB} does not exist"
        exit 1
    fi
    if [ ! -e ${WORK_DIR}/db.txt ]; then
        echo "${WORK_DIR}/db.txt does not exist"
        exit 1
    fi
    local number_of_nodes=$1
    kube::plugins::load ${PLUGINS_CONF_FILE}
    kube::init_for_add $number_of_nodes
    DEBUG kube::debug::print
    kube::create_machines "add_machines"
    kube::add_nodes
}
