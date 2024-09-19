readonly DIR=$2
. constants.sh
. ${SCRIPTS}/support/dirs.sh
load_dirs
. ${SCRIPTS}/support/k8s.sh
. ${SCRIPTS}/support/utils.sh
. ${SCRIPTS}/dao/cpl.sh

install(){
    local domain=$(jobico::dao::cpl::get_domain)
    local ingress=$(prepare_file "$1/ingress.yaml.tmpl" "tektoncd" "{DOMAIN}=$domain")

    kubectl apply -f https://storage.googleapis.com/tekton-releases/operator/latest/release.yaml
    kubectl apply -f https://raw.githubusercontent.com/tektoncd/operator/main/config/crs/kubernetes/config/all/operator_v1alpha1_config_cr.yaml
    wait_for_namespace "tekton-pipelines" 120 2
    if [ $? -ne 0 ]; then
      exit 1
    else
      copy_secret "$domain-secret" default tekton-pipelines
      kubectl apply -f $ingress -n tekton-pipelines
    fi
}
install "$@"
