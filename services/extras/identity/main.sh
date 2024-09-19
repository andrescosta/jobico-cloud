readonly DIR=$2
. constants.sh
. ${SCRIPTS}/support/dirs.sh
load_dirs
. ${SCRIPTS}/support/utils.sh
. ${SCRIPTS}/dao/cpl.sh

install(){
    local domain=$(jobico::dao::cpl::get_domain)
    local values=$(prepare_file "$1/values.yaml.tmpl" "identity" "{DOMAIN}=$domain")
    helm repo add zitadel https://charts.zitadel.com
    helm install my-zitadel zitadel/zitadel --values $values
}

install "$@"