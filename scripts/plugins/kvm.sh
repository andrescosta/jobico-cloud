kube::machine::create(){
     kube::dao::cluster::machines | while read IP FQDN HOST SUBNET TYPE; do
        make -f scripts/Makefile.vm new-vm-${TYPE} VM_IP=${IP} VM_NAME=${HOST}
    done 
}

kube::machine::destroy(){
    kube::dao::cluster::machines | while read IP FQDN HOST SUBNET TYPE; do
        make -f scripts/Makefile.vm destroy-vm VM_IP=${IP} VM_NAME=${HOST}
    done 
}
