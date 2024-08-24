jobico::vm::create() {
    jobico::dao::cluster::machines | while read IP FQDN HOST SUBNET TYPE SCH; do
        make -f $SCRIPTS/Makefile.vm new-vm-${TYPE} VM_IP=${IP} VM_NAME=${HOST} -C ${DIR}
    done
}

jobico::vm::destroy() {
    jobico::dao::cluster::machines | while read IP FQDN HOST SUBNET TYPE SCH; do
        make -f $SCRIPTS/Makefile.vm destroy-vm VM_IP=${IP} VM_NAME=${HOST} -C ${DIR}
    done
}
jobico::vm::cmd() {
    if [ $(jobico::dao::cluster::is_locked) == true ]; then
        jobico::dao::cluster::unlock
        jobico::dao::cluster::machines | while read IP FQDN HOST SUBNET TYPE SCH; do
            make -f $SCRIPTS/Makefile.vm cmd-vm CMD=$1 VM_NAME=${HOST} -C ${DIR}
        done
        jobico::dao::cluster::lock
        echo true
    else
        echo false
    fi
}
jobico::vm::list() {
    make -f $SCRIPTS/Makefile.vm list -C ${DIR}
}
jobico::vm::clear_dhcp() {
    jobico::dao::cluster::machines | while read IP FQDN HOST SUBNET TYPE SCH; do
        eval "$(virsh -q net-dhcp-leases default | awk -v host="${HOST}" '{ if ($6 == host) { split($5, ip, "/"); print "dhcp_release virbr0",ip[1],$3 }}')"
    done
}
jobico::vm::wait_until_all_up() {
    local port=22
    local timeout=120
    local delay=5
    local elapsed_time=0

    echo "Waiting for servers to start..."

    jobico::dao::cluster::machines | while read IP FQDN HOST SUBNET TYPE SCH; do
        echo "Waiting for $IP to start listening on port $port..."
        start_time=$(date +%s)
        while ! nc -z "$IP" "$port" >/dev/null 2>&1; do
            current_time=$(date +%s)
            elapsed_time=$((current_time - start_time))
            if [ "$elapsed_time" -ge "$timeout" ]; then
                echo "Timeout exceeded for $IP"
                break
            fi

            sleep "$delay"
        done

        if [ "$elapsed_time" -lt "$timeout" ]; then
            echo "$IP is now listening on port $port"
        fi
    done
}
