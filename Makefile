.PHONY: status dhcp list net cluster destroy help

new:
	./cluster.sh new --nodes 1 --schedulable-server
destroy:
	./cluster.sh destroy
help:
	./cluster.sh help
## Utils

dhcp:
	@virsh -q net-dhcp-leases default

list: 
	./cluster.sh list

net:
	virsh net-dumpxml default

