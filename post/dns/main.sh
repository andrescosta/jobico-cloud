if [ -d "/etc/systemd/resolved.conf.d/jobico.conf" ]; then
    sudo mkdir -p /etc/systemd/resolved.conf.d/
    cp $1/jobico.conf /etc/systemd/resolved.conf.d/jobico.conf
    sudo systemctl restart systemd-resolved
fi





