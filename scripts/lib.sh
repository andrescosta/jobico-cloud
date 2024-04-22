readonly WORK_DIR="work"
readonly DOWNLOADS_DIR="${WORK_DIR}/downloads"
readonly EXTRAS_DIR="${WORK_DIR}/k8s"
readonly HOSTSFILE="${WORK_DIR}/hosts"
readonly CA_CONF="${EXTRAS_DIR}/ca.conf" 
readonly MAKE=make
readonly STATUS_FILE=${WORK_DIR}/jobico_status

jobico::kube::create_vms(){
	while read IP FQDN HOST SUBNET; do
	  make -f Makefile.vm new-vm VM_IP=${IP} VM_NAME=${HOST}
	done < ${JOBICO_CLUSTER_TBL}
}

jobico::kube::destroy_vms(){
	while read IP FQDN HOST SUBNET; do
    make -f Makefile.vm destroy-vm VM_IP=${IP} VM_NAME=${HOST}
	done < ${JOBICO_CLUSTER_TBL}
}

jobico::kube::deps(){
  if ! grep -q "deps" "${STATUS_FILE}"; then
	  git clone --depth 1 https://github.com/kelseyhightower/kubernetes-the-hard-way.git ${EXTRAS_DIR}
    #mv ${WORK_DIR}/kubernetes-the-hard-way ${EXTRAS_DIR}
	  sed 's/arm64/amd64/' ${EXTRAS_DIR}/downloads.txt > ${WORK_DIR}/downloads_amd64_1.txt 
    sed 's/arm/amd64/' ${WORK_DIR}/downloads_amd64_1.txt > ${WORK_DIR}/downloads_amd64.txt 
	  mkdir -p ${DOWNLOADS_DIR}
    wget -q --https-only -P  ${DOWNLOADS_DIR} -i ${WORK_DIR}/downloads_amd64.txt
    jobico::kube::set_done "deps"
  fi
}
jobico::kube::init::locals(){
  if ! grep -q "locals" "${STATUS_FILE}"; then
    sudo cp ${DOWNLOADS_DIR}/kubectl /usr/local/bin && \
	  sudo chmod +x /usr/local/bin/kubectl
    jobico::kube::set_done "locals"
  fi
}
jobico::kube::load_database(){
  cp machines.txt ${WORK_DIR}
  readonly MACHINES_DB="${WORK_DIR}/machines.txt"
  readonly JOBICO_CLUSTER_TBL=${MACHINES_DB}
  readonly COMPONENTS_TBL=(admin node-0 node-1 kube-proxy kube-scheduler kube-controller-manager kube-api-server service-accounts)
  readonly NODE_TBL=(node-0 node-1)
  readonly COMPONENTS_CP_TBL=(admin kube-proxy kube-scheduler kube-controller-manager)
  readonly ENCRYPTION_KEY=$(head -c 32 /dev/urandom | base64)
  readonly SERVER_IP=$(grep server ${MACHINES_DB} | cut -d " " -f 1)
  readonly NODE_0_IP=$(grep node-0 ${MACHINES_DB} | cut -d " " -f 1)
  readonly NODE_0_SUBNET=$(grep node-0  ${MACHINES_DB} | cut -d " " -f 4)
  readonly NODE_1_IP=$(grep node-1 ${MACHINES_DB} | cut -d " " -f 1)
  readonly NODE_1_SUBNET=$(grep node-1 ${MACHINES_DB} | cut -d " " -f 4)
}

