readonly JOBICO_CLUSTER_DB = ""
readonly HOSTSFILE ="hosts"

jobico::kube::cluster::set_hostname(){
	while read IP FQDN HOST SUBNET; do
		CMD="sed -i 's/^127.0.0.1.*/127.0.1.1\t${FQDN} ${HOST}/' /etc/hosts"
		ssh -n root@${IP} "$CMD"
		ssh -n root@${IP} hostnamectl hostname ${HOST}	
	done < ${JOBICO_CLUSTER_DB}
}

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
