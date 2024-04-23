kubectl create secret generic kubernetes-the-hard-way \
  --from-literal="mykey=mydata"

ssh root@server \
    'etcdctl get /registry/secrets/default/kubernetes-the-hard-way | hexdump -C'