jobico::kube::init(){
  mkdir -p ${WORK_DIR}
  touch ${STATUS_FILE}
}
jobico::kube::machines(){
  jobico::kube::init
  if ! grep -q "machines" ${STATUS_FILE}; then
    jobico::kube::load_database 
    jobico::kube::create_vms
    jobico::kube::set_done "machines"
  fi
}
jobico::kube::destroy_machines(){
  jobico::kube::load_database 
  jobico::kube::destroy_vms
}
jobico::kube::cluster(){
  jobico::kube::init
  jobico::kube::load_database 
  jobico::kube::deps
  jobico::kube::init::locals
  jobico::kube::generate
}
jobico::kube::generate(){
  echo "Generating ..."
  #DNS
  if ! grep -q "host" ${STATUS_FILE}; then
    jobico::kube::gen_hostsfile
    jobico::kube::cluster::set_hostname
    jobico::kube::cluster::update_hostnames_file
    jobico::kube::set_done "host"
  fi
  #TLS
  if ! grep -q "tls_certs" ${STATUS_FILE}; then
    jobico::kube::tls::gen_ca
    jobico::kube::tls::gen_certs
    jobico::kube::tls::deploy_certs_to_nodes
    jobico::kube::tls::deploy_certs_to_server
    jobico::kube::set_done "tls_certs"
  fi
  #Kubeconfig
  if ! grep -q "kubeconfig" ${STATUS_FILE}; then
    jobico::kube::kubeconfig::gen_for_nodes
    jobico::kube::kubeconfig::gen_for_controlplane
    jobico::kube::kubeconfig::gen_locally_for_kube_admin
    jobico::kube::kubeconfig::deploy_to_nodes
    jobico::kube::kubeconfig::deploy_to_server
    jobico::kube::set_done "kubeconfig"
  fi
  #Encryption at rest
  if ! grep -q "encatrest" ${STATUS_FILE}; then
    jobico::kube::encryption::gen_key
    jobico::kube::encryption::deploy_key_to_server
    jobico::kube::set_done "encatrest"
  fi
  #Etcd 
  if ! grep -q "etcddb" ${STATUS_FILE}; then
    jobico::kube::etcd::deploy_to_server
    jobico::kube::set_done "etcddb"
  fi
  #Deployment
  if ! grep -q "deploy_server" ${STATUS_FILE}; then
    #jobico::kube::deploy_aux
    jobico::kube::deploy_deps_to_server
    jobico::kube::set_done "deploy_server"
  fi
  if ! grep -q "deploy_nodes" ${STATUS_FILE}; then
    jobico::kube::deploy_deps_to_nodes
    jobico::kube::set_done "deploy_nodes"
  fi
  # Routes
  if ! grep -q "add_routes" ${STATUS_FILE}; then
    jobico::kube::cluster::add_routes
    jobico::kube::set_done "add_routes"
  fi
  echo "Cluster generated ..."
}
jobico::kube::set_done(){
  echo "|$1|" >> ${WORK_DIR}/jobico_status
}
jobico::kube::deploy_aux(){
    jobico::kube::kubeconfig::deploy_to_server
    jobico::kube::tls::deploy_certs_to_server
    jobico::kube::encryption::deploy_key_to_server
}
jobico::kube::gen_hostsfile(){
	echo "" > ${HOSTSFILE} 
	echo "# Kubernetes Cluster" >> ${HOSTSFILE} 
	while read IP FQDN HOST SUBNET; do
		ENTRY="${IP} ${FQDN} ${HOST}"
		echo $ENTRY >> ${HOSTSFILE} 
	done < ${JOBICO_CLUSTER_TBL}
}

jobico::kube::update_local_hostsfile(){
	cat  ${HOSTSFILE} >> /etc/hosts
}

jobico::kube::cluster::set_hostname(){
	while read IP FQDN HOST SUBNET; do
		CMD="sed -i 's/^127.0.0.1.*/127.0.1.1\t${FQDN} ${HOST}/' /etc/hosts"
		ssh -n root@${IP} "$CMD"
		ssh -n root@${IP} hostnamectl hostname ${HOST}	
	done < ${JOBICO_CLUSTER_TBL}
}

jobico::kube::cluster::update_hostnames_file(){
	while read IP FQDN HOST SUBNET; do
		scp  ${HOSTSFILE} root@${HOST}:~/
		ssh -n \
		  root@${HOST} "cat hosts >> /etc/hosts"	
	done < ${JOBICO_CLUSTER_TBL}
}

jobico::kube::tls::gen_ca(){
	openssl genrsa -out ${WORK_DIR}/ca.key 4096
	openssl req -x509 -new -sha512 -noenc \
		-key ${WORK_DIR}/ca.key -days 3653 \
		-config ${CA_CONF}\
		-out ${WORK_DIR}/ca.crt
}

jobico::kube::tls::gen_certs(){
	for i in ${COMPONENTS_TBL[*]}; do
		openssl genrsa -out "${WORK_DIR}/${i}.key" 4096

		openssl req -new -key "${WORK_DIR}/${i}.key" -sha256 \
		  -config "${EXTRAS_DIR}/ca.conf" -section ${i} \
		  -out "${WORK_DIR}/${i}.csr"

		openssl x509 -req -days 3653 -in "${WORK_DIR}/${i}.csr" \
		  -copy_extensions copyall \
		  -sha256 -CA "${WORK_DIR}/ca.crt" \
		  -CAkey "${WORK_DIR}/ca.key" \
		  -CAcreateserial \
		  -out "${WORK_DIR}/${i}.crt"
	done
}

