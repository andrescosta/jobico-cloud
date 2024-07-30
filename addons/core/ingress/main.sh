security(){
    if [ ! -d $1/certs ]; then
        mkdir $1/certs
        openssl req -x509 -newkey rsa:4096 -sha256 -days 3650 -nodes -keyout tls.key -out tls.crt -subj "/C=CA/ST=QC/L=MTL/O=Jobico/OU=Jobico/CN=*.jobico.org"   -addext "subjectAltName=DNS:*.jobico.org"
    fi
    kubectl create secret tls i-certs-secret --cert=$1/certs/tls.crt --key=$1/certs/tls.key
}

kubectl apply -f $1/ingress.yaml
security "$@"
