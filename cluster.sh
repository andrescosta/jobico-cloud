#!/bin/bash

set -eu
set -o pipefail
set -o errtrace

PS4='LINENO:'
DEFAULT_NODES=2
DEFAULT_NODES_ADD=1
DEFAULT_CPL=1
DEFAULT_LB=2
DIR=$(dirname "$0")
SCRIPTS="${DIR}/scripts"
ADDONS_DIR="${DIR}/addons"

. ${SCRIPTS}/support/exception.sh
set_trap_err
. ${SCRIPTS}/api.sh 
. ${SCRIPTS}/support/utils.sh 
. ${SCRIPTS}/support/ssh.sh 
. ${SCRIPTS}/kvm.sh 

new() {
    local exec_dir="" cpl lb nodes addons_dir="" skip_addons=false
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --nodes )
                shift
                if [ -n "$1" ] && [[ "$1" =~ ^[0-9]+$ ]]; then
                    nodes=$1
                else
                    echo "Invalid value for --nodes. Please provide a numeric value." 
                    display_help
                    exit 1
                fi
                ;;
            --cpl )
                shift
                if [ -n "$1" ] && [[ "$1" =~ ^[0-9]+$ ]]; then
                    cpl=$1
                else
                    echo "Invalid value for --cpl. Please provide a numeric value." >&2
                    display_help
                    exit 1
                fi
                ;;
            --lb )
                shift
                if [ -n "$1" ] && [[ "$1" =~ ^[0-9]+$ ]]; then
                    lb=$1
                else
                    echo "Invalid value for --lb. Please provide a numeric value." >&2
                    display_help
                    exit 1
                fi
                ;;
            --dry-run )
                DRY_RUNON
                DEBUGON
                ;;
            --no-addons )
                skip_addons=true
                ;;
            --exec-dir )
                shift
                if [ -n "${1-}" ]; then
                    exec_dir="$1"
                    if [ ! -d "$exec_dir" ]; then
                        echo "The directory ${exec_dir} does not exist." >&2
                        exit 1
                    fi
                else
                    echo "With --exec-dir a directory name must be passed."
                    display_help
                    exit 1
                fi
                ;;
            --addons )
                if [ -n "${1-}" ]; then
                    addons_dir="$1"
                    if [ ! -d "$addons_dir" ]; then
                        echo "The directory ${addons_dir} does not exist." >&2
                        exit 1
                    fi
                else
                    echo "With --addons a directory name must be passed."
                    display_help
                    exit 1
                fi
                ;;
            --debug )
                shift
                if [ "$1" != "s" ] && [ "$1" != "d" ]; then
                    echo "Invalid value for --debug.Plase provide s or d" >&2
                    display_help
                    exit 1
                fi
                if [ "$1" == "d" ]; then
                    set -x
                 fi
                DEBUGON
                ;;
            -* )
                echo "Unrecognized or incomplete option: $1" >&2
                display_help
                exit 1
                ;;
            * )
                echo "Invalid argument: $1" >&2
                display_help
                exit 1
                ;;
        esac
        shift
    done
    nodes=${nodes:-$DEFAULT_NODES}
    cpl=${cpl:-$DEFAULT_CPL}
    lb=${lb:-$DEFAULT_LB}
    addons_dir=${addons_dir:-$ADDONS_DIR}
    if [[ $cpl > 1 ]]; then  
        echo "The K8s Cluster is being created with $nodes node(s), $cpl control plane node(s) and ${lb} load balancer(s) ..."
    else
        echo "The K8s Cluster is being created with $nodes node(s)."
    fi
    DRY_RUN echo ">> Dryn run << "
    kube::cluster $nodes $cpl $lb 
    addons $skip_addons $addons_dir
    NOT_DRY_RUN exec_dir $exec_dir

    NOT_DRY_RUN echo "The K8s Cluster was created."
}
addons(){
    local skip_addons=$1
    local base_dir=$2
    if [ $skip_addons == false ]; then
        if [ -d $base_dir ]; then
            kube::addons $base_dir
        else
            echo "No addons available to install at $base_dir"
        fi
    fi
}
exec_dir(){
    if [[ $# > 0 ]]; then
        local exec_dir=$1
        if [ "$exec_dir" != "" ]; then
            if [ -d $exec_dir ]; then
                DRY_RUN echo "Warning: --dry-run option was provided. The scripts in $exec_dir are not executed."
                NOT_DRY_RUN exec $exec_dir
            else
                echo "Warning: $exec_dir does not exist"
            fi
        fi 
    fi
}
exec(){
    echo "- Executing $1"
    local dir=$1
    local files=$(ls -p -v $1 | grep -v '/$')
    local err=0
    for script in $files; do
        echo ">Executing $script ..."
        local output=$(bash "$dir/$script" 2>&1) || err=$?
        echo "> Result of $script:"
        echo ">> $output"
        if [[ $err != 0 ]]; then
            echo "> Warning $script returned an error $err"
            break
        fi
    done
    echo "- Finished $1"
}
add(){
    local force=false nodes
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --nodes )
                shift
                if [ -n "$1" ] && [[ "$1" =~ ^[0-9]+$ ]]; then
                    nodes=$1
                else
                    echo "Invalid value for --nodes. Please provide a numeric value." >&2
                    display_help
                    exit 1
                fi
                ;;
            --dry-run )
                DRY_RUNON
                DEBUGON
                ;;
            --debug )
                shift
                if [ "$1" != "s" ] && [ "$1" != "d" ]; then
                    echo "Invalid value for --debug.Plase provide s or d" >&2
                    display_help
                    exit 1
                fi
                if [ "$1" == "d" ]; then
                    set -x
                fi
                DEBUGON
                ;;
            --force )
                force=true
                ;;
            -* )
                echo "Unrecognized or incomplete option: $1" >&2
                display_help
                exit 1
                ;;
            * )
                echo "Invalid argument: $1" >&2
                display_help
                exit 1
                ;;
        esac
        shift
    done
    nodes=${nodes:-$DEFAULT_NODES_ADD}
  
    echo "$nodes node(s) are being added ...  "
  
    if [[ $(kube::add_was_executed) == false && $(kube::dao::cluster::is_locked) == true ]]; then
        kube::unlock_cluster
    else
        if [[ $force == true ]]; then
            kuve::remove_add_commands
            kube::unlock_cluster
        fi
    fi
    kube::add $nodes  
  
    echo "The node(s) were added."
}
destroy(){
    local ask=true response
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -y )
                shift
                ask=false
                response="yes"
                ;;
            --dry-run )
                shift
                DRY_RUNON
                DEBUGON
                ;;
            -* )
                echo "Unrecognized or incomplete option: $1" >&2
                display_help
                exit 1
                ;;
            * )
                echo "Invalid argument: $1" >&2
                display_help
                exit 1
                ;;
        esac
        shift
    done
    NOT_DRY_RUN do_destroy
    DRY_RUN kube::destroy_cluster
}
do_destroy(){
  local response
  if [ "$ask" = true ]; then 
    read -r -p "Are you sure to destroy the cluster? [Y/n] " response
    response=${response,,}
  fi
  if [[ $response == "yes" || $response == "y" ]]; then
    echo "Destroying the cluster ... "
    kube::destroy_cluster
    rm -rf work
  else
    echo "Command execution cancelled."
  fi
}
clocal(){
    kube::gen_local_env
}
kvm(){
  install_kvm
}
cfg(){
    local salt_def="SALT12345678"
    local auth_key_def=$(ls ~/.ssh/*.pub 2>/dev/null | head -n 1)
    read -p "Salt for Debian               :" -e -i "${salt_def}" salt_deb
    read -p "Password for Debian           :" -s pass_deb
    echo
    local epass_deb=$(escape $(mkpasswd --method=SHA-512 --salt=${salt_deb} --rounds=4096 ${pass_deb}))
    read -p "Authorized key file for debian:" -e -i "$auth_key_def" auth_key_deb
    local key_deb="- $(escape "$(<$auth_key_deb)")"
    read -p "Salt for root                 :" -e -i "$salt_def" salt_root
    read -p "Password for root             :" -s pass_root
    echo
    local epass_root=$(escape $(mkpasswd --method=SHA-512 --salt=${salt_root} --rounds=4096 ${pass_root}))
    local auth_key_root=$auth_key_deb
    read -p "Authorized key file for root  :" -e -i "$auth_key_def" auth_key_root
    local key_root="- $(escape "$(<"$auth_key_root")")"
    cp extras/cfg/cloud-init-lb.cfg.tmpl extras/cfg/cloud-init-lb.cfg 
    cp extras/cfg/cloud-init-server.cfg.tmpl extras/cfg/cloud-init-server.cfg 
    cp extras/cfg/cloud-init-node.cfg.tmpl extras/cfg/cloud-init-node.cfg 
    sed -i "s/{PWD_DEBIAN}/${epass_deb}/g" extras/cfg/cloud-init-lb.cfg
    sed -i "s/{PWD_ROOT}/${epass_root}/g" extras/cfg/cloud-init-lb.cfg
    sed -i "s/{PWD_DEBIAN}/${epass_deb}/g" extras/cfg/cloud-init-node.cfg
    sed -i "s/{PWD_ROOT}/${epass_root}/g" extras/cfg/cloud-init-node.cfg
    sed -i "s/{PWD_DEBIAN}/${epass_deb}/g" extras/cfg/cloud-init-server.cfg
    sed -i "s/{PWD_ROOT}/${epass_root}/g" extras/cfg/cloud-init-server.cfg
    sed -i "s/{DEBIAN_KEYS}/${key_deb}/g" extras/cfg/cloud-init-server.cfg
    sed -i "s/{ROOT_KEYS}/${key_root}/g" extras/cfg/cloud-init-node.cfg
    sed -i "s/{DEBIAN_KEYS}/${key_deb}/g" extras/cfg/cloud-init-node.cfg
    sed -i "s/{ROOT_KEYS}/${key_root}/g" extras/cfg/cloud-init-lb.cfg
    sed -i "s/{DEBIAN_KEYS}/${key_deb}/g" extras/cfg/cloud-init-lb.cfg
    sed -i "s/{ROOT_KEYS}/${key_root}/g" extras/cfg/cloud-init-server.cfg
}
display_help() {
    echo "Usage: "
    echo "       $0 <command> [arguments]"
    echo "Commands:"
    echo "          help"
    echo "          new"
    echo "          add"
    echo "          destroy"
    echo "          addons"
    echo "          local"
    echo "          kvm"
    echo "          cfg"
    echo ""
    echo "Additional help: $0 help <command>"
}

display_help_command(){
  case $1 in 
    new)
      display_help_for_new
      ;;
    add)
      display_help_for_add
      ;;
    destroy)
      display_help_for_destroy
      ;;
    addons)
      display_help_for_addons
      ;;
    local)
      display_help_for_local
      ;;
    kvm)
      display_help_for_kvm
      ;;
    cfg)
      display_help_for_cfg
      ;;
    *)
      echo "Invalid command: $1" >&2
      display_help 
      exit 1
      ;;
  esac
} 
display_help_for_addons(){
  echo "Usage: $0 addons [arguments]"
  echo "Install the addons from the folder ./addons or the one specified by --dir."
}
display_help_for_new(){
  echo "Usage: $0 new [arguments]"
  echo "Create the VMs and deploys Kubernetes cluster into them."
  echo "The arguments that define how the cluster will be created:"
  echo "     --nodes n"
  echo "            Specify the number of worker nodes to be created. The default value is 2. "
  echo "     --cpl n"
  echo "            Specify the number of control planed nodes to be created. The default value is 1. "
  echo "     --lb n"
  echo "            Specify the number of load balancers to be created in case --cpl is greater than 1. The default value is 2. "
  echo "     --addons dir_name"
  echo "            Specify a different directory name for the addons. Default: $ADDONS_DIR"
  echo "     --no-addons"
  echo "            Skip the instalation of addons"
  echo "     --exec-dir dir_name"
  echo "            After the cluster is created successfully, the scripts in this directory will be executed in alphabetical order." 
  echo "     --dry-run"
  echo "            Create the dabases, kubeconfigs, and certificates but does not create the actual cluster. This option is useful for debugging."
  echo "     --debug [ s | d ]"
  echo "            Enable the debug mode."
  echo "       s: displays basic information."
  echo "       d: display advanced information."
}
display_help_for_add(){
  echo "Usage: $0 add [arguments]"
  echo "Add new nodes to the current Kubernetes cluster."
  echo "The arguments that define how the cluster will be updated:"
  echo "     --nodes n"
  echo "            Specify the number of worker nodes to be added. The default value is 1. "
  echo "     --dry-run"
  echo "            Update the dabases, kubeconfigs, and certificates but does not create the actual cluster. This option is useful for debugging."
  echo "     --force"
  echo "            If new nodes were added previously, this parameter force the execution of this command."
  echo "     --debug [ s | d ]"
  echo "            Enable the debug mode."
  echo "       s: displays basic information."
  echo "       d: display advanced information."
}
display_help_for_destroy(){
  echo "Usage: $0 destroy"
  echo "Destroy the Kubernetes cluster and the VMs"
}
display_help_for_cfg(){
  echo "Usage: $0 cfg"
  echo "Create the cloud init cfg files."
}
display_help_for_local(){
  echo "Usage: $0 local"
  echo "Prepares the local enviroment. It creates the kubeconfig and installs kubectl."
}
display_help_for_kvm(){
  echo "Usage: $0 kvm"
  echo "Install kvm and its dependencies locally."
}
main(){
  DEBUGOFF
  DRY_RUNOFF
  if [ $# -eq 0 ]; then
      display_help $0
      exit 0
  fi
  case $1 in 
    new)
      shift
      new "$@"
      ;;
    add)
      shift
      add "$@"
      ;;
    destroy)
      shift
      destroy "$@"
      ;;
    addons)
      addons false $ADDONS_DIR
      ;;
    local)
      shift
      clocal "$@"
      ;;
    kvm)
      shift 
      kvm "$@"    
      ;;
    cfg)
      shift 
      cfg "$@"
      ;;
    help)
      if [ $# -gt 1 ]; then
        display_help_command $2
      else
        display_help $0
      fi
      ;;
    *)
      echo "Invalid command: $1" >&2
      display_help 
      exit 1
      ;;
  esac
}
main "$@"
