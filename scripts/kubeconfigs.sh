for host in node-0 node-1; do
	kubectl config set-cluster kubernetes-the-hard-way \
		--certificate-authority=ca.crt \
		--embed-certs=true \
		--server=https://server.kubernetes.local:6443 \
		--kubeconfig=${host}.kubeconfig

	kubectl config set-credentials system:node:${host} \
		--client-certificate=${host}.crt \
		--client-key=${host}.key \
		--embed-certs=true \
		--kubeconfig=${host}.kubeconfig

	kubectl config set-context default \
		--cluster=kubernetes-the-hard-way \
		--user=system:node:${host} \
		--kubeconfig=${host}.kubeconfig

	kubectl config use-context default --kubeconfig=${host}.kubeconfig	
done

kubectl config set-cluster kubernetes-the-hard-way \
	--certificate-authority=ca.crt \
	--embed-certs=true \
	--server=https://server.kubernetes.local:6443 \
	--kubeconfig=kube-proxy.kubeconfig

kubectl config set-credentials system:kube-proxy \
	--client-certificate=kube-proxy.crt \
	--client-key=kube-proxy.key \
	--embed-certs=true \
	--kubeconfig=kube-proxy.kubeconfig

kubectl config set-context default \
	--cluster=kubernetes-the-hard-way \
	--user=system:kube-proxy \
	--kubeconfig=kube-proxy.kubeconfig

kubectl config use-context default --kubeconfig=kube-proxy.kubeconfig	

kubectl config set-cluster kubernetes-the-hard-way \
	--certificate-authority=ca.crt \
	--embed-certs=true \
	--server=https://server.kubernetes.local:6443 \
	--kubeconfig=kube-controller-manager.kubeconfig

kubectl config set-credentials system:kube-controller-manager \
	--client-certificate=kube-controller-manager.crt \
	--client-key=kube-controller-manager.key \
	--embed-certs=true \
	--kubeconfig=kube-controller-manager.kubeconfig

kubectl config set-context default \
	--cluster=kubernetes-the-hard-way \
	--user=system:kube-controller-manager \
	--kubeconfig=kube-controller-manager.kubeconfig

kubectl config use-context default --kubeconfig=kube-controller-manager.kubeconfig	

kubectl config set-cluster kubernetes-the-hard-way \
	--certificate-authority=ca.crt \
	--embed-certs=true \
	--server=https://server.kubernetes.local:6443 \
	--kubeconfig=kube-scheduler.kubeconfig

kubectl config set-credentials system:kube-scheduler \
	--client-certificate=kube-scheduler.crt \
	--client-key=kube-scheduler.key \
	--embed-certs=true \
	--kubeconfig=kube-scheduler.kubeconfig

kubectl config set-context default \
	--cluster=kubernetes-the-hard-way \
	--user=system:kube-scheduler \
	--kubeconfig=kube-scheduler.kubeconfig

kubectl config use-context default --kubeconfig=kube-scheduler.kubeconfig	

kubectl config set-cluster kubernetes-the-hard-way \
	--certificate-authority=ca.crt \
	--embed-certs=true \
	--server=https://server.kubernetes.local:6443 \
	--kubeconfig=admin.kubeconfig

kubectl config set-credentials admin \
	--client-certificate=admin.crt \
	--client-key=admin.key \
	--embed-certs=true \
	--kubeconfig=admin.kubeconfig

kubectl config set-context default \
	--cluster=kubernetes-the-hard-way \
	--user=admin \
	--kubeconfig=admin.kubeconfig

kubectl config use-context default --kubeconfig=admin.kubeconfig	

for host in node-0 node-1; do
	ssh root@$host "mkdir -p /var/lib/{kube-proxy,kubelet}"
	scp kube-proxy.kubeconfig \
		root@$host:/var/lib/kube-proxy/kubeconfig 
	scp ${host}.kubeconfig \
		root@$host:/var/lib/kubelet/kubeconfig

done

scp admin.kubeconfig \
	kube-controller-manager.kubeconfig \
	kube-scheduler.kubeconfig \
	root@server:~/
