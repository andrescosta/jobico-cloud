VM_NAME=$1
VM_IP=$2
curr_mac=$(virsh -q domifaddr $VM_NAME --source arp | awk '{print $2}')

echo "$curr_mac"

