#!/bin/bash

scp \
	ca.key ca.crt \
	kube-api-server.key kube-api-server.crt \
	service-accounts.key service-accounts.crt \
	root@server:~/
