for host in node-0 node-1; do
	SUBNET=$(grep $host ../machines.txt | cut -d " " -f 4)
	echo "==========$SUBNET==========="
	sed "s|SUBNET|$SUBNET|g" \
		k8s/configs/10-bridge.conf > 10-bridge.conf

	sed "s|SUBNET|$SUBNET|g" \
		k8s/configs/kubelet-config.yaml > kubelet-config.yaml

	scp 10-bridge.conf kubelet-config.yaml \
		root@$host:~/
done

for host in node-0 node-1; do
    scp downloads/runc.amd64 downloads/crictl-v1.28.0-linux-amd64.tar.gz downloads/cni-plugins-linux-amd64-v1.3.0.tgz downloads/containerd-1.7.8-linux-amd64.tar.gz downloads/kubectl downloads/kubelet downloads/kube-proxy k8s/configs/99-loopback.conf k8s/configs/containerd-config.toml k8s/configs/kube-proxy-config.yaml k8s/units/containerd.service k8s/units/kubelet.service k8s/units/kube-proxy.service root@$host:~/
done

for host in node-0 node-1; do

ssh root@$host << 'EOF'

apt-get update
apt-get -y install socat conntrack ipset

swapoff -a

mkdir -p \
  /etc/cni/net.d \
  /opt/cni/bin \
  /var/lib/kubelet \
  /var/lib/kube-proxy \
  /var/lib/kubernetes \
  /var/run/kubernetes

mkdir -p containerd
tar -xvf crictl-v1.28.0-linux-amd64.tar.gz
tar -xvf containerd-1.7.8-linux-amd64.tar.gz -C containerd
tar -xvf cni-plugins-linux-amd64-v1.3.0.tgz -C /opt/cni/bin/
mv runc.amd64 runc
chmod +x crictl kubectl kube-proxy kubelet runc 
mv crictl kubectl kube-proxy kubelet runc /usr/local/bin/
mv containerd/bin/* /bin/

mv 10-bridge.conf 99-loopback.conf /etc/cni/net.d/
mkdir -p /etc/containerd/
mv containerd-config.toml /etc/containerd/config.toml
mv containerd.service /etc/systemd/system/
mv kubelet-config.yaml /var/lib/kubelet/
mv kubelet.service /etc/systemd/system/
mv kube-proxy-config.yaml /var/lib/kube-proxy/
mv kube-proxy.service /etc/systemd/system/

systemctl daemon-reload
systemctl enable containerd kubelet kube-proxy
systemctl start containerd kubelet kube-proxy

EOF

done
