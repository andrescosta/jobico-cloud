readonly DIR=$2
. constants.sh
. ${SCRIPTS}/support/dirs.sh
. ${SCRIPTS}/dao/dao.sh
. ${SCRIPTS}/dao/cluster.sh
. ${SCRIPTS}/support/ssh.sh
. $1/lib.sh
install(){
    deploy "$@"
}
install "$@"
