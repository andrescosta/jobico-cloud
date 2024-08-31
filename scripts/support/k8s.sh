copy_secret(){
    local name=$1
    local from_ns=$2
    local to_ns=$3
    kubectl get secret $name --namespace=$from_ns -o yaml | sed "s/namespace: .*/namespace: $to_ns/" | kubectl apply -f -
}

wait_for_namespace() {
  local namespace="$1"
  local timeout="$2"
  local interval="$3"
  local elapsed=0
  until kubectl get namespace "$namespace" >/dev/null 2>&1; do
    if (( elapsed > timeout )); then
      return 1 
    fi
    
    sleep "$interval"
    elapsed=$((elapsed + interval))
  done
  return 0 
}