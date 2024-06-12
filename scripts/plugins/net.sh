jobico::net::init(){    
    jobico::dao::cluster::machines  | while read IP FQDN HOST SUBNET TYPE SCH; do
            SSH root@${IP} \
<<EOF 
    chmod 600 /etc/netplan/50-cloud-init.yaml
EOF
    done
}
jobico::net::add_routes(){
    jobico::dao::cluster::all_nodes | while read IP1 FQDN1 HOST1 SUBNET1 TYPE1 SCH1; do
       jobico::dao::cluster::all_nodes | while read IP2 FQDN2 HOST2 SUBNET2 TYPE2 SCH2; do
        if [ $IP1 != $IP2 ]; then
            SSH root@${IP1} \
<<EOF 
    sed -i "/set-name: enp1s0/a\            routes:\n              - to: ${SUBNET2}\n                via: ${IP2}" /etc/netplan/50-cloud-init.yaml 
EOF
        fi
       done
       SSH root@${IP1} \
<<EOF 
    netplan apply
EOF
    done
}
jobico::net::add_routes_to_added_node(){
    jobico::dao::cluster::curr_nodes | while read IP1 FQDN1 HOST1 SUBNET1 TYPE1 SCH1; do
        jobico::dao::cluster::nodes | while read IP2 FQDN2 HOST2 SUBNET2 TYPE2 SCH2; do
          if [ $IP1 != $IP2 ]; then
            SSH root@${IP1} \
<<EOF 
    sed -i "/set-name: enp1s0/a\            routes:\n              - to: ${SUBNET2}\n                via: ${IP2}" /etc/netplan/50-cloud-init.yaml 
EOF
          fi
        done
        SSH root@${IP1} \
<<EOF 
    netplan apply
EOF
    done
    jobico::dao::cluster::nodes | while read IP1 FQDN1 HOST1 SUBNET1 TYPE1 SCH1; do
        jobico::dao::cluster::curr_nodes | while read IP2 FQDN2 HOST2 SUBNET2 TYPE2 SCH2; do
            SSH root@${IP1} \
<<EOF 
    sed -i "/set-name: enp1s0/a\            routes:\n              - to: ${SUBNET2}\n                via: ${IP2}" /etc/netplan/50-cloud-init.yaml 
EOF
        done
        SSH root@${IP1} \
<<EOF 
    netplan apply
EOF
    done
}
