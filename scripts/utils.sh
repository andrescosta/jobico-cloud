
print_array(){
    values=($@)
    for v in "${values[@]}"; do
        echo "$v"
    done
}
DEBUG() {
    [ "$_DEBUG" == "on" ] && $@
}
