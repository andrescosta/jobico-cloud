jobico::haproxy::gen_cfg(){
    local vip=$(jobico::dao::cluster::lb 1)
    cp ${EXTRAS_DIR}/configs/haproxy.cfg.tmpl $(work_dir)/haproxy.cfg
    local servers=""
    while read IP FQDN HOST SUBNET TYPE SCH; do
        if [ "${TYPE}" == "server" ]; then
            servers="${servers}    server ${HOST} ${IP}:6443 check fall 3 rise 2\n"
        fi
    done < $(work_dir)/cluster.txt
    sed -i "s/{LB_IPS}/${servers}/g" "$(work_dir)/haproxy.cfg" 
    servers=($(jobico::dao::cluster::get lb 1))
    for ip1 in ${servers[@]}; do
        file="$(work_dir)/keepalived${ip1}.conf"
        cp  ${EXTRAS_DIR}/configs/keepalived.conf.tmpl ${file} 
        sed -i "s/{IP}/${ip1}/g" "${file}" 
        sed -i "s/{VIP}/${vip}/g" "${file}" 
        ips=""
        for ip2 in ${servers[*]}; do
            if [ "${ip1}" != "${ip2}" ]; then
                ips="${ips}    ${ip2}\n"
            fi
        done
        sed -i "s/{LB_IPS}/${ips}/g" "${file}" 
    done
}

jobico::haproxy::deploy(){
    local servers=($(jobico::dao::cluster::get lb 1))
    for ip in ${servers[@]}; do
        SCP $(work_dir)/haproxy.cfg root@${ip}:~/ 
        SCP $(work_dir)/keepalived${ip}.conf root@${ip}:~/keepalived.conf
        SSH root@$ip << 'EOF'
cloud-init status --wait > /dev/null
cat ~/haproxy.cfg >> /etc/haproxy/haproxy.cfg
cp ~/keepalived.conf /etc/keepalived
systemctl reload haproxy 
systemctl restart keepalived
EOF
    done
}

