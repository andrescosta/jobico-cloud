readonly WORK_DIR="./work"
. "scripts/dao/dao.sh"
. "scripts/dao/cluster.sh"
. "$1/lib.sh"
install(){
    security "$@"
    manifests "$@"
    deploy "$@"
}
install "$@"
