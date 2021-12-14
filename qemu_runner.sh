#!/bin/bash
set -x
source `pwd`/vm_functions.sh
#quick config section
#Modification: add nographic option
basemac="52:54:00:00:00:00"
router_ip="192.168.10.1"
MASTER_BRIDGE=""
basedir="/export/yuriy/work/kvadr_git/eth_installer_current"
image_path="/export/yuriy/work/virtnet/images"
bios_images_path="/export/yuriy/work/virtnet/bios_images"
#get vm image from vm path
#export virtual machine name
#vm0="x86-64:256M:dhcp.qcow2:vm0"
#router vm
#TODO process individual connections list
vm0="x86-64:256M:pc:dhcp.qcow2:qcow2:vm0"
vm0_connections="0:wan:direct 1:bridge:bridged"
vm_router="x86-64:256M:pc:dhcp.qcow2:qcow2:vm_router"
vm_bootstrap="x86-64:1G:pc:test_debootstrap.img,storage.img:raw:vm_bootstrap"
#tftp vm
vm_tftp="x86-64:256M:pc:tftp.qcow2:qcow2:vm_tftp"
vm_tftp_connections="0:bridge:bridged"
vm_tftp_client="x86-64:pc:vm_tftp_client"
vm_tftp_client_connections="0:bridge:bridged"
vm_client="x86-64:1G:pc:test1.qcow2:qcow2:vm_client"
#Bootstrap fresh client instances
vm1="x86-64:1G:pc:test1.qcow2:qcow2:vm1"
vm2="x86-64:256M:pc:guest.qcow2:vm2"
#vm_efi="x86-64:2G:OVMF.fd:ethos-1.3.3_upgrade.img:raw:vm_efi"
#for special purporse distrubution
#vm_efi="x86-64:2G:OVMF.fd:test_bullseye.qcow2:qcow2:vm_efi"
vm_efi="x86-64:2G:OVMF.fd:test_bullseye.backup.qcow2:qcow2:vm_efi"
vm_initramfs_test="x86-64:4G:pc:custom_ramfs_disk1.qcow2,custom_ramfs_disk2.qcow2:qcow2:vm_initramfs_test"
vm_test_images="x86-64:256M:pc:custom_ramfs.img,efi.img,boot.img,rootfs.img,swap.img,home.img:raw:vm_test_images"
vm_test2="x86-64:256M:pc:test2.img:test2_boot.img:test2_root.img:raw:vm_test2"
vm_test2_final="x86-64:256M:pc:test2.img,test2_storage.img:raw:vm_test2_final"
vm_rootfs_minimal="x86-64:256M:pc:rootfs.img:vm_rootfs_minimal" #test case :vm_test2
vm_network_boot_pc=""
vm_network_boot_efi=""
#vm_list="$vm_router $vm_tftp $vm_bootstrap"
#vm_list="$vm_router $vm_bootstrap"vm_test2="x86-64:256M:pc:test2.img:test2_boot.img:test2_root.img:raw:vm_test2"

#vm_list="$vm0 $vm_initramfs_test"
vm_list="$vm0 $vm_test2_final"
debug="true"

#add an option to explicitly set MAC

#connection record format interface:master:connection_type:vm_index
#connections_list="0:wan:direct:0 1:bridge:bridged:0 2:bridge:bridged:1 3:bridge:bridged:2"
connections_list="0:wan:direct:0 1:bridge:bridged:0 2:bridge:bridged:1"
#Add 2nd interface
#connections list for 2 virtual machines
#connections_list="0:wan:direct:0 1:bridge:bridged:0 2:bridge:bridged:1"
#Test for several virtual machioes
#Special interfaces list record
#Example:
#create network
interfaces_list=""
#list of new added virtual interfaces
new_interfaces=""
secondary_bridge=""
#run machine in background and clean interfaces if possible
#global variable for qemu_string

run_qemu_instance()
{
	vm_index=$1
#run virtual machine
	case $vm_index in
		0)
			vecho_run $vm0_string
		;;
		1)
			vecho_run $vm1_string
		;;
		2)
			vecho_run $vm2_string
		;;
		3)
			vecho_run $vm3_string
		;;
	esac
	#get all interface trecords for machine with given index
	#clean interfaces after vm run
	current_record=""
	for record in $interfaces_list
	do
		#get vm index for record
		index=$(echo $record | awk -F, '{print $4}')
		if [ $index -eq $vm_index ] ; then
			current_record="$current_record $record"
			interface=$(echo $record | awk -F, '{print $1}')
			#if interface is bridge
			if [ $(echo $interface | grep br | wc -w) -gt 0 ] ; then
				clean_bridge $interface
				delete_bridge $interface
			fi
		fi
	done
	for record in $current_record
	do
		interface=$(echo $record | awk -F, '{print $1}')
		delete_tap $interface
		new_interfaces=$(echo $new_interfaces | sed "s/$interface//")
	done
	interfaces_count=$(echo $new_interfaces | wc -w)
	if [ $interfaces_count -eq 0 ] ; then
		flush_rules
