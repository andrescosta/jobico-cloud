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
POST_DIR="${DIR}/post"

. ${SCRIPTS}/support/exception.sh
set_trap_err
. ${SCRIPTS}/controller.sh
. ${SCRIPTS}/support/utils.sh
. ${SCRIPTS}/support/ssh.sh

# Cluster creation
## "new" command. It creates a new cluster using the provided commnad line flags.
new() {
  local do_install_post_dir=false cpl lb nodes addons_dir="" skip_addons=false schedulable_server=false
  while [[ $# -gt 0 ]]; do
    case "$1" in
    --nodes)
      shift
      if [ -n "$1" ] && [[ "$1" =~ ^[0-9]+$ ]]; then
        nodes=$1
      else
        echo "Invalid value for --nodes. Please provide a numeric value."
        display_help
        exit 1
      fi
      ;;
    --cpl)
      shift
      if [ -n "$1" ] && [[ "$1" =~ ^[0-9]+$ ]]; then
        cpl=$1
      else
        echo "Invalid value for --cpl. Please provide a numeric value." >&2
        display_help
        exit 1
      fi
      ;;
    --lb)
      shift
      if [ -n "$1" ] && [[ "$1" =~ ^[0-9]+$ ]]; then
        lb=$1
      else
        echo "Invalid value for --lb. Please provide a numeric value." >&2
        display_help
        exit 1
      fi
      ;;
    --dry-run)
      DRY_RUNON
      DEBUGON
      ;;
    --no-addons)
      skip_addons=true
      ;;
    --post)
      do_install_post_dir=true
      ;;
    --schedulable-server)
      schedulable_server=true
      ;;
    --addons)
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
    --debug)
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
    -*)
      echo "Unrecognized or incomplete option: $1" >&2
      display_help
      exit 1
      ;;
    *)
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
  if [[ $nodes == 0 ]]; then
    echo "Warning: No worker nodes are created. The control plane nodes are schedulable."
    schedulable_server=true
  fi
  if [[ $cpl > 1 ]]; then
    echo "The K8s Cluster is being created with $nodes node(s), $cpl control plane node(s) and ${lb} load balancer(s) ..."
  else
    if [[ $nodes != 0 ]]; then
      echo "The K8s Cluster is being created with $nodes node(s)."
    else
      echo "The K8s Cluster is being created with $cpl node/server."
    fi
  fi
  DRY_RUN echo ">> Dryn run << "
  local addons_list=$(find "$addons_dir/core" -mindepth 1 -maxdepth 1 -type d  ! -exec test -e "{}/disabled" \; -print | tr '\n' ';')
  addons_list+=$(find "$addons_dir/extras" -mindepth 1 -maxdepth 1 -type d ! -exec test -e "{}/disabled" \; -print | tr '\n' ';')
  DEBUG echo "$nodes $cpl $lb $schedulable_server $addons_list"
  jobico::new_cluster $nodes $cpl $lb $schedulable_server $skip_addons "$addons_list"
  if [ $do_install_post_dir == true ]; then
    install_post_dir
  fi
  NOT_DRY_RUN echo "The K8s Cluster was created."
}
## "yaml" command. It creates a new cluster using the provided yaml as template.
yaml() {
    if [ ! -f "${SCRIPTS}/support/parse_yaml.sh" ]; then
        wget https://raw.githubusercontent.com/andrescosta/parse_yaml/master/src/parse_yaml.sh -P ${SCRIPTS}/support >/dev/null 2>&1 
    fi
    source ${SCRIPTS}/support/parse_yaml.sh
    echo "Start processing $1"
    eval $(parse_yaml $1 "yaml_")
    local nodes=$DEFAULT_NODES cpl=$DEFAULT_CPL lb=$DEFAULT_LB schedulable_server=false skip_addons=false 
    local dir="" addons_list_str_yaml="" addons_list_yaml=() addons_list=""
    local services_list_str_yaml="" services_list_yaml=() services_list=""
    for f in $yaml_cluster_addons_ ; do
        dir="${f}_dir"
        addons_list_str_yaml="${f}_list_"
        addons_list_yaml=${!addons_list_str_yaml}
        for addon in ${addons_list_yaml[@]}; do
            if [[ $addons_list != "" ]]; then
                addons_list+=";"
            fi
            addons_list+="./addons/${!dir}/${!addon}"
        done 
    done
    if [[ -v yaml_cluster_node_size ]]; then
        nodes=$yaml_cluster_node_size
    fi
    if [[ -v yaml_cluster_cpl_size ]]; then
        cpl=$yaml_cluster_cpl_size
    fi
    if [[ $cpl > 1 ]]; then
        if [[ -v yaml_cluster_cpl_lb_size ]]; then
            lb=$yaml_cluster_cpl_lb_size
        fi
    fi
    if [ $nodes == 0 ]; then
        schedulable_server=true
    else
        if [[ -v yaml_cluster_cpl_schedulable ]]; then
            schedulable_server=$yaml_cluster_cpl_schedulable
        fi
    fi
    DEBUG echo "$nodes $cpl $lb $schedulable_server $addons_list"
    jobico::new_cluster $nodes $cpl $lb $schedulable_server false "$addons_list"
    for f in $yaml_cluster_services_ ; do
        dir="${f}_dir"
        services_list_str_yaml="${f}_list_"
        services_list_yaml=${!services_list_str_yaml}
        for svc in ${services_list_yaml[@]}; do
            if [[ $services_list != "" ]]; then
                services_list+=";"
            fi
            services_list+="./post/${!dir}/${!svc}"
        done 
    done
    if [[ $services_list != "" ]]; then
        echo "Waiting for the cluster to be created ..."
        NOT_DRY_RUN wait_all_pods
        echo ${services_list}
        NOT_DRY_RUN jobico::install_all_addons "newpost" "${services_list}"
    fi
    NOT_DRY_RUN echo "The K8s Cluster was created."
}

