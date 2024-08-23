. constants.sh
. ${SCRIPTS}/dao/dao.sh
. ${SCRIPTS}/dao/cluster.sh
. ${SCRIPTS}/support/ssh.sh
. $1/lib.sh
install(){
    security "$@"
    manifests "$@"
    deploy "$@"
    deploy_docker "$@"
}
install "$@"
