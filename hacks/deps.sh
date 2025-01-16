sudo apt update
sudo apt install -y qemu-kvm virt-manager libvirt-daemon-system virtinst libvirt-clients bridge-utils
sudo apt install cloud-utils whois -y
sudo systemctl enable --now libvirtd
sudo systemctl start libvirtd
sudo usermod -aG libvirt,kvm $USER
sudo apt install -y dnsmasq-utils
sudo apt install -y make
echo "The dependencies were installed. Please logout or restart your computer to refresh the changes."
