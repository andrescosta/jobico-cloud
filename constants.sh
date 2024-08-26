readonly SCRIPTS="${DIR}/scripts"
readonly WORK_DIR="${DIR}/work"
readonly DOWNLOADS_DIR="${DIR}/downloads"
readonly DOWNLOADS_LOCAL_DIR="${DIR}/downloads_local"
readonly EXTRAS_DIR="${DIR}/extras"
readonly HOSTSFILE="${WORK_DIR}/hosts"
readonly CA_CONF="${WORK_DIR}/ca.conf"
readonly MAKE=make
readonly STATUS_FILE=${WORK_DIR}/jobico_status
readonly CLUSTER_NAME=jobico-cloud
readonly WORKER_NAME=node
readonly SERVER_NAME=server
readonly LB_NAME=lb
readonly ENCRYPTION_KEY=$(head -c 32 /dev/urandom | base64)
readonly BEGIN_HOSTS_FILE="#B> Kubernetes Cluster"
readonly END_HOSTS_FILE="#E> Kubernetes Cluster"
readonly PLUGINS_CONF_FILE=${DIR}/plugins.conf