# Add new node to the current cluster
add() {
  local force=false nodes addons_dir="" skip_addons=false 
  while [[ $# -gt 0 ]]; do
    case "$1" in
    --nodes)
      shift
      if [ -n "$1" ] && [[ "$1" =~ ^[0-9]+$ ]]; then
        nodes=$1
      else
        echo "Invalid value for --nodes. Please provide a numeric value." >&2
        display_help
        exit 1
      fi
      ;;
    --dry-run)
      DRY_RUNON
      DEBUGON
      ;;
    --debug)
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
    --force)
      force=true
      ;;
    --no-addons)
      skip_addons=true
      ;;
    --addons)
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
    -*)
      echo "Unrecognized or incomplete option: $1" >&2
      display_help
      exit 1
      ;;
    *)
      echo "Invalid argument: $1" >&2
      display_help
      exit 1
      ;;
    esac
    shift
  done
  nodes=${nodes:-$DEFAULT_NODES_ADD}
  addons_dir=${addons_dir:-$ADDONS_DIR}

  echo "$nodes node(s) are being added ...  "

  if [[ $(jobico::add_cmd_was_done) == false && $(jobico::dao::cluster::is_locked) == true ]]; then
    jobico::unlock_cluster
  else
    if [[ $force == true ]]; then
      kuve::remove_add_commands
      jobico::unlock_cluster
    fi
  fi
  local addons_list=$(find "$addons_dir/core" -mindepth 1 -maxdepth 1 -type d  ! -exec test -e "{}/disabled" \; -print | tr '\n' ';')
  addons_list+=$(find "$addons_dir/extras" -mindepth 1 -maxdepth 1 -type d ! -exec test -e "{}/disabled" \; -print | tr '\n' ';')
  jobico::add_nodes $nodes $skip_addons $addons_list
  echo "The node(s) were added."
}

# Destroy the current cluster.
destroy() {
  local ask=true response
  while [[ $# -gt 0 ]]; do
    case "$1" in
    -y)
      shift
      ask=false
      response="yes"
      ;;
    --dry-run)
      shift
      DRY_RUNON
      DEBUGON
      ;;
    -*)
      echo "Unrecognized or incomplete option: $1" >&2
      display_help
      exit 1
      ;;
    *)
      echo "Invalid argument: $1" >&2
      display_help
      exit 1
      ;;
    esac
    shift
  done
  NOT_DRY_RUN do_destroy
  DRY_RUN jobico::destroy_cluster
}
do_destroy() {
  local response
  if [ "$ask" = true ]; then
    read -r -p "Are you sure to destroy the cluster? [Y/n] " response
    response=${response,,}
  fi
  if [[ $response == "yes" || $response == "y" ]]; then
    echo "Destroying the cluster ... "
    jobico::destroy_cluster
    rm -rf work
  else
    echo "Command execution cancelled."
  fi
}

clocal() {
  jobico::gen_local_env
}

