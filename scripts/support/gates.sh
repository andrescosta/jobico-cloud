get_gates(){
    local component=$1
    local dir=$(gate_config_dir)
    if [[ $dir == "" ]]; then
        dir=${GATES_DIR}
    fi
    local file="${dir}/$1.gt"
    local command=""
    if [[ -f "$file" ]]; then
        while IFS= read -r line || [ -n "$line" ]; do
            if [[ $command != "" ]]; then
                command+=","
            else
                command="--feature-gates="
            fi
            command+="${line}"
        done < $file
    fi
    command+=' \\'
    echo "$command"
}