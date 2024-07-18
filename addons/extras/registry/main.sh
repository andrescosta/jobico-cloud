readonly WORK_DIR="./work"
. "scripts/dao/dao.sh"
. "scripts/dao/cluster.sh"
. "scripts/support/ssh.sh"
. "$1/lib.sh"
install(){
    security "$@"
    manifests "$@"
    deploy "$@"
    deploy_docker "$@"
}
install "$@"
