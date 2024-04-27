.PHONY: status dhcp list net 

## Utils

status:
	cloud-init status

dhcp:
	@virsh -q net-dhcp-leases default

list: 
	virsh list --all

net:
	virsh net-dumpxml default

