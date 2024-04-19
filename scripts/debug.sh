while read IP FQDN HOST SUBNET; do
	echo "${FQDN} ${HOST} ${IP}"
done < machines.txt
