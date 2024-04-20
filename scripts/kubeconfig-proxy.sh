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