cfg() {
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
  cp extras/cfg/cloud-init-node.cfg.tmpl extras/cfg/cloud-init-node.cfg
  sed -i "s/{PWD_DEBIAN}/${epass_deb}/g" extras/cfg/cloud-init-lb.cfg
  sed -i "s/{PWD_ROOT}/${epass_root}/g" extras/cfg/cloud-init-lb.cfg
  sed -i "s/{PWD_DEBIAN}/${epass_deb}/g" extras/cfg/cloud-init-node.cfg
  sed -i "s/{PWD_ROOT}/${epass_root}/g" extras/cfg/cloud-init-node.cfg
  sed -i "s/{ROOT_KEYS}/${key_root}/g" extras/cfg/cloud-init-node.cfg
  sed -i "s/{DEBIAN_KEYS}/${key_deb}/g" extras/cfg/cloud-init-node.cfg
  sed -i "s/{ROOT_KEYS}/${key_root}/g" extras/cfg/cloud-init-lb.cfg
  sed -i "s/{DEBIAN_KEYS}/${key_deb}/g" extras/cfg/cloud-init-lb.cfg
}
start_cluster() {
  jobico::start_cluster
}
shutdown_cluster() {
  jobico::shutdown_cluster
}
resume_cluster() {
  jobico::resume_cluster
}
suspend_cluster() {
  jobico::suspend_cluster
}
state_cluster() {
  jobico::state_cluster
}
info_cluster() {
  jobico::info_cluster
}
list() {
  jobico::list_vms
}
debug() {
  jobico::debug::print
}

# Helpers functions
install_post_dir() {
  DRY_RUN echo "Warning: --dry-run option was provided. The scripts are not executed."
  if [ $(IS_DRY_RUN) == true ]; then
    return
  fi
  echo "Waiting for the cluster to be created ..."
  wait_all_pods
  local post_list=$(find "$POST_DIR/core" -mindepth 1 -maxdepth 1 -type d  ! -exec test -e "{}/disabled" \; -print | tr '\n' ';')
  post_list+=$(find "$POST_DIR/extras" -mindepth 1 -maxdepth 1 -type d ! -exec test -e "{}/disabled" \; -print | tr '\n' ';')
  jobico::install_all_addons "newpost" "${post_list}"
}
wait_all_pods() {
    local timeout=4096
    kubectl wait --for=condition=Ready pods --all --all-namespaces --timeout="${timeout}s"
}

# Help releated functions
display_help() {
  echo "Usage: "
  echo "       $0 <command> [arguments]"
  echo "Commands:"
  echo "          help"
  echo "          new"
  echo "          add"
  echo "          destroy"
  echo "          addons"
  echo "          start"
  echo "          shutdown"
  echo "          suspend"
  echo "          resume"
  echo "          info"
  echo "          state"
  echo "          list"
  echo "          local"
  echo "          cfg"
  echo "          post"
  echo "          debug"
  echo "          wait"
  echo ""
  echo "Additional help: $0 help <command>"
}

display_help_command() {
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
  info | state | list)
    display_help_for_cluster_info
    ;;
  start)
    display_help_for_start
    ;;
  cfg)
    display_help_for_cfg
    ;;
  debug)
    display_help_for_debug
    ;;
  *)
    echo "Invalid command: $1" >&2
    display_help
    exit 1
    ;;
  esac
}
display_help_for_debug(){
    echo "Usage: $0 debug"
    echo "Prints the content of the internal databases using the dao scripts."
}
display_help_for_cluster_info() {
  echo "Usage: $0 <info|state|list>"
  echo "Display information about the cluster's VM(s)."
}
display_help_for_start() {
  echo "Usage: $0 start"
  echo "Starts the cluster's VMs"
}
display_help_for_addons() {
  echo "Usage: $0 addons [arguments]"
  echo "Install the addons from the folder ./addons or the one specified by --dir."
}
display_help_for_new() {
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
  echo "     --post"
  echo "            Waits for the cluster to be created and then runs the scripts on the post directory."
  echo "     --schedulable-server"
  echo "            The control plane nodes will be available to schedule pods. The default is false(tainted)."
  echo "     --dry-run"
  echo "            Create the dabases, kubeconfigs, and certificates but does not create the actual cluster. This option is useful for debugging."
  echo "     --debug [ s | d ]"
  echo "            Enable the debug mode."
  echo "       s: displays basic information."
  echo "       d: display advanced information."
}
display_help_for_add() {
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
display_help_for_destroy() {
  echo "Usage: $0 destroy"
  echo "Destroy the Kubernetes cluster and the VMs"
}
display_help_for_cfg() {
  echo "Usage: $0 cfg"
  echo "Create the cloud init cfg files."
}
display_help_for_local() {
  echo "Usage: $0 local"
  echo "Prepares the local enviroment. It creates the kubeconfig and installs kubectl."
}

# Entry point. It process the commnad line commands.
main() {
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
  yaml)
    shift
    yaml "$@"
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
    jobico::addons_post $ADDONS_DIR "ex" false
    ;;
  post)
    install_post_dir
    ;;
  local)
    shift
    clocal "$@"
    ;;
  start)
    start_cluster
    ;;
  shutdown)
    shutdown_cluster
    ;;
  suspend)
    suspend_cluster
    ;;
  resume)
    resume_cluster
    ;;
  info)
    info_cluster
    ;;
  state)
    state_cluster
    ;;
  list)
    list
    ;;
  cfg)
    shift
    cfg "$@"
    ;;
  debug)
    debug
    ;;
  wait)
    wait_all_pods  
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
