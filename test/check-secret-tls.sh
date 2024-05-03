ssh root@server-1 \
'etcdctl get --cert=/etc/etcd/etcd-server.crt --key=/etc/etcd/etcd-server.key --cacert=/etc/etcd/ca.crt /registry/secrets/default/kubernetes-the-hard-way | hexdump -C'
ssh root@server-0 \
'etcdctl get --cert=/etc/etcd/etcd-server.crt --key=/etc/etcd/etcd-server.key --cacert=/etc/etcd/ca.crt /registry/secrets/default/kubernetes-the-hard-way | hexdump -C'
