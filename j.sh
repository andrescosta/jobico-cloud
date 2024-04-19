VM_NAME=ikjumpbox
VM_IP:=192.168.122.6
USER:=root
DESIRED_SIZE=20G
DIR:=k8s
mac_jumpbox:=$(shell bash -c 'printf "02:%02x:%02x:%02x:%02x:%02x" $$((RANDOM%256)) $$((RANDOM%256)) $$((RANDOM%256)) $$((RANDOM%256)) $$((RANDOM%256))')
curr_mac=$(shell virsh -q domifaddr ${VM_NAME} --source arp | awk '{print $$2}')

mac:
	virsh net-update default add ip-dhcp-host \
	  --xml '<host mac="${mac_jumpbox}" name="${VM_NAME}" ip="${VM_IP}"/>' \
	  --live --config

delete-mac:
	-virsh net-update default delete ip-dhcp-host \
	  '<host ip="${VM_IP}"/>' \
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

destroy: dhcp-release delete-mac delete-key
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
	echo ${curr_mac}
dhcp-release:
	-dhcp_release virbr0 ${VM_IP} ${curr_mac}
delete-key:
	-ssh-keygen -f ~/.ssh/known_hosts -R ${VM_IP}
ssh:
	ssh root@${VM_IP}
.PHONY: vms-install vms-destroy vms-start dhcp

jb-git:
	ssh ${USER}@${VM_IP} "git clone --depth 1 https://github.com/kelseyhightower/kubernetes-the-hard-way.git ; mv kubernetes-the-hard-way ${DIR}"

jb-download:
	ssh ${USER}@${VM_IP} "mkdir -p downloads; wget -q --https-only -P downloads -i ${DIR}/downloads.txt"

machine-cp: init
	scp ${TMP}/machines.txt ${USER}@ikjumpbox:~/

init:
	mkdir -p ${TMP}
