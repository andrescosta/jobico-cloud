VM_NAME=ikjumpbox

DESIRED_SIZE=20G
mac_jumpbox:=$(shell bash -c 'printf "02:%02x:%02x:%02x:%02x:%02x" $$((RANDOM%256)) $$((RANDOM%256)) $$((RANDOM%256)) $$((RANDOM%256)) $$((RANDOM%256))')

mac:
	virsh net-update default add ip-dhcp-host \
	  --xml '<host mac="${mac_jumpbox}" name="${VM_NAME}" ip="192.168.122.6"/>' \
	  --live --config

delete-mac:
	-virsh net-update default delete ip-dhcp-host \
	  '<host ip="192.168.122.6"/>' \
	  --live --config


jumpbox: deploy mac virt 

deps: 
	sudo apt update && sudo apt install cloud-utils whois -y

deploy: debian-12.qcow2 resize cloud-init.cfg cloud-init.iso
	sudo cp debian-12.qcow2  /var/lib/libvirt/boot/debian-12-${VM_NAME}.qcow2 
	sudo cp cloud-init.iso  /var/lib/libvirt/boot/cloud-init-${VM_NAME}.iso 

debian-12.qcow2:
	wget https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-generic-amd64.qcow2
	mv -i debian-12-generic-amd64.qcow2 \
  		debian-12.qcow2

resize:
	qemu-img resize \
  		debian-12.qcow2 \
  		${DESIRED_SIZE} 

cloud-init.cfg cloud-init.iso: 
	sudo cloud-localds cloud-init.iso cloud-init.cfg

virt:
	./newvm.sh ${VM_NAME} ${mac_jumpbox}

status:
	cloud-init status

destroy: delete-mac
	-virsh destroy ${VM_NAME} 
	-virsh undefine ${VM_NAME} --remove-all-storage

dhcp:
	virsh -q net-dhcp-leases default

list: 
	virsh list --all

net:
	virsh net-dumpxml default
debug:
	@echo ${mac_jumpbox}
