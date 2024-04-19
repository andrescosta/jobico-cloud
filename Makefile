USER:=root
DIR:=k8s

.PHONY: vms-install vms-destroy vms-start dhcp

#@ Cloud

new: jumpbox-new server-new node-0-new node-1-new

server-new:  
	$(MAKE) -f Makefile.vm new-vm VM_IP=192.168.122.7 VM_NAME=server
	echo "192.168.122.7 server.kubernetes.local server" > machines.txt
node-0-new:
	$(MAKE) -f Makefile.vm new-vm VM_IP=192.168.122.8 VM_NAME=node-0
	echo "192.168.122.8 node-0.kubernetes.local node-0 10.200.0.0/24" >> machines.txt
node-1-new:
	$(MAKE) -f Makefile.vm new-vm VM_IP=192.168.122.9 VM_NAME=node-1
	echo "192.168.122.9 node-1.kubernetes.local node-1 10.200.1.0/24" >> machines.txt

destroy: jumpbox-del server-del node-0-del node-1-del

server-del:  
	$(MAKE) -f Makefile.vm destroy-vm VM_IP=192.168.122.7 VM_NAME=server
node-0-del:
	$(MAKE) -f Makefile.vm destroy-vm VM_IP=192.168.122.8 VM_NAME=node-0
node-1-del:
	$(MAKE) -f Makefile.vm destroy-vm VM_IP=192.168.122.9 VM_NAME=node-1


## Set jumpbox

jumpbox: jumpbox-vm jb-wait-ready jb-git jb-download jb-machines jb-kubectl

jumpbox-new:  
	$(MAKE) -f Makefile.vm new-vm VM_IP=192.168.122.6 VM_NAME=jumpbox

jumpbox-del:  
	$(MAKE) -f Makefile.vm destroy-vm VM_IP=192.168.122.6 VM_NAME=jumpbox


jp-git:
	ssh ${USER}@${VM_IP} "git clone --depth 1 https://github.com/kelseyhightower/kubernetes-the-hard-way.git ; mv kubernetes-the-hard-way ${DIR}"

jp-download:
	ssh ${USER}@${VM_IP} "sed 's/arm64/amd64/' ~/k8s/downloads.txt > ~/k8s/downloads_amd64_1.txt"
	ssh ${USER}@${VM_IP} "sed 's/arm/amd64/' ~/k8s/downloads_amd64_1.txt > ~/k8s/downloads_amd64.txt"
	ssh ${USER}@${VM_IP} "mkdir -p downloads; wget -q --https-only -P downloads -i ${DIR}/downloads_amd64.txt"

jp-machines:
	scp machines.txt ${USER}@${VM_IP}:~/  

jp-kubectl: 
	 ssh ${USER}@${VM_IP} "chmod +x downloads/kubectl; cp downloads/kubectl /usr/local/bin/"

init:
	mkdir -p ${TMP}

## Deps

deps: 
	sudo apt update && sudo apt install cloud-utils whois -y


## Utils

status:
	cloud-init status

dhcp:
	virsh -q net-dhcp-leases default

list: 
	virsh list --all

net:
	virsh net-dumpxml default
ssh:
	ssh root@${VM_IP}


