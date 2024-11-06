#!/bin/bash
wget -O - -nv --ciphers DEFAULT@SECLEVEL=1 https://www.wall2.ilabt.iminds.be/enable-nat.sh | sudo bash
sudo apt update && sudo apt install python2 -y
sudo rm /usr/bin/python
sudo ln -s /usr/bin/python2 /usr/bin/python
wget https://doc.ilabt.imec.be/downloads/geni-get-info.py
chmod u+x geni-get-info.py

output=$(./geni-get-info.py | sed -n '/Experiment network interfaces:/,$p' | grep -E "Iface name:|dev:|ipv4:" | awk -F':' '/Iface name:|dev:|ipv4:/ {gsub(/^[[:space:]]+|[[:space:]]+$/, "", $2); gsub(/^[[:space:]]+|[[:space:]]+$/, "", $3); print $2,$3}')
control=$( ./geni-get-info.py | grep -A 2 "Control network interface:" | grep "dev:" | awk '{print $2}')
ips=($( ./geni-get-info.py | sed -n '/Requested public IPv4 pool (routable_pool):/,/^$/p' | grep -oE "\b([0-9]{1,3}\.){3}[0-9]{1,3}\b"))
readarray -t lines <<< "$output"
for ((i=0; i<${#lines[@]}; i+=3)); do
    dev=${lines[$i+1]}
    dev=$(echo "$dev" | awk '{$1=$1};1')
    ip=$(echo ${lines[$i+2]} | sed 's/ (netmask [0-9.]\+)//')
    if [[ $ip == 192.168.*.1 ]]; then
        IFS='.' read -r part1 part2 part3 part4 <<< "$ip"

        public_ip_address=$(ip addr show dev "$control".29 | awk '/inet / {print $2}' | cut -d/ -f1)

        wget https://cloud.ilabt.imec.be/index.php/s/FNYAaLbDj49QYEL/download/openvpn_install.sh -O openvpn-install.sh
        sudo /bin/bash openvpn-install.sh $public_ip_address "client$part3" $part3
        rm openvpn-install.sh

        sudo systemctl enable openvpn-server@server.service
        sudo systemctl start openvpn-server@server.service

        sudo iptables -t nat -A POSTROUTING -s 10.8.$part3.0/24 -j MASQUERADE
        sudo iptables -D POSTROUTING -s 10.8.$part3.0/24 ! -d 10.8.$part3.0/24 -j SNAT --to-source $public_ip_address -t nat

        DEBIAN_FRONTEND=noninteractive apt-get install -y iptables-persistent
    
        sudo ip route del 193.190.127.192/26

        # URL and file parameters
        pub_ip_server=${ips[0]}
        url="http://$pub_ip_server:5000/openvpn/upload"
        # TODO maybe change this to path of current user
        file="/users/geniuser/client$part3.ovpn"
        user="rl"
        timeout=1

        # Loop until the curl command succeeds
        while true; do
            # Execute the curl request
            curl -X POST --url "$url" -F "file=@$file" -u "$user:" --connect-timeout "$timeout"
            
            # Check if the request was successful
            if [ $? -eq 0 ]; then
                echo "Upload successful!"
                break
            else
                echo "Upload failed, retrying in 5 seconds..."
                sleep 5
            fi
        done

    fi
done
sudo rm /usr/bin/python
sudo ln -s /usr/bin/python3 /usr/bin/python