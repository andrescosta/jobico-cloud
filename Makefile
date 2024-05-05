.PHONY: status dhcp list net cluster destroy help

new:
	./cluster.sh new

destroy:
	./cluster.sh destroy

help:
	./cluster.sh help

## Utils

status:
	cloud-init status

dhcp:
	@virsh -q net-dhcp-leases default

list: 
	virsh list --all

net:
	virsh net-dumpxml default

