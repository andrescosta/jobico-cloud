scp downloads/etcd-v3.4.27-linux-amd64.tar.gz k8s/units/etcd.service root@server:~/
ssh root@server << 'EOF'
tar -xvf ~/etcd-v3.4.27-linux-amd64.tar.gz
mv ~/etcd-v3.4.27-linux-amd64/etcd* /usr/local/bin
mkdir -p /etc/etcd /var/lib/etcd
cp ca.crt kube-api-server.key kube-api-server.crt \
	/etc/etcd/
mv ~/etcd.service /etc/systemd/system
systemctl daemon-reload
systemctl enable etcd
systemctl start etcd
etcdctl member list
EOF
