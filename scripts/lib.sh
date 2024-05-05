
readonly WORK_DIR="work"
readonly DOWNLOADS_DIR="${WORK_DIR}/downloads"
readonly EXTRAS_DIR="extras"
readonly HOSTSFILE="${WORK_DIR}/hosts"
readonly CA_CONF="${WORK_DIR}/ca.conf"
readonly MAKE=make
readonly STATUS_FILE=${WORK_DIR}/jobico_status
readonly CLUSTER_NAME=jobico-cloud
readonly WORKER_NAME=node
readonly SERVER_NAME=server
readonly LB_NAME=lb
readonly MACHINES_DB="${WORK_DIR}/cluster.txt"
readonly DOWNLOADS_TBL=${EXTRAS_DIR}/downloads/downloads_amd64.txt
readonly JOBICO_CLUSTER_TBL=${MACHINES_DB}
readonly ENCRYPTION_KEY=$(head -c 32 /dev/urandom | base64)
readonly BEGIN_HOSTS_FILE="#B> Kubernetes Cluster"
readonly END_HOSTS_FILE="#E> Kubernetes Cluster"
_DEBUG="off"
_DRY_RUN=false

. $(dirname "$0")/utils.sh 
. $(dirname "$0")/controllers.sh 
. $(dirname "$0")/local.sh 
. $(dirname "$0")/kvmm.sh 
. $(dirname "$0")/dao.sh 
. $(dirname "$0")/host.sh 
. $(dirname "$0")/tls.sh 
. $(dirname "$0")/kubeconfig.sh 
. $(dirname "$0")/haproxy.sh 
. $(dirname "$0")/encryption.sh 
. $(dirname "$0")/etcd.sh 
. $(dirname "$0")/cpl.sh 
. $(dirname "$0")/clusterdep.sh 
. $(dirname "$0")/debug.sh 

# Public API

kube::cluster(){
    local number_of_nodes=$1
    local number_of_cpl_nodes=$2
    local number_of_lbs=$3
    kube::init
    DEBUG kube::debug::print
    kube::create_machines
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
    kube::destroy_machines
    kube::restore_local_env
}

kube::gen_local_env(){
    kube::local
}
