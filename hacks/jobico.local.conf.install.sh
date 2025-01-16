mkdir -p /etc/systemd/resolved.conf.d/
cp jobico.local.conf /etc/systemd/resolved.conf.d/ 
sudo systemctl restart systemd-resolved
