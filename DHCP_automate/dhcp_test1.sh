#!/bin/bash

#Update OS and Install ISC-DHCP
#sudo apt update 
#sudo apt install isc-dhcp-server

#Assign Domain Name and FQDN name  to variables
#domain_name=$(hostname | cut -d '.' -f2-3)
#fqdomain_name=$(hostname)

OIFS="$IFS"
#List all available network intefaces.
net_int=$(ip -o link show | awk -F ': ' '{print $2}')
echo $net_int


#VLAN Configuration for interface

read -p 'Would you like to configure a VLAN for DHCP-interface (enter y/n)' yn



while [ -z "$yn" ] | [ "$yn" != "n" ] && [ "$yn" != "y" ]; do
	read -p 'Would you like to configure a VLAN for DHCP-interface (enter y/n)' yn
done	

	if [ "$yn" = "y" ]; then
		 IFS=","
		read -p 'Enter the Interface name and VLAN-ID for DHCP-Server: ' interface_name  VLAN_ID
		interface_name=${interface_name//[[:blank:]]/}
		VLAN_ID=${VLAN_ID//[[:blank:]]/}
		vlan_pkg_name=vlan
		if [ $(dpkg-query -W -f='${Status}' vlan 2>/dev/null | grep -c "ok installed") -eq 0 ]; then
			echo "Vlan package not installed, installing..."
			apt-get install vlan
		fi
			
		modprobe 8021q
		vconfig add $interface_name $VLAN_ID
		status=$?
		ip link set up $interface_name.$VLAN_ID
		status=$?

		if [ $status -eq 0 ]; then	
			echo "$interface_name.$VLAN_ID was successfully set up."
		else
			echo "Unsuccessful"
		fi
		net_int_name=$interface_name.$VLAN_ID
		IFS="$OIFS"		
	fi
	if [ "$yn" = "n" ]; then
		echo 'Enter the network interface to configure DHCP Server with: '
		read -r "net_int_name"
		
		while [ -z $net_int_name ]; do
			
			echo 'Enter the network interface to configure DHCP Server with: '
			read -r "net_int_name"
		
		done
		
		status=$?
		ip link set up $net_int_name
		status=$?
		
		if [ $status -eq 0 ]; then
			echo "$net_int_name was set up Successfully."
		
		else	
			echo "$net_int_name wasn't set up, exiting.."
			exit 1
		fi
	fi
net_int_name_mod="\"${net_int_name}\""

#Assign files to variables
dhcp_default="/etc/default/isc-dhcp-server"
dhcpd_file="/etc/dhcp/dhcpd.conf"

if [ -w $dhcp_default ]; then
	sed -i -e "s/\(INTERFACESv4=\).*/\1$net_int_name_mod/" $dhcp_default
else
	echo "Err: /etc/default/isc-dhcp-server file doesnt exist or cannot open!"
	exit 
fi
	
#ifconfig wlp3s0.200 10.0.2.22

read -p "Would you like to configure DNS? (enter y/n)" yn
domain_name_server_original1="ns1.example.org"
domain_name_server_original2="ns2.example.org"

while [ -z "$yn" ] | [ "$yn" != "n" ] && [ "$yn" != "y" ]; do
	read -p 'Would you like to configure DNS? (enter y/n)' yn
done	

if [ "$yn" = "y" ]; then 
	
	if [ -w $dhcpd_file ]; then
		
		read -p 'Enter the Domain Name (example.org): ' domain_name
		domain_name_mod="\"${domain_name}\""	
		sed -i -e "s/\(domain-name \).*/\1$domain_name_mod/" $dhcpd_file	
		
		read -p "How many Domain Name Servers Would you like to Enter? (1 or 2): " domain_name_server_number
		
		case "$domain_name_server_number"  in
		"1") read -p 'Enter a Domain Name Server (ns1.example.org): ' domain_name_server 			
			while [ -z $domain_name_server ]; 
				do
					read -p "Enter the Domain Name Server (ns1.example.org): " domain_name_server	
				done
			sed -i  "s/$domain_name_server_original1/$domain_name_server/g" $dhcpd_file
			domain_name_server_original1=$domain_name_server
			#DELETE ns2.example.org NOT ADDED
		;;

		"2") IFS=","
			read -p 'Enter the Domain Name Servers (ns1.example.org, ns2.example.org)' domain_name_server1 domain_name_server2
			domain_name_server1=${domain_name_server1//[[:blank:]]/}
			domain_name_server2=${domain_name_server2//[[:blank:]]/}
		
				
			sed -i  "s/$domain_name_server_original1/$domain_name_server1/g" $dhcpd_file
			
			sed -i  "s/$domain_name_server_original2/$domain_name_server2/g" $dhcpd_file

			domain_name_server_original1=$domain_name_server1
			domain_name_server_original2=$domain_name_server2
			IFS="$OIFS"		
		;;

		*) echo 'Oops, You can configure atmost 2 Domain Name Server using this script, to add more DNS address, kindly edit dhcpd.conf file.'
		break
		;;
		esac    # --- end of case ---
	fi
fi
if [ "$yn" = "n" ]; then
	echo  'DNS Not Configured, processing next stage...Please Wait'
fi

read -p "Would you like to make this dhcp server authoritative? (enter y/n)" yn

while [ -z "$yn" ] | [ "$yn" != "n" ] && [ "$yn" != "y" ]; do
	read -p "Would you like to make this dhcp server authoritative? (enter y/n) " yn
done
if [ "$yn" = "y" ]; then
	sed -i  's/#authoritative/authoritative/g' $dhcpd_file
fi
if [ "$yn" = "n" ]; then
	echo 'Ok.'
fi

#Read IP address, Broadcast, gateway, subnet and configure the dhcp interface.
#ifconfig wlp3s0.41 | awk -F'' 'FNR == 2 {print $2}'

 EmptyEntry() {
	var=$1
	name=$2
	while [ -z $var ]; do
		#LOCAL="Cannot be Empty!"
		echo "Enter $name for DHCP Config: " >&2
		read  local_var
		var=$local_var
		done
		echo "$var"  
}
	read -p "Enter IP Address for DHCP Config: " ip_address
	ip_name="IP Address"
	ip_address1=$(EmptyEntry "$ip_address" "$ip_name") 
	ip addr add $ip_address1 dev $net_int_name
#	echo $ip_address1	
	
#	read -p "Enter the Subnet Mask: " subnet_mask
	
#	read -p "Enter the default gateway: " gate_way
	
#	read -p "Enter the broadcast Address: " broad_cast


############################################################################

#default subnet if no ckt-ID || remote-ID is not entered. FilePath=$dhcpd_file
#echo 'Proceeding to onfiguration of default dhcp subnet range...'
#echo 'Please wait...'
#
#	read -p 'Enter default dhcp subnet to be used (Eg: 10.5.5.0): ' subnet_dhcp
#
#	dhcp_name="dhcp subnet"
#	subnet_dhcp1=$(EmptyEntry "$subnet_dhcp" "$dhcp_name") 
#
#
#IFS=","
#	read -p 'Enter the default range of IP (Eg: 10.5.5.26, 10.5.5.30):' range1 range2 
#
#	range1=${range1//[[:blank:]]/}
#	range2=${range2//[[:blank:]]/}
#
#IFS="$OIFS"
#
#	read -p 'Enter subnet-mask (Eg: 255.255.255.224): ' subnet_mask_dhcp
#
#	#CALLING THE EMPTYENTRY FUNCTION
#	
#	subnet_mask_dhcp_name="subnet-mask"
#	subnet_mask_dhcp1=$(EmptyEntry "$subnet_mask_dhcp" "$subnet_mask_dhcp_name") 
#	
#	#FUNCTION RETURNS VARIABLE.
#
#
#	read -p 'Enter the routers address (Eg: 10.5.5.1): ' router_dhcp
#	
#	
#	router_dhcp_name="router address"
#	router_dhcp1=$(EmptyEntry "$router_dhcp" "$router_dhcp_name") 
#	
#
#
#	read -p 'Enter the broadcast-address (Eg: 10.5.5.31):' broadcast_dhcp
#	
#	read -p 'Enter the default-lease-time in sec (Eg: 600):' lease_time
#	
#	read -p 'Enter the max-lease-time in sec (Eg: 7200): ' max_lease
#
#
#for i in $(seq 53 62)
#do 
#	sed -i "${i}s/^#//" $dhcpd_file
#done
#
# 	sed -i "53s/10.5.5.0/$subnet_dhcp1/" $dhcpd_file
# 	sed -i "57s/255.255.255.224/$subnet_mask_dhcp1/" $dhcpd_file
#	sed -i "54s/10.5.5.26/$range1/" $dhcpd_file
#	sed -i "54s/10.5.5.30/$range2/" $dhcpd_file
#	sed -i "58s/10.5.5.1/$router_dhcp1/" $dhcpd_file
# 	sed -i "59s/10.5.5.31/$broadcast_dhcp/" $dhcpd_file
# 	sed -i "60s/600/$lease_time/" $dhcpd_file
# 	sed -i "61s/7200/$max_time/" $dhcpd_file

#Adding Circuit ID and Remote ID and Assigning subnet for Clients:


###### CKT ID - RMT ID INPUT ########

###### MODIFY THIS PART
	read -p "How many Circuit and Remote ID  would you like to configure(2,2):" num_id 
	IFS=","
	idx_c=0
	idx_r=0

	while [ $num_id -gt 0 ]; do 
		read -p "Enter the circuit ID and Remote ID (Eg: 2,0): " cid rid
		cid=${cid//[[:blank:]]/}
		rid=${rid//[[:blank:]]/}

	while [[ -z $cid ]] || [[ -z $rid ]]; do 
		read -p "Enter both circuit ID and Remote ID (Eg: 2,0):" cid rid
	done
	Circuit_ID[$idx_c]=$cid
	Remote_ID[$idx_r]=$rid

	let "idx_c++"	
	let "idx_r++"	
	let "num_id--"
done


#add 2 more such loops to typ2 and type 3 inputs and store in differet array
#add var feature
##### CKT ID - RMT ID ########

###### CLASS CREATION ###############

echo "|----------------------------------------------------------|"
echo "|     |Type| <------------------------------> |VALUE|      |"
echo "|      PORT           <-------------->          1          |"
echo "|  CHASSIS-SLOT-PORT  <-------------->          2          |"
echo "|     MAC ID          <-------------->          3          |"
echo "|----------------------------------------------------------|"

read -p "You can  create any of the above class creation method, enter any one value (referabove example):" value

if [ "$value" = "1" ]; then 
type_="PORT" 
fi
if [ "$value" = "2" ]; then 
type_="CHASSIS-SLOT-PORT" 
fi
if [ "$value" = "3" ]; then 
type_="MAC_ID" 
fi

echo "How many classes of type" $type_ "would you like to create: "
read  num_type 

case  $value in
#CASE-1 is for class type-port
"1") while [ $num_type -gt 0 ]; do
	read -p "Would you like to provide CID or RID or Both? (Enter CID or RID or Both)" var	

		bi=1
		ci=0
		ri=0
		if [ "$var" = "CID" ]; then
			
			echo "class \"PORT\"-" \"$ci\"  "{">> $dhcpd_file
			echo "match if binary-to-ascii(10,8,"",substring(option agent.circuit-id,2,1)) = " $Circuit_ID[$ci] ";" >>$dhcpd_file
			let "ci++"
			echo "}" >> $dhcpd_file
		
		elif [ "$var" = "RID" ]; then
			echo "class \"PORT\"-" \"$ri\" "{">> $dhcpd_file
			echo "match if binary-to-ascii(10,8,"",substring(option agent.remote-id,2,1)) = " $Remote_ID[$ri] ";" >> $dhcp_file
			let "ri++"
			echo "}" >> $dhcp_file
		
		elif [[ "$var" = "Both" ]] || [[ "$var" = "both" ]]; then
			echo "class \"PORT\"-" \"$bi\"  "{">> $dhcpd_file
			echo "match if binary-to-ascii(10,8,"",substring(option agent.circuit-id,2,1)) = " $Circuit_ID[$ci] ";" >>$dhcpd_file
			echo "match if binary-to-ascii(10,8,"",substring(option agent.remote-id,2,1)) = " $Remote_ID[$ri] ";" >> $dhcp_file

			let "ci++"
			let "ri++"
			"}" >> $dhcpd_file
				
			let "bi++"
	
		
		else echo "ok"
		fi
		let "num_type--"	
done 
;;

"2")while [ $num_type -gt 0 ]; do
	read -p "Would you like to provide CID or RID or Both? (Enter CID or RID or Both)" var	

		bi=1
		ci=0
		ri=0
		if [ "$var" = "CID" ]; then
			
			echo "class \"PORT\"-" \"$ci\"  "{">> $dhcpd_file
			echo "match if binary-to-ascii(10,8,"",substring(option agent.circuit-id,2,1)) = " $Circuit_ID[$ci] ";" >>$dhcpd_file
			let "ci++"
			echo "}" >> $dhcpd_file
		
		elif [ "$var" = "RID" ]; then
			echo "class \"PORT\"-" \"$ri\" "{">> $dhcpd_file
			echo "match if binary-to-ascii(10,8,"",substring(option agent.remote-id,2,1)) = " $Remote_ID[$ri] ";" >> $dhcp_file
			let "ri++"
			echo "}" >> $dhcp_file
		
		elif [[ "$var" = "Both" ]] || [[ "$var" = "both" ]]; then
			echo "class \"PORT\"-" \"$bi\"  "{">> $dhcpd_file
			echo "match if binary-to-ascii(10,8,"",substring(option agent.circuit-id,2,1)) = " $Circuit_ID[$ci] ";" >>$dhcpd_file
			echo "match if binary-to-ascii(10,8,"",substring(option agent.remote-id,2,1)) = " $Remote_ID[$ri] ";" >> $dhcp_file

			let "ci++"
			let "ri++"
			"}" >> $dhcpd_file
				
			let "bi++"
		
		
		else echo "ok"
		fi
		let "num_type--"	
done 
;;

"3")while [ $num_type -gt 0 ]; do
	read -p "Would you like to provide CID or RID or Both? (Enter CID or RID or Both)" var	

		bi=1
		ci=0
		ri=0
		if [ "$var" = "CID" ]; then
			
			echo "class \"PORT\"-" \"$ci\"  "{">> $dhcpd_file
			echo "match if binary-to-ascii(10,8,"",substring(option agent.circuit-id,2,1)) = " $Circuit_ID[$ci] ";" >>$dhcpd_file
			let "ci++"
			echo "}" >> $dhcpd_file
		
		elif [ "$var" = "RID" ]; then
			echo "class \"PORT\"-" \"$ri\" "{">> $dhcpd_file
			echo "match if binary-to-ascii(10,8,"",substring(option agent.remote-id,2,1)) = " $Remote_ID[$ri] ";" >> $dhcp_file
			let "ri++"
			echo "}" >> $dhcp_file
		
		elif [[ "$var" = "Both" ]] || [[ "$var" = "both" ]]; then
			echo "class \"PORT\"-" \"$bi\"  "{">> $dhcpd_file
			echo "match if binary-to-ascii(10,8,"",substring(option agent.circuit-id,2,1)) = " $Circuit_ID[$ci] ";" >>$dhcpd_file
			echo "match if binary-to-ascii(10,8,"",substring(option agent.remote-id,2,1)) = " $Remote_ID[$ri] ";" >> $dhcp_file

			let "ci++"
			let "ri++"
			"}" >> $dhcpd_file
				
			let "bi++"
		
		else echo "ok"

		fi
			
		let "num_type--"	
done 
;;
esac    # --- end of case ---
##### CLASS CREATION END #########

####### SUBNETS CREATION ########
read -p 'How many subnets would you like to use:(Note: There can be many pools under a given subnet): ' subnet_num

while [ -z "$subnet_num" ]; do 
	read -p 'How many subnets would you like to use:(Note: There can be many pools under a given subnet): ' subnet_num

done

declare -a subnet_arr
idx_net=0
count=1
while [ $subnet_num -gt 0 ]; do
	echo  'Enter the subnet' $count '(Eg:10.10.29.40):'
	read  subnets
	while [ -z $subnets ]; do
			
		echo  'Input the subnets one at a time' $count '(Eg:10.10.29.40):'
		read  subnets
	done
	
	subnet_arr[$idx_net]=$subnets
	let "idx_net++"
	let "count++"	
	let "subnet_num--"
done

for i in "${subnet_arr[@]}"
do
	
	read -p "Enter the netmask for the subnet (Eg: 255.255.255.0):"netmask
	read -p "Enter the option routers (Eg: 10.10.10.2):" opt_router
	read -p "default-lease-time:" d_time
	read -p "max-lease-time:" m_time
	read -p "Enter option subnet-mask: " opt_subnet
	read -p "Enter the option domain-name-servers: " opt_dns

#create subnets with parameters

done

##### SUBNETS ###########

###### POOL ########
read -p "How many pools would you like to configure:" pool_num
while [ -z $pool_num ]; do
	read -p "How many pools would you like to configure:" pool_num
done

IFS=","
while [ $pool_num -gt 0 ]; do
	echo 'Enter the  range for pool' $count '(Eg: 10.10.10.10 10.10.10.100):'
	read pool_range1 pool_range2
	pool_range1=${pool_range1//[[:blank:]]/}
	pool_range2=${pool_range2//[[:blank:]]/}

	echo "Enter the members to allow for this pool (Eg: PORT20):" 
	read allow_mem
#create pools
done 

echo "Would you like to add deny option to any pools? (Enter y/n):" 
read yn
#add deny members
IFS=$OIFS

####### POOl #############


#display the table and ask to configure manually if any error or delete file and start again 

# add option to configure keep cetain default features
# add DNS configuration commands
# alter script for RedHat config
# add circuit ID and Remote ID config



#Firewall
Firewall Changes
sudo ufw allow 67/udp
sudo ufw reload

#isc-dhcp-server Enable

sudo systemctl status isc-dhcp-server.service
sudo systemctl start isc-dhcp-server.service
sudo systemctl start isc-dhcp-server
sudo systemctl enable isc-dhcp-server
sudo systemictl enable isc-dhcp-server
