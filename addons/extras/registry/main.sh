readonly DIR=$2
. constants.sh
. ${SCRIPTS}/support/dirs.sh
load_dirs
. ${SCRIPTS}/dao/dao.sh
. ${SCRIPTS}/dao/cluster.sh
. ${SCRIPTS}/dao/cpl.sh
. ${SCRIPTS}/support/ssh.sh
. ${SCRIPTS}/support/utils.sh
. $1/lib.sh
install(){
    security "$@"
    manifests "$@"
    deploy "$@"
    deploy_docker "$@"
}
install "$@"
