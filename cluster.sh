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

. ${SCRIPTS}/support/exception.sh
set_trap_err
    #trap 'throw "error ($?) executing command"' ERR
. ${SCRIPTS}/api.sh 
. ${SCRIPTS}/support/utils.sh 
. ${SCRIPTS}/kvm.sh 

destroy(){
    ask=true
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -y )
                shift
                ask=false
                response="yes"
                ;;
            --dry_run )
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
  if [ "$ask" = true ]; then 
    read -r -p "Are you sure to destroy the cluster? [Y/n] " response
    response=${response,,}
  fi
  if [[ $response == "yes" || $response == "y" ]]; then
    echo "Destroying the cluster ... "
    kube::destroy_cluster
    rm -rf work
    exit 0
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

new() {
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
            --dry_run )
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
    if [[ $cpl > 1 ]]; then  
        echo "The K8s Cluster is being created with $nodes node(s), $cpl control plane node(s) and ${lb} load balancer(s) ..."
    else
        echo "The K8s Cluster is being created with $nodes node(s)."
    fi
    DRY_RUN echo ">> Dryn run << "
  
    kube::cluster $nodes $cpl $lb 
  
    NOT_DRY_RUN echo "The K8s Cluster was created."
}
add(){
    local force=false
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
            --dry_run )
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
display_help() {
    echo "Usage: "
    echo "       $0 <command> [arguments]"
    echo "Commands:"
    echo "          help"
    echo "          new"
    echo "          add"
    echo "          destroy"
    echo "          local"
    echo "          kvm"
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
    local)
      display_help_for_local
      ;;
    kvm)
      display_help_for_kvm
      ;;
    *)
      echo "Invalid command: $1" >&2
      display_help 
      exit 1
      ;;
  esac
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
  echo "     --dry_run"
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
  echo "     --dry_run"
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
    local)
      shift
      clocal "$@"
      ;;
    kvm)
      kvm      
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