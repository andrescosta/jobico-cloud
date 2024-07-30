sudo rm -r /usr/local/share/ca-certificates/jobico.org.crt
sudo rm -r /etc/ssl/certs/jobico.org.pem
sudo update-ca-certificates
sudo cp ../addons/core/ingress/certs/tls.crt /usr/local/share/ca-certificates/jobico.org.crt
sudo update-ca-certificates
