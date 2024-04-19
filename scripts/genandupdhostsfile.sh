
echo "" > hosts
echo "# Kubernetes The Hard Way" >> hosts
while read IP FQDN HOST SUBNET; do
	ENTRY="${IP} ${FQDN} ${HOST}"
	echo $ENTRY >> hosts	
done < machines.txt

cat hosts >> /etc/hosts
