execute(){
    local timeout=120
    local end_time=$((SECONDS + timeout))
    while true; do
        if kubectl get pods -l app=nginx -o jsonpath="{.items[*].status.phase}" | grep -q "Running"; then
            break
        fi
        if (( SECONDS >= $end_time )); then
            echo "Timeout waiting for a pod"
            exit -1
        fi
        sleep 2
    done
    local pod_name=$(kubectl get pods -l app=nginx -o jsonpath="{.items[0].metadata.name}")
    kubectl port-forward $pod_name 8080:80 >/dev/null 2>&1 &
    echo "Done with $pod_name"
}
execute
