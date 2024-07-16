sudo apt install nfs-kernel-server
sudo systemctl start nfs-kernel-server.service
sudo mkdir -p /srv/nfs
sudo chown nobody:nogroup /srv/nfs
sudo chmod 0777 /srv/nfs
sudo mv /etc/exports /etc/exports.bak
# no_root_squash is needed by PostgreSQL
echo '/srv/nfs 192.168.122.0/24(rw,sync,no_subtree_check,no_root_squash)' | sudo tee /etc/exports
sudo systemctl restart nfs-kernel-server
