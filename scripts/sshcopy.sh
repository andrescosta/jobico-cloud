while read IP FQDN HOST SUBNET; do
	ssh-copy-id root@${IP}
done < machines.txt
