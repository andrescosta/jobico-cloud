print_array(){
    values=($@)
    for v in "${values[@]}"; do
        echo "$v"
    done
}
DEBUG() {
    [ "$_DEBUG" == "on" ] && $@
}
DRY_RUN() {
    [ "$_DRY_RUN" == true ] && $@
}
NOT_DRY_RUN(){
    [ "$_DRY_RUN" == false ] && $@
} 
escape() {
    escaped_result=$(printf '%s\n' "$1" | sed -e 's/[]\/$*.^[]/\\&/g')
    echo "${escaped_result}"
}
print_array_to_file(){
    values=($@)
    for v in "${values[@]}"; do
        echo "$v" > array.txt
    done
}
