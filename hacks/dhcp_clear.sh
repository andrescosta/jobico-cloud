eval "$(make dhcp | awk '{print "dhcp_release virbr0",$5,$3}')"
