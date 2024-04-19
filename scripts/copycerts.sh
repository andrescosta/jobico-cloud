#!/bin/bash

for host in node-0 node-1; do
	ssh root@$host mkdir /var/lib/kubelet/
	
	scp ca.crt root@$host:/var/lib/kubelet/

	scp $host.crt \
		root@$host:/var/lib/kubelet/kubelet.crt

	scp $host.key \
		root@$host:/var/lib/kubelet/kubelet.key
done
