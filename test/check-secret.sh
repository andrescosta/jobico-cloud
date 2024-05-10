SSH root@server \
'etcdctl get --cert=/etc/etcd/etcd-server.crt --key=/etc/etcd/etcd-server.key --cacert=/etc/etcd/ca.crt /registry/secrets/default/kubernetes-the-hard-way | hexdump -C'
