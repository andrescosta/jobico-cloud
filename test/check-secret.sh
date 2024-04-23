ssh root@server \
    'etcdctl get /registry/secrets/default/kubernetes-the-hard-way | hexdump -C'
