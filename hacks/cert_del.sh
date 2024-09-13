certName="Jobico.org-CA"
certFile=work/ca.crt
certCRT=jobico.ca.crt
certPEM=jobico.ca.pem
sudo rm -r /usr/local/share/ca-certificates/$certCRT
sudo rm -r /etc/ssl/certs/$certPEM
sudo update-ca-certificates
for certDB in $(find ~/ -name "cert9.db")
do
    certdir=$(dirname ${certDB});
    certutil -D -n "${certName}" -d sql:${certdir}
done
for certDB in $(find ~/ -name "cert8.db")
do
    certdir=$(dirname ${certDB});
    certutil -D -n "${certName}" -d sql:${certdir}
done
