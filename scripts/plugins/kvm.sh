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
if [ $(kube::dao::cluster::is_locked) == true ]; then
        kube::dao::cluster::unlock
        kube::dao::cluster::machines | while read IP FQDN HOST SUBNET TYPE SCH; do
            make -f scripts/Makefile.vm cmd-vm CMD=$1 VM_NAME=${HOST}
        done 
        kube::dao::cluster::lock
        echo true
    else
        echo false
    fi
}

kube::machine::list(){
    make -f scripts/Makefile.vm list 
}

kube::kvm::install_kvm(){
  sudo apt update
  sudo apt install -y qemu-kvm virt-manager libvirt-daemon-system virtinst libvirt-clients bridge-utils
  sudo apt install cloud-utils whois -y
  sudo systemctl enable --now libvirtd
  sudo systemctl start libvirtd
  sudo usermod -aG kvm $USER
  sudo usermod -aG libvirt $USER
}
