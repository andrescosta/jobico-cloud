jobico::tls::ca_conf_file(){
    echo "$(work_dir)/ca.conf"
}
jobico::tls::gen_ca_conf() {
    cp ${EXTRAS_DIR}/tls/ca.conf.tmpl $(jobico::tls::ca_conf_file)
    local workers=($(jobico::dao::cpl::get worker))
    local new_ca=""
    while read IP FQDN HOST SUBNET TYPE SCH; do
        node_req=$(sed "s/{NAME}/${HOST}/g; s/{IP}/${IP}/g;" "${EXTRAS_DIR}/tls/ca.conf.nodes.tmpl")
        new_ca="${new_ca}\n\n${node_req}"
    done < <(jobico::dao::cluster::members)
    echo -e "${new_ca}" >>$(jobico::tls::ca_conf_file)

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
    sed -i "s/{ETCD_IPS}/$ips/g" "$(jobico::tls::ca_conf_file)"
    sed -i "s/{ETCD_DNS}/$dns/g" "$(jobico::tls::ca_conf_file)"
    sed -i "s/{API_SERVER_IPS}/$ips/g" "$(jobico::tls::ca_conf_file)"

    local vip=$(jobico::dao::cluster::lb 1)
    local vipname=$(jobico::dao::cluster::lb 2)
    sed -i "s/{LB_IP}/${vip}/g" "$(jobico::tls::ca_conf_file)"
    sed -i "s/{LB_DNS}/${vipname}/g" "$(jobico::tls::ca_conf_file)"
}
jobico::tls::add_nodes_to_ca_conf() {
    local workers=($(jobico::dao::cpl::get worker))
    local new_ca=""
    while read IP FQDN HOST SUBNET TYPE SCH; do
        node_req=$(sed "s/{NAME}/${HOST}/g; s/{IP}/${IP}/g;" "${EXTRAS_DIR}/tls/ca.conf.nodes.tmpl")
        new_ca="${new_ca}\n\n${node_req}"
    done < <(jobico::dao::cluster::nodes)
    echo -e "${new_ca}" >>$(jobico::tls::ca_conf_file)
}
jobico::tls::gen_ca() {
    openssl genrsa -out $(work_dir)/ca.key 4096
    openssl req -x509 -new -sha512 -noenc \
        -key $(work_dir)/ca.key -days 3653 \
        -config $(jobico::tls::ca_conf_file) \
        -out $(work_dir)/ca.crt
}
jobico::tls::gen_certs() {
    local comps=($(jobico::dao::cpl::get gencert 3))
    for component in ${comps[@]}; do
        openssl genrsa -out "$(work_dir)/${component}.key" 4096

        openssl req -new -key "$(work_dir)/${component}.key" -sha256 \
            -config $(jobico::tls::ca_conf_file) -section ${component} \
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
    local namespace="default"
    if [[ $# > 0 ]]; then
        namespace=$1
    fi
    kubectl create secret tls jobico.org-secret --cert=$(work_dir)/jobico.org.crt --key=$(work_dir)/jobico.org.key --namespace=$namespace
}
