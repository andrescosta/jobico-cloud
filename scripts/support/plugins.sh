
DIR=$(dirname "$0")
PLUGINS_DIR=${DIR}/scripts/plugins

. $(dirname "$0")/scripts/support/debug.sh 

kube::plugins::load(){
    local plugins_conf=$1
    while IFS='=' read -r func plugin || [[ -n "$func" ]]; do 
        if [ -z "${plugin}" ]; then
            continue
        fi
        plugin_file="${PLUGINS_DIR}/$plugin"
        DEBUG echo ">>Loading plugin: ${plugin_file}"
        if [ -f "${plugin_file}" ]; then
            source "$plugin_file"
        else
            echo "The plugin ${plugin_file} was not found."
            exit 1
        fi
    done < "${plugins_conf}"
}
