sudo virsh net-destroy default
sudo virsh net-undefine default
virsh net-define /usr/share/libvirt/networks/default.xml
virsh net-autostart default
virsh net-start default
virsh net-update default delete ip-dhcp-range --xml <range start='192.168.122.2' end='192.168.122.254'/> --live --config
virsh net-update default add ip-dhcp-range --xml <range start='192.168.122.100' end='192.168.122.254'/> --live --config
