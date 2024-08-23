kubectl create cm build-map --from-file=$1/build.sh --dry-run=client -oyaml | kubectl apply --force -f -


