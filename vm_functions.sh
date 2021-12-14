#!/bin/bash
vecho_run()
{
    echo "RUN: $@;";
    local cmd=$@;
    set -f "$cmd";
    eval $cmd
}
enable_interface()
{
#    $(ip link set $1 up)
    vecho_run "ip link set $1 up"
}
disable_interface()
{
#    $(ip link set $1 up)
    vecho_run "ip link set $1 down"
}
enable_forwarding()
{
#    $(echo 1 > /proc/sys/net/ipv4/ip_forward)
    vecho_run "echo 1 > /proc/sys/net/ipv4/ip_forward"
}

enable_proxy_arp()
{
    #$(echo 1 > /proc/sys/net/ipv4/conf/$1/proxy_arp)
    vecho_run "echo 1 > /proc/sys/net/ipv4/conf/$1/proxy_arp"
}
forward_interface()
{
    #$(iptables -A FORWARD -i $1 -o $2 -j ACCEPT)
    vecho_run "iptables -A FORWARD -i $1 -o $2 -j ACCEPT"
}
#create new tap interface
next_tap()
{
	tap_interface_count=$(ip tuntap list | wc -l)
	max_index=0
	for i in `seq $tap_interface_count` 
	do
		tap_interface=$(ip tuntap list | awk '{print $1}' | head -n $i | tail -n 1 | sed 's/://')
		current_index=${tap_interface:(-1)}
		if [ $current_index -gt $max_index ] ; then
			max_index=$current_index
		fi
	done
#TODO check if new interface actually appeared and throw error otherwise
	$(ip tuntap add mode tap)
	if [ $tap_interface_count -eq 0 ] ; then
		echo "tap${max_index}"
	else
		echo "tap$(($max_index+1))"
	fi
}
delete_tap()
{
	interface=$1
	$(ip tuntap del $interface mode tap)
}
next_mac()
{
	#get two last symbols from MAC address sring
	ll=${basemac:(-1)}
	echo "${basemac:(0):(-1)}$(($ll+1))"
}
get_wan()
{
	echo $(ip route show default | awk '/default/ {print $5}')
}
get_bridge()
{
	if [ -z $(brctl show | awk ' /br[0-9]/ {print $1}'| grep $MASTER_BRIDGE)] ; then
		last_bridge=$(brctl show | awk '/br[0-9]/ {print $1}' )
	else
		if [ -n ${MASTER_BRIDGE} ] ; then
			echo ${MASTER_BRIDGE}
		fi
	fi
}
add_bridge()
{
	last_bridge=$(brctl show | awk '/br[0-9]/ {print $1}' )
	if [ -n $last_bridge ] ; then
		index=${last_bridge:(-1)}
		new_bridge=${last_bridge:(0):(-1)}$(($index+1))
		brctl addbr $new_bridge
		echo $new_bridge
	else
		new_bridge=br0
		brctl addbr $new_bridge
		echo $new_bridge
	fi
}
clean_bridge()
{
	bridge=$1
	lines=$(brctl show $bridge | wc -l)
	interface_list=""
	if [ $lines -gt 1 ] ; then
		for i in `seq $lines`
		do	
			if [ $i -gt 1 ] ; then
				interface=$(brctl show $bridge | head -n $i | tail -n 1 | awk '{print $4}')
				interface_list="$interface_list $interface"
			fi
		done	
	fi
	for i in $interface_list
	do
		delete_tap $i
	done
}
add_to_bridge()
{
	interface=$1
	bridge=$2
	$(brctl addif $bridge $interface)
}
delete_from_bridge()
{
	interface=$1
	bridge=$2
	$(brctl delif $bridge $interface)
}
delete_bridge()
{
	bridge=$1
	disable_interface $bridge
	$(brctl delbr $bridge)
}
route_addr_to_dev()
{
    #$(ip route add $1 dev $2)
    vecho_run "ip route add $1 dev $2"
}
forward_interface()
{
    vecho_run "iptables -A FORWARD -i $1 -o $2 -j ACCEPT"
#	vecho_run "iptables -A INPUT -i $1 -j ACCEPT"
#    	vecho_run "iptables -A FORWARD -i $1 -j ACCEPT"
#   	vecho_run "iptables -A FORWARD -o $1 -j ACCEPT"
}
flush_rules()
{
	iptables -F
	iptables -X
	iptables -t nat -F
	iptables -t nat -X
}

nat_network()
{
	wan=$1 
	network=$2
	vecho_run "iptables -t nat -A POSTROUTING -o $wan -s $network -j MASQUERADE"
	#iptables -t nat -A POSTROUTING -o $wan -j MASQUERADE
}

connect_network_direct()
{
        wan=$1
        vm_extif=$2
        vm_extaddr=$3
#        create_tap_interface $vm_extif
#	flush_rules
        enable_interface $vm_extif
        enable_forwarding
        enable_proxy_arp $vm_extif
        enable_proxy_arp $wan
        route_addr_to_dev $vm_extaddr $vm_extif
        forward_interface $vm_extif $wan
	network="${vm_extaddr:(0):(-1)}0/24"
	nat_network $wan $network
}
connect_network_bridged()
{
	wan=$1
	vm_extif=$2
	vm_extaddr=$3
	bridge=$4
	create_bridge $3
	
}


