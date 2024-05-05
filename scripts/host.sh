
kube::host::gen_hostsfile(){
    echo ${BEGIN_HOSTS_FILE} > ${HOSTSFILE}
    while read IP FQDN HOST SUBNET TYPE; do
        entry="${IP} ${FQDN} ${HOST}"
        echo ${entry} >> ${HOSTSFILE}
    done < ${JOBICO_CLUSTER_TBL}
    echo  ${END_HOSTS_FILE}>> ${HOSTSFILE}
}
kube::host::update_local_etc_hosts(){
    local cmd="cat ${HOSTSFILE} >> /etc/hosts"
    sudo bash -c "$cmd"
}
kube::host::restore_local_etc_hosts(){
    sed "/${BEGIN_HOSTS_FILE}/,/${END_HOSTS_FILE}/d" /etc/hosts > ${WORK_DIR}/uhosts
    sudo bash -c "cp ${WORK_DIR}/uhosts /etc/hosts"
}
kube::host::update_local_known_hosts(){
     kube::dao::cluster::machines | while read IP FQDN HOST SUBNET TYPE; do
        ssh-keyscan -H ${HOST} >> ~/.ssh/known_hosts
        ssh-keyscan -H ${IP} >> ~/.ssh/known_hosts
    done 
}
kube::host::set_machines_hostname(){
    kube::dao::cluster::machines | while read IP FQDN HOST SUBNET TYPE; do
        cmd="sed -i 's/^127.0.0.1.*/127.0.1.1\t${FQDN} ${HOST}/' /etc/hosts"
        ssh -n root@${IP} "${cmd}"
        ssh -n root@${IP} hostnamectl hostname ${HOST}
    done 
}
kube::host::update_machines_etc_hosts(){
     kube::dao::cluster::machines | while read IP FQDN HOST SUBNET TYPE; do
        scp  ${HOSTSFILE} root@${IP}:~/
        ssh -n \
            root@${IP} "cat hosts >> /etc/hosts"
    done 
}

