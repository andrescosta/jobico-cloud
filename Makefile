USER:=root
DIR:=k8s
WORK_DIR:=work

.PHONY: vms-install vms-destroy vms-start dhcp

#@ Cloud

new: jumpbox-new server-new node-0-new node-1-new

jumpbox-new:  
	$(MAKE) -f Makefile.vm new-vm VM_IP=192.168.122.6 VM_NAME=jumpbox


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

jumpbox-del:  
	$(MAKE) -f Makefile.vm destroy-vm VM_IP=192.168.122.6 VM_NAME=jumpbox
server-del:  
	$(MAKE) -f Makefile.vm destroy-vm VM_IP=192.168.122.7 VM_NAME=server
node-0-del:
	$(MAKE) -f Makefile.vm destroy-vm VM_IP=192.168.122.8 VM_NAME=node-0
node-1-del:
	$(MAKE) -f Makefile.vm destroy-vm VM_IP=192.168.122.9 VM_NAME=node-1


## Get deps 

k8s-deps: k8s-init k8s-git k8s-download 

k8s-init:
	mkdir -p ${WORK_DIR}

k8s-git:
	cd ${WORK_DIR} && git clone --depth 1 https://github.com/kelseyhightower/kubernetes-the-hard-way.git \
		       && mv kubernetes-the-hard-way ${DIR}

k8s-download:
	cd ${WORK_DIR} && sed 's/arm64/amd64/' k8s/downloads.txt > downloads_amd64_1.txt \
		       && sed 's/arm/amd64/' downloads_amd64_1.txt > downloads_amd64.txt \
		       && mkdir -p downloads \
                       && wget -q --https-only -P downloads -i downloads_amd64.txt
## Cluster

k8s-kubectl:
	 cp ${WORK_DIR}/downloads/kubectl /usr/local/bin
	 chmod +x /usr/local/bin/kubectl

k8s-set-host-names: 
	scripts/sethostnames.sh

k8s-hosts-name-gen: 
	scripts/genhostsfile.sh

k8s-hosts-name-local: k8s-hosts-name-gen
	scripts/genandupdhostsfile.sh

k8s-hosts-name-remote: k8s-hosts-name-gen
	scripts/scphostsfile.sh

k8s-gen-ca:
	cd ${WORK_DIR} && ../scripts/genca.sh

k8s-gen-certs:
	cd ${WORK_DIR} && ../scripts/gencerts.sh

k8s-copy-certs:
	cd ${WORK_DIR} && ../scripts/copycerts.sh
k8s-copy-certs-server:
	cd ${WORK_DIR} && ../scripts/copycertsserver.sh
k8s-kubeconfigs:
	cd ${WORK_DIR} && ../scripts/kubeconfigs.sh

k8s-encryption-key:
	cd ${WORK_DIR} && ../scripts/encryption-config.sh
k8s-etcd:
	cd ${WORK_DIR} && ../scripts/etcd.sh
k8s-control-plane:
	cd ${WORK_DIR} && ../scripts/controlplane.sh
## Jumpbox Setup

jumpbox-kubectl: 
	 scp ${WORK_DIR}/usr/local/bin/kubectl ${USER}@192.168.122.6:/usr/local/bin

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
debug:
	scripts/debug.sh

