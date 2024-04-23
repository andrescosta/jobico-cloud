
#!/bin/bash

script_path=$(dirname $0)

echo $script_path

source $script_path/lib.sh


jobico::kube::destroy_machines

rm -rf work
