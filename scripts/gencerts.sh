#!/bin/bash

certs=(admin node-0 node-1 kube-proxy kube-scheduler kube-controller-manager kube-api-server service-accounts)

for i in ${certs[*]}; do
	openssl genrsa -out "${i}.key" 4096

	openssl req -new -key "${i}.key" -sha256 \
		-config "k8s/ca.conf" -section ${i} \
		-out "${i}.csr"

	openssl x509 -req -days 3653 -in "${i}.csr" \
		-copy_extensions copyall \
		-sha256 -CA "ca.crt" \
		-CAkey "ca.key" \
		-CAcreateserial \
		-out "${i}.crt"
done
