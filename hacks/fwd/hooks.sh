git clone https://github.com/saschpe/libvirt-hook-qemu 
cd libvirt-hook-qemu
cp ../hooks.json .
make install
sudo systemctl restart libvirtd
