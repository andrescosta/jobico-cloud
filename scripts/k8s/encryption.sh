
kube::encryption::gen_key(){
    cat > ${WORK_DIR}/encryption-config.yaml \
<<EOF
  kind: EncryptionConfig
  apiVersion: v1
  resources:
    - resources:
        - secrets
      providers:
        - aescbc:
            keys:
              - name: key1
                secret: ${ENCRYPTION_KEY}
        - identity: {}
EOF
}

kube::encryption::deploy(){
    local servers=($(kube::dao::cluster::get server 1))
    for host in ${servers[@]}; do
        scp ${WORK_DIR}/encryption-config.yaml root@$host:~/
    done
}