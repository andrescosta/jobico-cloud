. constants.sh
. ${SCRIPTS}/plugins/tls.sh
echo $WORK_DIR
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl patch configmap argocd-cmd-params-cm  --patch-file $1/cm.yaml -nargocd
jobico::tls::create_tls_secret argocd
kubectl apply -f $1/ingress.yaml
if [ ! -e /usr/local/bin/argocd ]; then
    curl -sSL -o $1/argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
    sudo install -m 555 $1/argocd-linux-amd64 /usr/local/bin/argocd
    rm argocd-linux-amd64
fi