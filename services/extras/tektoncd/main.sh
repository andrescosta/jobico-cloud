readonly DIR=$2
. constants.sh
. ${SCRIPTS}/support/k8s.sh

kubectl apply -f https://storage.googleapis.com/tekton-releases/operator/latest/release.yaml
kubectl apply -f https://raw.githubusercontent.com/tektoncd/operator/main/config/crs/kubernetes/config/all/operator_v1alpha1_config_cr.yaml
wait_for_namespace "tekton-pipelines" 120 2
if [ $? -ne 0 ]; then
  exit 1
else
  copy_secret jobico.org-secret default tekton-pipelines
  kubectl apply -f $1/ingress.yaml -n tekton-pipelines
fi