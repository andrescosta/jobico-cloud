readonly DIR=$2
. constants.sh
. ${SCRIPTS}/support/dirs.sh
load_dirs
. ${SCRIPTS}/plugins/tls.sh
. ${SCRIPTS}/support/utils.sh
. ${SCRIPTS}/dao/cpl.sh

install(){
    local domain=$(jobico::dao::cpl::get_domain)
    local ingress=$(prepare_file "$1/ingress.yaml.tmpl" "argocd" "{DOMAIN}=$domain")

    kubectl create namespace argocd
    kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
    kubectl patch configmap argocd-cmd-params-cm  --patch-file $1/argocd-cmd-params-cm-patch.yaml -nargocd
    kubectl patch configmap argocd-cm --patch-file $1/argocd-cm-patch.yaml -nargocd
    kubectl patch configmap argocd-rbac-cm --patch-file $1/rbac-patch.yaml -nargocd
    kubectl patch role argocd-server --type=json --patch-file $1/role-patch.yaml -nargocd
    kubectl patch ClusterRole argocd-server --type=json --patch-file $1/role-patch.yaml
    jobico::tls::create_tls_secret argocd
    kubectl apply -f $ingress
    if [ ! -e /usr/local/bin/argocd ]; then
        curl -sSL -o $1/argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
        sudo install -m 555 $1/argocd-linux-amd64 /usr/local/bin/argocd
        rm argocd-linux-amd64
    fi
}
install "$@"