jobico::kube::tls::deploy_certs_to_nodes(){
	for host in ${NODE_TBL[*]}; do
		ssh root@$host mkdir -p /var/lib/kubelet/
	
		scp ${WORK_DIR}/ca.crt root@$host:/var/lib/kubelet/

		scp ${WORK_DIR}/$host.crt \
		  root@$host:/var/lib/kubelet/kubelet.crt

		scp ${WORK_DIR}/$host.key \
		  root@$host:/var/lib/kubelet/kubelet.key
	done
}

jobico::kube::tls::deploy_certs_to_server(){
	scp \
	  ${WORK_DIR}/ca.key ${WORK_DIR}/ca.crt \
  	  ${WORK_DIR}/kube-api-server.key ${WORK_DIR}/kube-api-server.crt \
	  ${WORK_DIR}/service-accounts.key ${WORK_DIR}/service-accounts.crt \
	  root@server:~/
}

jobico::kube::kubeconfig::gen_for_nodes(){
	for host in ${NODE_TBL[*]}; do
	  kubectl config set-cluster kubernetes-the-hard-way \
		--certificate-authority=${WORK_DIR}/ca.crt \
		--embed-certs=true \
		--server=https://server.kubernetes.local:6443 \
		--kubeconfig=${WORK_DIR}/${host}.kubeconfig

	  kubectl config set-credentials system:node:${host} \
		--client-certificate=${WORK_DIR}/${host}.crt \
		--client-key=${WORK_DIR}/${host}.key \
		--embed-certs=true \
		--kubeconfig=${WORK_DIR}/${host}.kubeconfig

	  kubectl config set-context default \
		--cluster=kubernetes-the-hard-way \
		--user=system:node:${host} \
		--kubeconfig=${WORK_DIR}/${host}.kubeconfig

	  kubectl config use-context default --kubeconfig=${WORK_DIR}/${host}.kubeconfig	
  done
}

jobico::kube::kubeconfig::gen_for_controlplane(){
  for comp in ${COMPONENTS_CP_TBL[*]}; do
    kubectl config set-cluster kubernetes-the-hard-way \
      --certificate-authority=${WORK_DIR}/ca.crt \
      --embed-certs=true \
      --server=https://server.kubernetes.local:6443 \
      --kubeconfig=${WORK_DIR}/${comp}.kubeconfig

    kubectl config set-credentials system:${comp} \
      --client-certificate=${WORK_DIR}/${comp}.crt \
      --client-key=${WORK_DIR}/${comp}.key \
      --embed-certs=true \
      --kubeconfig=${WORK_DIR}/${comp}.kubeconfig

    kubectl config set-context default \
      --cluster=kubernetes-the-hard-way \
      --user=system:${comp} \
      --kubeconfig=${WORK_DIR}/${comp}.kubeconfig

    kubectl config use-context default --kubeconfig=${WORK_DIR}/${comp}.kubeconfig	
  done
}

jobico::kube::kubeconfig::deploy_to_nodes(){
  for host in node-0 node-1; do
    ssh root@$host "mkdir -p /var/lib/{kube-proxy,kubelet}"
    scp ${WORK_DIR}/kube-proxy.kubeconfig \
      root@$host:/var/lib/kube-proxy/kubeconfig 
    scp ${WORK_DIR}/${host}.kubeconfig \
      root@$host:/var/lib/kubelet/kubeconfig
  done
}

jobico::kube::kubeconfig::deploy_to_server(){
  scp ${WORK_DIR}/admin.kubeconfig \
    ${WORK_DIR}/kube-controller-manager.kubeconfig \
    ${WORK_DIR}/kube-scheduler.kubeconfig \
    root@server:~/
}

jobico::kube::encryption::gen_key(){
  cat > ${WORK_DIR}/encryption-config.yaml \
<<EOF
  kind: EncryptionConfig
  apiVersion: v1
  resources: 
    - resources:
        - secrets
      providers: 
        - aescbc:
            keys:
              - name: key1
                secret: ${ENCRYPTION_KEY}
        - identity: {}
EOF
}

jobico::kube::encryption::deploy_key_to_server(){
  scp ${WORK_DIR}/encryption-config.yaml root@server:~/
}

