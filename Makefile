.PHONY: status dhcp list net cluster destroy help

new:
	./scripts/cluster.sh new

destroy:
	./scripts/cluster.sh destroy

help:
	./scripts/cluster.sh help

## Utils

status:
	cloud-init status

dhcp:
	@virsh -q net-dhcp-leases default

list: 
	virsh list --all

net:
	virsh net-dumpxml default

