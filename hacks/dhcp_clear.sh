eval "$(make dhcp | awk '{split($5, ip, "/"); print "dhcp_release virbr0",ip[1],$3}')"
