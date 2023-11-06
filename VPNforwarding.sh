#!/bin/bash

kali_ip=$(hostname -I | awk '{print $1}')
iface=$(ip link show | grep -o '^[0-9]\+: [a-zA-Z0-9]*' | awk '{print $2}' FS=':' | sed -n '2p' | sed 's/ //g')
htb_subnet=$(ip route show dev tun0 | tail -n1 |awk '{print $1}')

ctrl_c(){
  echo -e "\n [!] Exiting..."; sleep 0.5; exit 1

}

checkIpv4(){

  if ifconfig tun0 &>/dev/null; then
    echo -e "\n[+] Interface tun0 exists, skipping"; sleep 0.5
  else
    echo -e "\n[!] Interface tun0 not enabled, are you sure you are running OpenVPN? "; sleep 0.5; exit 1
  fi

  if [ "$(cat /proc/sys/net/ipv4/ip_forward)" -eq 0 ]; then

    echo -ne "\n[!] IPv4 forwarding is not enabled! Do you want to enable it? (y/n): " && read -r r

    case $r in 
      y) echo -e "\n[*] Enabling IPv4 forwarding"; sleep 0.5; echo 1 > /proc/sys/net/ipv4/ip_forward; sleep 0.5; echo -e "\n[+] Done!";;
      n) echo -e "\nExiting...\n"; exit 1;;
      *) echo -e "\n[!] Please provide a valid option (y/n)\n"
    esac

  else
    echo -e "\n[+] Ipv4 forwarding enabled, skipping..."; sleep 0.5

  fi

}

forward(){

  iptables --table nat --append POSTROUTING --out-interface tun0 -j MASQUERADE
  iptables --append FORWARD --in-interface $iface -j ACCEPT

  echo -e "[+] Iptables rules created, please run the following command on your Windows host:\n" 

  echo -e "\troute add $htb_subnet $kali_ip" 
  echo -e "\nTo delete the rule\n"
  echo -e "\troute delete $htb_subnet $kali_ip"


}

deleteTables(){

  echo -e "\n[!] Are you sure you want to proceed? All currently saved iptables rules will be deleted. (y/n): " && read -r r 

  case $r in 
    y)iptables --flush; iptables --table nat --flush; iptables --delete-chain; iptables --table nat --delete-chain;;
    n) echo -e "\nExiting...\n";;
    *) echo -e "\n[!] Please provide a valid option (y/n)\n"
    esac

}

trap ctrl_c SIGINT

if [ "$(id -u)" -eq 0 ]; then

  checkIpv4
  deleteTables
  forward

else
  echo -e "\n[!] You must be root to execute this script\n"
  
fi
