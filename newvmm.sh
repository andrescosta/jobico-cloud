VM_NAME=$1
VM_IP=$2
mac=$(printf '02:%02x:%02x:%02x:%02x:%02x' $((RANDOM%256)) $((RANDOM%256)) $((RANDOM%256)) $((RANDOM%256)) $((RANDOM%256)))
virsh net-update default add ip-dhcp-host \
  --xml "<host mac='$mac' name='$VM_NAME' ip='$VM_IP'/>" \
  --live --config

sudo cp debian-12.qcow2  /var/lib/libvirt/boot/debian-12-$VM_NAME.qcow2 
sudo cp cloud-init.iso  /var/lib/libvirt/boot/cloud-init-$VM_NAME.iso 

sudo virt-install \
 --name $VM_NAME \
 --ram 2048 \
 --vcpus=1 \
 --cpu host \
 --disk /var/lib/libvirt/boot/debian-12-$VM_NAME.qcow2,device=disk,bus=virtio \
 --hvm \
 --disk /var/lib/libvirt/boot/cloud-init-$VM_NAME.iso,device=cdrom \
 --os-variant debian10 \
 --virt-type kvm \
 --graphics none \
 --network network=default,model=virtio,mac=$mac\
 --import \
