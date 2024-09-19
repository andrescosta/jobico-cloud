readonly DIR=$2
. constants.sh
. ${SCRIPTS}/support/dirs.sh
load_dirs
. ${SCRIPTS}/support/utils.sh
. ${SCRIPTS}/dao/cpl.sh

install(){
    local domain=$(jobico::dao::cpl::get_domain)
    local values=$(prepare_file "$1/values.yaml.tmpl" "dashboard" "{DOMAIN}=$domain")
    helm repo add kubernetes-dashboard https://kubernetes.github.io/dashboard/
    helm upgrade --install kubernetes-dashboard kubernetes-dashboard/kubernetes-dashboard --create-namespace --namespace kubernetes-dashboard -f $values
    kubectl apply -f $1/user.yaml
}

install "$@"