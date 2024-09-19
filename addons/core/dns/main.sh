readonly DIR=$2
. constants.sh
. ${SCRIPTS}/support/dirs.sh
load_dirs
. ${SCRIPTS}/support/utils.sh
. ${SCRIPTS}/dao/cpl.sh

install(){
    local domain=$(jobico::dao::cpl::get_domain)
    local coredns=$(prepare_file "$1/coredns.yaml.tmpl" "dns" "{DOMAIN}=$domain")
    local excoredns=$(prepare_file "$1/excoredns.yaml.tmpl" "dns" "{DOMAIN}=$domain")
    kubectl apply -f $coredns
    kubectl apply -f $excoredns
}

install "$@"