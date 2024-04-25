sed '/#B> Kubernetes Cluster/,/#E> Kubernetes Cluster/d' /etc/hosts  > work/newhosts
cp work/newhosts /etc/hosts

