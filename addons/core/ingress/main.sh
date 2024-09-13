readonly DIR=$2
. constants.sh
. ${SCRIPTS}/support/dirs.sh
load_dirs
. ${SCRIPTS}/support/utils.sh
. ${SCRIPTS}/dao/cpl.sh

install(){
    local domain=$(jobico::dao::cpl::get_domain)
    local ingress=$(prepare_file "$1/ingress.yaml.tmpl" "ingress" "{DOMAIN}=$domain")
    kubectl apply -f $ingress
}

install "$@"