jobico::kube::etcd::deploy_to_server(){
  scp ${DOWNLOADS_DIR}/etcd-v3.4.27-linux-amd64.tar.gz ${EXTRAS_DIR}/units/etcd.service root@server:~/
  ssh root@server << 'EOF'
tar -xvf ~/etcd-v3.4.27-linux-amd64.tar.gz
mv ~/etcd-v3.4.27-linux-amd64/etcd* /usr/local/bin
mkdir -p /etc/etcd /var/lib/etcd
cp ca.crt \
kube-api-server.key \
kube-api-server.crt /etc/etcd/
mv ~/etcd.service /etc/systemd/system
systemctl daemon-reload
systemctl enable etcd
systemctl start etcd
etcdctl member list
EOF
}

jobico::kube::deploy_deps_to_server(){
  scp ${DOWNLOADS_DIR}/kube-apiserver \
    ${DOWNLOADS_DIR}/kube-controller-manager \
    ${DOWNLOADS_DIR}/kube-scheduler \
    ${DOWNLOADS_DIR}/kubectl \
    ${EXTRAS_DIR}/units/kube-apiserver.service \
    ${EXTRAS_DIR}/units/kube-controller-manager.service \
    ${EXTRAS_DIR}/units/kube-scheduler.service \
    ${EXTRAS_DIR}/configs/kube-scheduler.yaml \
    ${EXTRAS_DIR}/configs/kube-apiserver-to-kubelet.yaml root@server:~/

  ssh root@server \
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
}

jobico::kube::deploy_deps_to_nodes(){
  for host in ${NODE_TBL[*]}; do
    subnets=$(grep $host $MACHINES_DB | cut -d " " -f 4)
    sed "s|SUBNET|${subnets}|g" \
      ${EXTRAS_DIR}/configs/10-bridge.conf > ${WORK_DIR}/10-bridge.conf

    sed "s|SUBNET|${subnets}|g" \
      ${EXTRAS_DIR}/configs/kubelet-config.yaml > ${WORK_DIR}/kubelet-config.yaml

    scp ${WORK_DIR}/10-bridge.conf \
        ${WORK_DIR}/kubelet-config.yaml \
         root@$host:~/
  done

  for host in ${NODE_TBL[*]}; do
      scp ${DOWNLOADS_DIR}/runc.amd64 \
        ${DOWNLOADS_DIR}/crictl-v1.28.0-linux-amd64.tar.gz \
        ${DOWNLOADS_DIR}/cni-plugins-linux-amd64-v1.3.0.tgz \
        ${DOWNLOADS_DIR}/containerd-1.7.8-linux-amd64.tar.gz \
        ${DOWNLOADS_DIR}/kubectl \
        ${DOWNLOADS_DIR}/kubelet \
        ${DOWNLOADS_DIR}/kube-proxy \
        ${EXTRAS_DIR}/configs/99-loopback.conf \
        ${EXTRAS_DIR}/configs/containerd-config.toml \
        ${EXTRAS_DIR}/configs/kube-proxy-config.yaml \
        ${EXTRAS_DIR}/units/containerd.service \
        ${EXTRAS_DIR}/units/kubelet.service \
        ${EXTRAS_DIR}/units/kube-proxy.service root@$host:~/
  done

  for host in ${NODE_TBL[*]}; do
    ssh root@$host \
<< 'EOF'

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
}
jobico::kube::cluster::set_local(){
  jobico::kube::kubeconfig::gen_locally_for_kube_admin
}
jobico::kube::kubeconfig::gen_locally_for_kube_admin(){
  kubectl config set-cluster kubernetes-the-hard-way \
      --certificate-authority=${WORK_DIR}/ca.crt \
      --embed-certs=true \
      --server=https://server.kubernetes.local:6443

  kubectl config set-credentials admin \
      --client-certificate=${WORK_DIR}/admin.crt \
      --client-key=${WORK_DIR}/admin.key

  kubectl config set-context kubernetes-the-hard-way \
      --cluster=kubernetes-the-hard-way \
      --user=admin

  kubectl config use-context kubernetes-the-hard-way
}

jobico::kube::cluster::add_routes(){
  ssh root@server \
<<EOF
    ip route add ${NODE_0_SUBNET} via ${NODE_0_IP}
    ip route add ${NODE_1_SUBNET} via ${NODE_1_IP}
EOF

  ssh root@node-0 \
<<EOF
  ip route add $NODE_1_SUBNET via $NODE_1_IP
EOF

  ssh root@node-1 \
<<EOF
ip route add $NODE_0_SUBNET via $NODE_0_IP
EOF
}
