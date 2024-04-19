VM_NAME=$1
VM_IP=$2
curr_mac=$(virsh -q domifaddr $VM_NAME --source arp | awk '{print $2}')
virsh net-update default delete ip-dhcp-host \
  '<host ip="$VM_IP"/>' \
  --live --config

virsh destroy $VM_NAME 
virsh undefine $VM_NAME --remove-all-storage
dhcp_release virbr0 $VM_IP $curr_mac
ssh-keygen -f ~/.ssh/known_hosts -R $VM_IP
