set_trap_err(){
    trap 'throw "code:$?, executing command at:"' ERR
}

throw(){
    local msg="$1"
    echo "FATAL ERROR: $msg">&2
    local i=0 info line func file
    while info=$(caller $i); do
        read -r line func file <<< "$info"
        printf '\t%s at %s:%s\n' "$func" "$file" "$line" >&2
        (( i += 1 ))
    done

    kill -ABRT -$$
}
