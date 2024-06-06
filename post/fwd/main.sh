temp_dir=$(mktemp -d)
git clone https://github.com/saschpe/libvirt-hook-qemu $temp_dir
cd $temp_dir
cp $1/hooks.json .
make install
sudo systemctl restart libvirtd
rm -rf $temp_dir
