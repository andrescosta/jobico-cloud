wait_for_pod(){
    local namespace="metallb-system"
    local label_selector="app=metallb,component=controller"
    local timeout=120
    local end_time=$((SECONDS + timeout))
    while true; do
        if kubectl get pods -n "$namespace" -l "$label_selector" -o jsonpath="{.items[*].status.phase}" | grep -q "Running"; then
            break
        fi
        if (( SECONDS >= $end_time )); then
            echo "Timeout waiting for a pod"
            exit -1
        fi
        sleep 2
    done
    echo=
    if ! kubectl wait --namespace "$namespace" --for=condition=ready pod -l "$label_selector" --timeout="${timeout}s" &> /dev/null; then
        echo "Error: Pod for label selector '$label_selector' in namespace '$namespace' did not become ready."
        exit 1
    fi
}
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.14.5/config/manifests/metallb-native.yaml
wait_for_pod
echo ">> All pods ready <<"
kubectl apply -f $1/manifest/metalb.yaml
