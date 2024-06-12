jobico::tls::gen_ca_conf() {
    cp ${EXTRAS_DIR}/tls/ca.conf.tmpl ${CA_CONF}
    local workers=($(jobico::dao::cpl::get worker))
    local new_ca=""
    while read IP FQDN HOST SUBNET TYPE SCH; do
        node_req=$(sed "s/{NAME}/${HOST}/g; s/{IP}/${IP}/g;" "${EXTRAS_DIR}/tls/ca.conf.nodes.tmpl")
        new_ca="${new_ca}\n\n${node_req}"
    done < <(jobico::dao::cluster::members)
    echo -e "${new_ca}" >>${CA_CONF}

    local ips=""
    local dns=""
    local i=1
    while read IP FQDN HOST SUBNET TYPE SCH; do
        if [ "${TYPE}" == "server" ]; then
            ips="${ips}IP.${i}=${IP}\n"
            dns="${dns}DNS.${i}=${FQDN}\n"
            ((i = i + 1))
        fi
    done <${JOBICO_CLUSTER_TBL}
    sed -i "s/{ETCD_IPS}/$ips/g" "${CA_CONF}"
    sed -i "s/{ETCD_DNS}/$dns/g" "${CA_CONF}"
    sed -i "s/{API_SERVER_IPS}/$ips/g" "${CA_CONF}"

    local vip=$(jobico::dao::cluster::lb 1)
    local vipname=$(jobico::dao::cluster::lb 2)
    sed -i "s/{LB_IP}/${vip}/g" "${CA_CONF}"
    sed -i "s/{LB_DNS}/${vipname}/g" "${CA_CONF}"
}
jobico::tls::add_nodes_to_ca_conf() {
    local workers=($(jobico::dao::cpl::get worker))
    local new_ca=""
    while read IP FQDN HOST SUBNET TYPE SCH; do
        node_req=$(sed "s/{NAME}/${HOST}/g; s/{IP}/${IP}/g;" "${EXTRAS_DIR}/tls/ca.conf.nodes.tmpl")
        new_ca="${new_ca}\n\n${node_req}"
    done < <(jobico::dao::cluster::nodes)
    echo -e "${new_ca}" >>${CA_CONF}
}
jobico::tls::gen_ca() {
    openssl genrsa -out ${WORK_DIR}/ca.key 4096
    openssl req -x509 -new -sha512 -noenc \
        -key ${WORK_DIR}/ca.key -days 3653 \
        -config ${CA_CONF} \
        -out ${WORK_DIR}/ca.crt
}
jobico::tls::gen_certs() {
    local comps=($(jobico::dao::cpl::get gencert 3))
    for component in ${comps[@]}; do
        openssl genrsa -out "${WORK_DIR}/${component}.key" 4096

        openssl req -new -key "${WORK_DIR}/${component}.key" -sha256 \
            -config ${CA_CONF} -section ${component} \
            -out "${WORK_DIR}/${component}.csr"

        openssl x509 -req -days 3653 -in "${WORK_DIR}/${component}.csr" \
            -copy_extensions copyall \
            -sha256 -CA "${WORK_DIR}/ca.crt" \
            -CAkey "${WORK_DIR}/ca.key" \
            -CAcreateserial \
            -out "${WORK_DIR}/${component}.crt"
    done
}
jobico::tls::deploy_to_nodes() {
    while read IP FQDN HOST SUBNET TYPE SCH; do

        SSH -n root@$HOST mkdir -p /var/lib/kubelet

        SCP ${WORK_DIR}/ca.crt root@$HOST:/var/lib/kubelet/

        SCP ${WORK_DIR}/$HOST.crt root@$HOST:/var/lib/kubelet/kubelet.crt

        SCP ${WORK_DIR}/$HOST.key root@$HOST:/var/lib/kubelet/kubelet.key
    done < <(jobico::dao::cluster::members)
}
jobico::tls::deploy_to_server() {
    local servers=($(jobico::dao::cluster::get server 1))
    for host in ${servers[@]}; do
        SCP \
            ${WORK_DIR}/ca.key ${WORK_DIR}/ca.crt \
            ${WORK_DIR}/kube-api-server.key ${WORK_DIR}/kube-api-server.crt \
            ${WORK_DIR}/service-accounts.key ${WORK_DIR}/service-accounts.crt \
            ${WORK_DIR}/etcd-server.key ${WORK_DIR}/etcd-server.crt \
            root@$host:~/
    done
}
