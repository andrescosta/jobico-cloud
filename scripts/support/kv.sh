# Serialize a Bash associative array (map) into a key:value string.
# Each entry in the array can hold a simple value or a structured string.
# Example when called as:
#   ./script.sh --node-0 "ip=10.0.0.1,role=master,zone=us-east"
# Internal structure:
#   declare -A node_configs=(
#     [node-0]="ip=10.0.0.1,role=master,zone=us-east"
#   )
# Output:
#   node-0:ip=10.0.0.1,role=master,zone=us-east

kv::map::serialize() {
  declare -n kv_map=$1
  local result=""
  for key in "${!kv_map[@]}"; do
    [[ -n "$result" ]] && result+="|"
    result+="${key}:${kv_map[$key]}"
  done
  if [[ $result == "" ]]; then
        result="empty"
  fi
  echo "$result"
}

kv::map::deserialize() {
  local serialized="$1"
  declare -n output_map=$2

  if [[ $serialized == "empty" ]]; then
    return
  fi

  IFS='|' read -ra entries <<< "$serialized"
  for entry in "${entries[@]}"; do
    local key="${entry%%:*}"
    local val="${entry#*:}"
    output_map["$key"]="$val"
  done
}

kv::map::get_param_value() {
  local param_string="$1"
  local key="$2"
  IFS=',' read -ra entries <<< "$param_string"
  for entry in "${entries[@]}"; do
    if [[ "$entry" == "$key="* ]]; then
      echo "${entry#*=}"
      return
    fi
  done
}
