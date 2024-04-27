#!/bin/bash

DEFAULT_NODES=2

. $(dirname "$0")/lib.sh 
. $(dirname "$0")/kvm.sh 

function destroy(){
  read -r -p "Are you sure to destroy the cluster? [Y/n] " response
  response=${response,,}
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
cluster() {
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

function display_help {
    echo "Usage: "
    echo "       $0 <command> [arguments]"
    echo "Commands:"
    echo "          cluster"
    echo "          destroy"
    echo "          local"
    echo "          kvm"
    echo ""
    echo "Additional help: $0 help <command>"
    exit 1
}

function display_help_command(){
  case $1 in 
    cluster)
      display_help_for_cluster
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
      ;;
  esac
} 

function display_help_for_cluster(){
  echo "Usage: $0 cluster [--nodes n]"
  echo "Create the VMs and deploy a Kubernetes cluster into them."
  echo "The arguments that define how the cluster will be created:"
  echo "     --nodes n"
  echo "            Specify the number of worker nodes to be created. The default value is 2. "
}
function display_help_for_destroy(){
  echo "Usage: $0 destroy"
  echo "Destroy the Kubernetes cluster and the VMs"
}
function display_help_for_local(){
  echo "Usage: $0 local"
  echo "Prepares the local enviroment. It creates the kubeconfig and installs kubectl."
}
function display_help_for_kvm(){
  echo "Usage: $0 kvm"
  echo "Install kvm and its dependencies locally."
}
function exec_command(){
  case $1 in 
    cluster)
      shift
      cluster "$@"
      ;;
    destroy)
      destroy
      ;;
    local)
      clocal
      ;;
    kvm)
      kvm      
      ;;
    help)
      display_help_command $2
      ;;
    *)
      echo "Invalid command: $1" >&2
      display_help 
      ;;
  esac
}
exec_command "$@"
