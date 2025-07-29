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

test_ser(){
	declare -A node_configs=(
  		[node-0]="size=small,cgroup=v1"
  		[node-1]="size=medium"
	)
	serialized=$(kv::map::serialize node_configs)
	echo "$serialized"

	declare -A new_node_configs
	kv::map::deserialize "$serialized" new_node_configs

	# Test it
	for k in "${!new_node_configs[@]}"; do
  		echo "Node $k: ${new_node_configs[$k]}"
	done

	local v
        local k
	local node
	node="node-0"
	k=${new_node_configs[$node]}
	v=$(kv::map::get_param_value "$k" "cgroup")
	if [[ -z $v ]]; then
		echo "empty"
	else
		echo "vv:$v"
	fi
}


test_ser2(){
	declare -n node_configs
	serialized=$(kv::map::serialize node_configs)
	echo "$serialized"

	declare -A new_node_configs
	kv::map::deserialize "$serialized" new_node_configs

	echo "$new_node_configs"
	local node
	local k
	node="node-3"
	k=${new_node_configs[$node]}
	if [[ $k == "" ]]; then
		echo "No for node ${node}"
	fi
}

test_ser3(){
	declare -A node_configs
	node_configs[node-0]="size=small"
	node_configs[node-1]="cgroup=v1,size=large,taints=jobico&test"
	serialized=$(kv::map::serialize node_configs)
	echo "$serialized"

	declare -A new_node_configs
	kv::map::deserialize "$serialized" new_node_configs

	# Test it
	for k in "${!new_node_configs[@]}"; do
  		echo "Node $k: ${new_node_configs[$k]}"
	done

	local v
        local k
	local node
	node="node-1"
	k=${new_node_configs[$node]}
	v=$(kv::map::get_param_value "$k" "cgroup")
	if [[ -z $v ]]; then
		echo "empty"
	else
		echo "vv:$v"
	fi
	local s
	
	s=$(kv::map::get_param_value "$k" "size")
	echo "size:$s"


	input=$(kv::map::get_param_value "$k" "taints")
accumulator=""
if [[ -n "$input" ]]; then
  IFS='&' read -ra items <<< "$input"
  for item in "${items[@]}"; do
    accumulator+=$'\n'"  - key: \"${item}\""
    accumulator+=$'\n'"    value: \"true\""
    accumulator+=$'\n'"    effect: \"NoSchedule\""
  done
fi

if [[ -n "$accumulator" ]]; then
  echo "registerWithTaints:${accumulator}"
fi
}

test_ser
echo "-------------------------" 
test_ser2
echo "-------------------------" 
test_ser3
