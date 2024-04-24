.PHONY: cluster destroy local deps

cluster:
	bash ./scripts/cluster.sh

destroy:
	bash ./scripts/destroy.sh

local:
	bash ./scripts/local.sh

## Deps

deps: 
	bash ./scripts/install.sh


## Utils

status:
	cloud-init status

dhcp:
	@virsh -q net-dhcp-leases default

list: 
	virsh list --all

net:
	virsh net-dumpxml default

