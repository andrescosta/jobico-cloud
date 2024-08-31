jobico::host::host_file(){
    echo "$(work_dir)/hosts"
}

jobico::host::gen_hostsfile() {
    echo ${BEGIN_HOSTS_FILE} >$(jobico::host::host_file)
    jobico::dao::cluster::all | while read IP FQDN HOST SUBNET TYPE SCH; do
        entry="${IP} ${FQDN} ${HOST}"
        echo ${entry} >>$(jobico::host::host_file)
    done
    echo ${END_HOSTS_FILE} >>$(jobico::host::host_file)
}
jobico::host::update_local_etc_hosts() {
    jobico::host::restore_local_etc_hosts
    local cmd="cat $(jobico::host::host_file) >> /etc/hosts"
    sudo bash -c "$cmd"
}
jobico::host::restore_local_etc_hosts() {
    sed "/${BEGIN_HOSTS_FILE}/,/${END_HOSTS_FILE}/d" /etc/hosts >$(work_dir)/uhosts
    sudo bash -c "cp $(work_dir)/uhosts /etc/hosts"
}
jobico::host::update_local_known_hosts() {
    jobico::dao::cluster::machines | while read IP FQDN HOST SUBNET TYPE SCH; do
        ssh-keyscan -H ${HOST} >>~/.ssh/known_hosts
        ssh-keyscan -H ${IP} >>~/.ssh/known_hosts
    done
}
jobico::host::set_machines_hostname() {
    jobico::dao::cluster::machines | while read IP FQDN HOST SUBNET TYPE SCH; do
        cmd="sed -i 's/^127.0.0.1.*/127.0.1.1\t${FQDN} ${HOST}/' /etc/hosts"
        SSH -n root@${IP} "${cmd}"
        SSH -n root@${IP} hostnamectl hostname ${HOST}
    done
}
jobico::host::update_machines_etc_hosts() {
    jobico::dao::cluster::machines | while read IP FQDN HOST SUBNET TYPE SCH; do
        SCP $(jobico::host::host_file) root@${IP}:~/
        SSH -n \
            root@${IP} "cat hosts >> /etc/hosts"
    done
}
jobico::host::add_new_nodes_to_hostsfile() {
    local entry=""
    while read IP FQDN HOST SUBNET TYPE SCH; do
        entry="${entry}${IP} ${FQDN} ${HOST}\n"
    done < <(jobico::dao::cluster::nodes)
    sed -i "/${END_HOSTS_FILE}/d" "$(work_dir)/hosts"
    echo -e "${entry}${END_HOSTS_FILE}" >>"$(work_dir)/hosts"
}
