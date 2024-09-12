jobico::cluster::deploy_to_servers(){
    local servers=($(jobico::dao::cluster::get server 1))
    for host in ${servers[@]}; do
        SCP $(downloads_dir)/kube-apiserver \
        $(downloads_dir)/kube-controller-manager \
        $(downloads_dir)/kube-scheduler \
        $(downloads_dir)/kubectl \
        $(work_dir)/kube-apiserver.service \
        ${EXTRAS_DIR}/units/kube-controller-manager.service \
        ${EXTRAS_DIR}/units/kube-scheduler.service \
        ${EXTRAS_DIR}/configs/kube-scheduler.yaml \
        ${EXTRAS_DIR}/configs/kube-apiserver-to-kubelet.yaml root@$host:~/
    
        SSH root@$host \
<< 'EOF'
  mkdir -p /etc/kubernetes/config
  chmod +x kube-apiserver \
    kube-controller-manager \
    kube-scheduler kubectl

  mv kube-apiserver \
    kube-controller-manager \
    kube-scheduler kubectl \
    /usr/local/bin

  mkdir -p /var/lib/kubernetes

  mv ca.crt ca.key \
    kube-api-server.key kube-api-server.crt \
    service-accounts.key service-accounts.crt \
    encryption-config.yaml \
    /var/lib/kubernetes

  mv kube-apiserver.service \
    /etc/systemd/system/kube-apiserver.service

  mv kube-controller-manager.kubeconfig /var/lib/kubernetes/
  mv kube-controller-manager.service /etc/systemd/system/
  mv kube-scheduler.kubeconfig /var/lib/kubernetes/
  mv kube-scheduler.yaml /etc/kubernetes/config/
  mv kube-scheduler.service /etc/systemd/system/

  systemctl daemon-reload
  systemctl enable kube-apiserver \
    kube-controller-manager kube-scheduler

  systemctl start kube-apiserver \
    kube-controller-manager kube-scheduler

  sleep 10

  kubectl cluster-info \
    --kubeconfig admin.kubeconfig

  kubectl apply -f kube-apiserver-to-kubelet.yaml \
    --kubeconfig admin.kubeconfig

EOF
    done
}

## Nodes deployment

jobico::cluster::deploy_to_nodes(){
     jobico::dao::cluster::members | while read IP FQDN HOST SUBNET TYPE SCH; do
        sed "s|SUBNET|${SUBNET}|g" \
        ${EXTRAS_DIR}/configs/10-bridge.conf > $(work_dir)/10-bridge.conf

        if [[ "$TYPE" == "server" && "$SCH" == "$TAINTED" ]]; then
            cp ${EXTRAS_DIR}/configs/kubelet-config-tainted.yaml $(work_dir)/kubelet-config.yaml
        else
            cp ${EXTRAS_DIR}/configs/kubelet-config.yaml $(work_dir)/kubelet-config.yaml
        fi

        sed -i "s|SUBNET|${SUBNET}|g" $(work_dir)/kubelet-config.yaml
        
        SCP $(work_dir)/10-bridge.conf \
        $(work_dir)/kubelet-config.yaml \
        root@${IP}:~/
    done
    
     jobico::dao::cluster::members | while read IP FQDN HOST SUBNET TYPE SCH; do
        SCP $(downloads_dir)/runc.amd64 \
        $(downloads_dir)/crictl.tar.gz \
        $(downloads_dir)/cni-plugins.tgz \
        $(downloads_dir)/containerd.tar.gz\
        $(downloads_dir)/kubectl \
        $(downloads_dir)/kubelet \
        $(downloads_dir)/kube-proxy \
        ${EXTRAS_DIR}/configs/99-loopback.conf \
        ${EXTRAS_DIR}/configs/containerd-config.toml \
        ${EXTRAS_DIR}/configs/kube-proxy-config.yaml \
        ${EXTRAS_DIR}/units/containerd.service \
        ${EXTRAS_DIR}/units/kubelet.service \
        ${EXTRAS_DIR}/units/kube-proxy.service root@${IP}:~/
    done
    
    jobico::dao::cluster::members | while read IP FQDN HOST SUBNET TYPE SCH; do
        SSH root@${IP} \
<< 'EOF'

  swapoff -a

  mkdir -p \
    /etc/cni/net.d \
    /opt/cni/bin \
    /var/lib/kubelet \
    /var/lib/kube-proxy \
    /var/lib/kubernetes \
    /var/run/kubernetes

  mkdir -p containerd
  tar -xvf crictl.tar.gz
  tar -xvf containerd.tar.gz -C containerd
  tar -xvf cni-plugins.tgz -C /opt/cni/bin/
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
}
