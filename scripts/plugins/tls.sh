ca_conf_file(){
    echo "$(work_dir)/ca.conf"
}
jobico::tls::gen_ca_conf() {
    cp ${EXTRAS_DIR}/tls/ca.conf.tmpl $(ca_conf_file)
    local workers=($(jobico::dao::cpl::get worker))
    local new_ca=""
    while read IP FQDN HOST SUBNET TYPE SCH; do
        node_req=$(sed "s/{NAME}/${HOST}/g; s/{IP}/${IP}/g;" "${EXTRAS_DIR}/tls/ca.conf.nodes.tmpl")
        new_ca="${new_ca}\n\n${node_req}"
    done < <(jobico::dao::cluster::members)
    echo -e "${new_ca}" >>$(ca_conf_file)

    local ips=""
    local dns=""
    local i=1
    while read IP FQDN HOST SUBNET TYPE SCH; do
        if [ "${TYPE}" == "server" ]; then
            ips="${ips}IP.${i}=${IP}\n"
            dns="${dns}DNS.${i}=${FQDN}\n"
            ((i = i + 1))
        fi
    done <$(machines_db)
    sed -i "s/{ETCD_IPS}/$ips/g" "$(ca_conf_file)"
    sed -i "s/{ETCD_DNS}/$dns/g" "$(ca_conf_file)"
    sed -i "s/{API_SERVER_IPS}/$ips/g" "$(ca_conf_file)"

    local vip=$(jobico::dao::cluster::lb 1)
    local vipname=$(jobico::dao::cluster::lb 2)
    sed -i "s/{LB_IP}/${vip}/g" "$(ca_conf_file)"
    sed -i "s/{LB_DNS}/${vipname}/g" "$(ca_conf_file)"

    local domain=$(jobico::dao::cpl::get_domain)
    sed -i "s/{DOMAIN}/$domain/g" "$(ca_conf_file)"
}
jobico::tls::add_nodes_to_ca_conf() {
    local workers=($(jobico::dao::cpl::get worker))
    local new_ca=""
    while read IP FQDN HOST SUBNET TYPE SCH; do
        node_req=$(sed "s/{NAME}/${HOST}/g; s/{IP}/${IP}/g;" "${EXTRAS_DIR}/tls/ca.conf.nodes.tmpl")
        new_ca="${new_ca}\n\n${node_req}"
    done < <(jobico::dao::cluster::nodes)
    echo -e "${new_ca}" >>$(ca_conf_file)
}
jobico::tls::gen_ca() {
    openssl genrsa -out $(work_dir)/ca.key 4096
    openssl req -x509 -new -sha512 -noenc \
        -key $(work_dir)/ca.key -days 3653 \
        -config $(ca_conf_file) \
        -out $(work_dir)/ca.crt
}
jobico::tls::gen_certs() {
    local comps=($(jobico::dao::cpl::get gencert 3))
    for component in ${comps[@]}; do
        openssl genrsa -out "$(work_dir)/${component}.key" 4096

        openssl req -new -key "$(work_dir)/${component}.key" -sha256 \
            -config $(ca_conf_file) -section ${component} \
            -out "$(work_dir)/${component}.csr"

        openssl x509 -req -days 3653 -in "$(work_dir)/${component}.csr" \
            -copy_extensions copyall \
            -sha256 -CA "$(work_dir)/ca.crt" \
            -CAkey "$(work_dir)/ca.key" \
            -CAcreateserial \
            -out "$(work_dir)/${component}.crt"
    done
}
jobico::tls::deploy_to_nodes() {
    while read IP FQDN HOST SUBNET TYPE SCH; do

        SSH -n root@$HOST mkdir -p /var/lib/kubelet

        SCP $(work_dir)/ca.crt root@$HOST:/var/lib/kubelet/

        SCP $(work_dir)/$HOST.crt root@$HOST:/var/lib/kubelet/kubelet.crt

        SCP $(work_dir)/$HOST.key root@$HOST:/var/lib/kubelet/kubelet.key
    done < <(jobico::dao::cluster::members)
}
jobico::tls::deploy_to_server() {
    local servers=($(jobico::dao::cluster::get server 1))
    for host in ${servers[@]}; do
        SCP \
            $(work_dir)/ca.key $(work_dir)/ca.crt \
            $(work_dir)/kube-api-server.key $(work_dir)/kube-api-server.crt \
            $(work_dir)/service-accounts.key $(work_dir)/service-accounts.crt \
            $(work_dir)/etcd-server.key $(work_dir)/etcd-server.crt \
            root@$host:~/
    done
}
jobico::tls::create_tls_secret(){
    local namespace=$1
    local domain=$(jobico::dao::cpl::get_domain)
    kubectl create secret tls "$domain-secret" --cert="$(work_dir)/$domain.crt" --key="$(work_dir)/$domain.key" --namespace=$namespace
}
