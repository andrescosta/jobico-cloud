kube::machine::create(){
     kube::dao::cluster::machines | while read IP FQDN HOST SUBNET TYPE SCH; do
        make -f scripts/Makefile.vm new-vm-${TYPE} VM_IP=${IP} VM_NAME=${HOST}
    done 
}

kube::machine::destroy(){
    kube::dao::cluster::machines | while read IP FQDN HOST SUBNET TYPE SCH; do
        make -f scripts/Makefile.vm destroy-vm VM_IP=${IP} VM_NAME=${HOST}
    done 
}
kube::machine::cmd(){
    kube::dao::cluster::unlock
    kube::dao::cluster::machines | while read IP FQDN HOST SUBNET TYPE SCH; do
        make -f scripts/Makefile.vm cmd-vm CMD=$1 VM_NAME=${HOST}
    done 
    kube::dao::cluster::lock
}

kube::machine::list(){
    make -f scripts/Makefile.vm list 
}

