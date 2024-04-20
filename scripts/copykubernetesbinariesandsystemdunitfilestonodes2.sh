for host in node-0 node-1; do
    scp downloads/runc.amd64 downloads/crictl-v1.28.0-linux-amd64.tar.gz downloads/cni-plugins-linux-amd64-v1.3.0.tgz downloads/containerd-1.7.8-linux-amd64.tar.gz downloads/kubectl downloads/kubelet downloads/kube-proxy configs/99-loopback.conf configs/containerd-config.toml configs/kubelet-config.yaml configs/kube-proxy-config.yaml units/containerd.service units/kubelet.service units/kube-proxy.service root@$host:~/
done