#		restore_routing
	fi
}
#clean all interfaces on restart
set -x
for connection in $connections_list
do
	echo $host
	index=$(echo $connection |  awk -F : '{print $1}')
	current_interface=$(next_tap)
	enable_interface $current_interface
	new_interfaces="$new_interfaces $current_interface"
        current_mac=$(next_mac)
	basemac=$current_mac
#Fields of interface record a separated with comma
	interface_record="$current_interface,$current_mac,$(echo $connection |  awk -F : '{print $3}'),$(echo $connection |  awk -F : '{print $4}')"
	master=$(echo $connection |  awk -F : '{print $2}')
	case $master in
		wan)
			wan_interface=$(get_wan)
			echo $wan_interface
		;;
		bridge)
			#test if passthrough bridge global is declared
			if [ -z "$secondary_bridge" ] ; then
				secondary_bridge=$(add_bridge)
				echo $secondary_bridge
			fi
		;;
	esac
#ssomething went wrong here
	master_connection=$(echo $connection |  awk -F : '{print $3}')
	case $master_connection in
		direct)
		    connect_network_direct $wan_interface $current_interface $router_ip
		;;
		bridged)
			case $master in
			wan)
			    #Not ready yet	
			    master_bridge=$wan_interface
			    #Not ready yet
			    connect_network_bridged $current_interface $wan_interface $master_bridge
			;;
			bridge)
			    add_to_bridge $current_interface $secondary_bridge
			;;
			esac    
		;;
	  esac 
#TODO enable all added tap interfaces
	[ ! -z "$secondary_bridge" ] && enable_interface $secondary_bridge
	interfaces_list="$interfaces_list $interface_record"
done
echo $interfaces_list
vm_index=0
for machine in $vm_list
do
	#check vm description
	echo $machine
	#get vm name from list by index
	#get interface fo vm index
	#get entries with index
	arch=$(echo $machine | awk -F: '{print $1}')
	#system_token,cpu_token,kvm_token
	case $arch in 
		"x86-64")
		qemu_string="qemu-system-x86_64 -cpu host -enable-kvm"
		;;
		"amd64")
		qemu_string="qemu-system-x86_64"
		;;
		"i386")
		qemu_string="qemu-system-i386"
		;;
	esac
	#mem_token
	mem=$(echo $machine | awk -F: '{print $2}')               
	qemu_string="$qemu_string -m $mem"
	bios=$(echo $machine | awk -F: '{print $3}')
	if [ "x$bios" != "xpc" ] ; then
		qemu_string="$qemu_string -bios $bios_images_path/$bios"
	fi
	drives=$(echo $machine | awk -F: '{print $4}')
	format=$(echo $machine | awk -F: '{print $5}')
	drive_list=$(echo $drives  | sed 's/,/ /g')
	for drive in $drive_list
	do
		qemu_string="$qemu_string -drive format=$format,file=$image_path/$drive,if=virtio"
	done
	for interface in $interfaces_list
	do
		#get interface name
		local_interface=$(echo $interface | awk -F, '{print $1}')
		local_mac=$(echo $interface | awk -F, '{print $2}')
		#get vm index
		local_vm_index=$(echo $interface | awk -F, '{print $4}')
#something went wrong here
		if [ $local_vm_index -eq  $vm_index ] ; then
			qemu_string="$qemu_string -net nic,model=virtio,macaddr=$local_mac -net tap,ifname=$local_interface,script=no,downscript=no"
		fi      
	done
	vm_name=$(echo $machine | awk -F: '{print $6}')
	qemu_string="$qemu_string -monitor unix:${vm_name}-monitor,server,nowait -serial unix:${vm_name}-serial,server,nowait -nographic"
	graphic=$(echo $machine | awk -F: '{print $7}')
	if [ "$graphic" = "nographic" ] ; then
		qemu_string="$qemu_string -monitor unix:${vm_name}-monitor,server,nowait -serial unix:${vm_name}-serial,server,nowait -nographic"
	fi
	echo $qemu_string
	#export qemu string to virtualmachine instance
	case $vm_index in
		0)
		vm0_string=$qemu_string
		;;
		1)
		vm1_string=$qemu_string
		;;
		2)
		vm2_string=$qemu_string
		;;
		3)
		vm3_string=$qemu_string
		;;
	esac
	run_qemu_instance $vm_index &
	vm_index=$(($vm_index+1))
done

