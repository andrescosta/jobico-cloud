readonly DIR=$2
. constants.sh
. ${SCRIPTS}/support/dirs.sh
load_dirs
. ${SCRIPTS}/dao/cpl.sh
. ${SCRIPTS}/support/utils.sh
install(){
    local domain=$(jobico::dao::cpl::get_domain)
    local pgadmin=$(prepare_file "$1/pgadmin.yaml.tmpl" "pgadmin" "{DOMAIN}=$domain")
    kubectl apply -f $pgadmin
    if [ $? == 1 ]; then
        echo "Generated file $pgadmin"
    fi
}
install "$@"