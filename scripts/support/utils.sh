print_array() {
    values=($@)
    for v in "${values[@]}"; do
        echo "$v"
    done
}
DEBUG() {
    if [ "${_DEBUG}" == true ]; then
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

dump_array() {
  local -n assoc_array="$1"
  local result=""
  for key in "${!assoc_array[@]}"; do
    result+="${key}=${assoc_array[$key]};"
  done
  echo "${result%;}"  
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
    local filename="$1"
    local output_file="$(work_dir)/template/$2"
    local temp_file

    mkdir -p "$(dirname "$output_file")"

    cp "$filename" "$output_file"
    shift 2
    
    for pattern in "$@"; do
        key="${pattern%%=*}"
        value="${pattern#*=}"
        
        temp_file="${output_file}.tmp.$$"
        
        if awk -v search_key="$key" -v repl="$value" '{gsub(search_key, repl); print}' "$output_file" > "$temp_file"; then
            mv "$temp_file" "$output_file"
        else
            rm -f "$temp_file"
            return 1
        fi
    done
    
    echo "$output_file"
}