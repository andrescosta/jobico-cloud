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

prepare_file() {
    local filename=$1
    local output_dir="$(work_dir)/template/$2"
    local output_file="$output_dir/$(basename $filename)"
    if [[ "$output_file" == *.tmpl ]]; then
        output_file="${output_file%.tmpl}"
    fi
    mkdir -p "$output_dir"
    cp "$filename" "$output_file"
    shift
    shift
    for pattern in "$@"; do
        IFS="=" read -r key value <<< "$pattern"
        sed -i "s/$key/$value/g" "$output_file"
    done
    echo "$output_file"
}