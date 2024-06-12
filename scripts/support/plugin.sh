DIR=$(dirname "$0")
PLUGINS_DIR=${DIR}/scripts/plugins

. $(dirname "$0")/scripts/support/debug.sh

jobico::plugin::load() {
    local plugins_conf=$1
    while IFS='=' read -r func plugin; do
        DEBUG echo "Plugin $plugin($func)"
        if [ "${plugin}" == "" ]; then
            throw "Illegal format: The plugin ${plugin} is empty."
        fi
        if [ "${func}" == "" ]; then
            throw "The function ${func} is empty."
        fi
        plugin_file="${PLUGINS_DIR}/$plugin"
        DEBUG echo ">>Loading plugin: ${plugin_file}"
        if [ -f "${plugin_file}" ]; then
            source "$plugin_file"
        else
            throw "The plugin ${plugin_file} was not found."
        fi
    done <"${plugins_conf}"
}
