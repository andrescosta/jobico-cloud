install(){
    kubectl apply -f $1/redis.yaml
}

install "$@"
