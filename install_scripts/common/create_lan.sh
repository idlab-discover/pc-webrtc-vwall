wget -O - -nv --ciphers DEFAULT@SECLEVEL=1 https://www.wall2.ilabt.iminds.be/enable-nat.sh | sudo bash
sudo apt update && sudo apt install python2 -y
sudo rm /usr/bin/python
sudo ln -s /usr/bin/python2 /usr/bin/python
wget https://doc.ilabt.imec.be/downloads/geni-get-info.py
chmod u+x geni-get-info.py
output=$(./geni-get-info.py | sed -n '/Experiment network interfaces:/,$p' | grep -E "Iface name:|dev:|ipv4:" | awk -F':' '/Iface name:|dev:|ipv4:/ {gsub(/^[[:space:]]+|[[:space:]]+$/, "", $2); gsub(/^[[:space:]]+|[[:space:]]+$/, "", $3); print $2,$3}')
ips=($( ./geni-get-info.py | sed -n '/Requested public IPv4 pool (routable_pool):/,/^$/p' | grep -oE "\b([0-9]{1,3}\.){3}[0-9]{1,3}\b"))
i=0
max_nodes=4
readarray -t lines <<< "$output"

for ((i=0; i<${#lines[@]}; i+=3)); do
    dev=${lines[$i+1]}
    dev=$(echo "$dev" | awk '{$1=$1};1')
    ip=$(echo ${lines[$i+2]} | sed 's/ (netmask [0-9.]\+)//')
    if [[ $ip == 192.168.* ]]; then
        # Break IP into octets
        IFS='.' read -r part1 part2 part3 part4 <<< "$ip"

        # Set up YAML configuration for the interface
        config_file="/etc/netplan/${dev}.yaml"

        echo "Generating Netplan configuration for $dev at $ip..."

        # Generate the basic structure of the YAML file

cat <<EOF > $config_file
network:
  version: 2
  ethernets:
    $dev:
      addresses:
        - $ip/24
      routes:
EOF
        

        # Logic for .1 IPs (Client -> Switch)
        if [[ $ip == *1 ]]; then
            switch="${part1}.${part2}.${part3}.$((part4 + 1))"
            for ((n=0; n<max_nodes*2; n++)); do
                if [[ "$n" -ne "$part3" ]]; then
                    # Add routes to other clients and switches
                    target_subnet="${part1}.${part2}.${n}.0"

                    echo "        - to: $target_subnet/24" >> $config_file
                    echo "          via: $switch" >> $config_file
                fi
            done
            for ((n=0; n<max_nodes; n++)); do
                if [[ "$n" -ne "$part3" ]]; then
                    # Add routes to other clients and switches
                    target_subnet="10.8.${n}.0"

                    echo "        - to: $target_subnet/24" >> $config_file
                    echo "          via: $switch" >> $config_file
                fi
            done
            pub_ip=${ips[0]}
            echo "        - to: $pub_ip/32" >> $config_file
            echo "          via: $switch" >> $config_file
        fi

        # Logic for .2 IPs (Switch -> Client)
        if [[ $ip == *2 ]]; then
            # Backward connections
            switch_backward="${part1}.${part2}.${part3}.$((part4 - 1))"
            target_subnet_backward="${part1}.${part2}.${part3}.0"

            echo "        - to: 10.8.${part3}.0/24" >> $config_file
            echo "          via: $switch_backward" >> $config_file

            echo "        - to: $target_subnet_backward/24" >> $config_file
            echo "          via: $switch_backward" >> $config_file
        fi
        if [[ $ip == *3 ]]; then
            # Forward connections
            switch_forward="${part1}.${part2}.${part3}.$((part4 + 1))"
            for ((n=0; n<max_nodes*2; n++)); do
                if [[ "$n" -ne "$part3" && "$n" -ne "$((part3 - max_nodes))" ]]; then
                    target_subnet_forward="${part1}.${part2}.${n}.0"

                    echo "        - to: $target_subnet_forward/24" >> $config_file
                    echo "          via: $switch_forward" >> $config_file
                fi
            done
            for ((n=0; n<max_nodes; n++)); do
                if [[ "$n" -ne "$((part3 - max_nodes))" ]]; then
                    # Add routes to other clients and switches
                    target_subnet="10.8.${n}.0"

                    echo "        - to: $target_subnet/24" >> $config_file
                    echo "          via: $switch_forward" >> $config_file
                fi
            done
            

            # Public server ip
            pub_ip=${ips[0]}
            echo "        - to: $pub_ip/32" >> $config_file
            echo "          via: $switch_forward" >> $config_file
        fi
        if [[ $ip == *4 ]]; then
            switch="${part1}.${part2}.${part3}.$((part4 - 1))"
            target_subnet_client="${part1}.${part2}.$((part3 - max_nodes)).0"

            echo "        - to: 10.8.$((part3 - max_nodes)).0/24" >> $config_file
            echo "          via: $switch" >> $config_file

            echo "        - to: $target_subnet_client/24" >> $config_file
            echo "          via: $switch" >> $config_file
        fi
        # Apply the generated Netplan configuration
        echo "Applying Netplan configuration for $dev..."
        sudo chmod 600 $config_file
    fi
done
sudo netplan apply
sudo rm /usr/bin/python
sudo ln -s /usr/bin/python3 /usr/bin/python