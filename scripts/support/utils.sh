print_array() {
    values=($@)
    for v in "${values[@]}"; do
        echo "$v"
    done
}
DEBUG() {
    if [ "$_DEBUG" == true ]; then
        $@
    fi
}
DEBUGOFF() {
    _DEBUG=false
}
DEBUGON() {
    _DEBUG=true
}
DRY_RUNOFF() {
    _DRY_RUN=false
}
DRY_RUNON() {
    _DRY_RUN=true
}
DRY_RUN() {
    if [ "${_DRY_RUN}" == true ]; then
        $@
    fi
}
NOT_DRY_RUN() {
    if [ "${_DRY_RUN}" == false ]; then
        $@
    fi
}
IS_DRY_RUN() {
    echo ${_DRY_RUN}
}
escape() {
    escaped_result=$(printf '%s\n' "$1" | sed -e 's/[]\/$*.^[]/\\&/g')
    echo "${escaped_result}"
}
print_array_to_file() {
    local values=($@)
    for v in "${values[@]}"; do
        echo "$v" >array.txt
    done
}
clear_dhcp() {
    eval "$(make dhcp | awk '{split($5, ip, "/"); print "dhcp_release virbr0",ip[1],$3}')"
}
