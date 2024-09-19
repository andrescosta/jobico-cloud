readonly DIR=$2
. constants.sh
. ${SCRIPTS}/support/dirs.sh
load_dirs
. ${SCRIPTS}/support/utils.sh
. ${SCRIPTS}/dao/cpl.sh

install(){
    local domain=$(jobico::dao::cpl::get_domain)
    if [[ $1 != "" && -d $1 ]]; then
        temp_dir=$1
    else
        temp_dir=$(mktemp -d)
    fi
    if [[ ! -d "$1/jobicok8s" ]]; then
        git clone git@github.com:/andrescosta/jobicok8s.git $temp_dir/jobicok8s
    fi
    cd $temp_dir/jobicok8s
    echo "Installing from: $(pwd)"
    docker login --username jobico --password jobico123 https://reg.$domain
    make deploy-all
}

install "$@"