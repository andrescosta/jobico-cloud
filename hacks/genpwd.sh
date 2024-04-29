echo "Salt: $1"
mkpasswd --method=SHA-512 --salt=$1 --rounds=4096 -s
