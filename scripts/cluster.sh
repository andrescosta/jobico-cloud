#!/bin/bash
PS4='LINENO:'
DEFAULT_NODES=2

. $(dirname "$0")/lib.sh 
. $(dirname "$0")/kvm.sh 

function destroy(){
    ask=true
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -y )
                shift
                ask=false
                response="yes"
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
  if [ "$ask" = true ]; then 
    read -r -p "Are you sure to destroy the cluster? [Y/n] " response
    response=${response,,}
  fi
  if [[ $response == "yes" || $response == "y" ]]; then
    echo "Destroying the cluster ... "
    jobico::kube::destroy_cluster
    rm -rf work
  else
    echo "Command execution cancelled."
  fi
}
function clocal(){
  jobico::kube::cluster::set_local
}
function kvm(){
  install_kvm
}
show_databases_content(){
    jobico::kube::print_databases_info
}

new() {
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
                _DEBUG="on"
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
  echo " The K8s Cluster is being created with $nodes node(s) ..."
  jobico::kube::cluster $nodes
  echo " The K8s Cluster was created."
}

display_help() {
    echo "Usage: "
    echo "       $0 <command> [arguments]"
    echo "Commands:"
    echo "          new"
    echo "          destroy"
    echo "          local"
    echo "          kvm"
    echo "          db"
    echo ""
    echo "Additional help: $0 help <command>"
}

display_help_command(){
  case $1 in 
    new)
      display_help_for_new
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
    db)
      display_help_for_db
      ;;
    *)
      echo "Invalid command: $1" >&2
      display_help 
      exit 1
      ;;
  esac
} 

display_help_for_new(){
  echo "Usage: $0 new [--nodes n] [--debug s|d]"
  echo "Create the VMs and deploys Kubernetes cluster into them."
  echo "The arguments that define how the cluster will be created:"
  echo "     --nodes n"
  echo "            Specify the number of worker nodes to be created. The default value is 2. "
  echo "     --debug [ s | d ]"
  echo "            Enable the debug mode."
  echo "       s: displays basic information."
  echo "       d: display advanced information."
}
display_help_for_db(){
  echo "Usage: $0 db"
  echo "Display the content of the internal databases."
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
exec_command(){
  if [ $# -eq 0 ]; then
      display_help $0
      exit 0
  fi
  case $1 in 
    new)
      shift
      new "$@"
      ;;
    destroy)
      shift
      destroy "$@"
      ;;
    local)
      clocal
      ;;
    kvm)
      kvm      
      ;;
    db)
      show_databases_content
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

exec_command "$@"
