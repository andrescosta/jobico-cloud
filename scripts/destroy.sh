
#!/bin/bash

. $(dirname "$0")/lib.sh 

jobico::kube::destroy_machines

rm -rf work
