readonly WORK_DIR ="work"
readonly JOBICO_CLUSTER_DB = "machines.txt"
readonly HOSTSFILE ="${WORK_DIR}/hosts"
readonly CA_CONF="k8s/ca.conf" 
readonly COMPONENTS=(admin node-0 node-1 kube-proxy kube-scheduler kube-controller-manager kube-api-server service-accounts)
jobico::kube::gen_hostsfile(){
	echo "" > ${HOSTSFILE} 
	echo "# Kubernetes Cluster" >> ${HOSTSFILE} 
	while read IP FQDN HOST SUBNET; do
		ENTRY="${IP} ${FQDN} ${HOST}"
		echo $ENTRY >> ${HOSTSFILE} 
	done < ${JOBICO_CLUSTER_DB}
}

jobico::kube::update_hostsfile(){
	cat  ${HOSTSFILE} >> /etc/hosts
}

jobico::kube::cluster::set_hostname(){
	while read IP FQDN HOST SUBNET; do
		CMD="sed -i 's/^127.0.0.1.*/127.0.1.1\t${FQDN} ${HOST}/' /etc/hosts"
		ssh -n root@${IP} "$CMD"
		ssh -n root@${IP} hostnamectl hostname ${HOST}	
	done < ${JOBICO_CLUSTER_DB}
}

jobico::kube::cluster::update_hostnames_file(){
	while read IP FQDN HOST SUBNET; do
		scp hosts root@${HOST}:~/
		ssh -n \
		  root@${HOST} "cat hosts >> /etc/hosts"	
	done < ${JOBICO_CLUSTER_DB}
}

jubico::kube::tls::genca(){
	openssl genrsa -out ${WORK_DIR}/ca.key 4096
	openssl req -x509 -new -sha512 -noenc \
		-key ${WORK_DIR}/ca.key -days 3653 \
		-config ${CA_CONF}\
		-out ${WORK_DIR}/ca.crt
}

jobico::kube::tls::gencerts(){
	for i in ${COMPONENTS[*]}; do
		openssl genrsa -out "${WORK_DIR}/{i}.key" 4096

		openssl req -new -key "${WORK_DIR}/${i}.key" -sha256 \
		  -config "k8s/ca.conf" -section ${i} \
		  -out "${WORK_DIR}/${i}.csr"

		openssl x509 -req -days 3653 -in "${WORK_DIR}/${i}.csr" \
		  -copy_extensions copyall \
		  -sha256 -CA "${WORK_DIR}/ca.crt" \
		  -CAkey "${WORK_DIR}/ca.key" \
		  -CAcreateserial \
		  -out "${WORK_DIR}/${i}.crt"
	done
}

jobico::kube::tls::copycertstonodes(){
	for host in node-0 node-1; do
		ssh root@$host mkdir /var/lib/kubelet/
	
		scp ca.crt root@$host:/var/lib/kubelet/

		scp $host.crt \
		  root@$host:/var/lib/kubelet/kubelet.crt

		scp $host.key \
		  root@$host:/var/lib/kubelet/kubelet.key
	done
}
