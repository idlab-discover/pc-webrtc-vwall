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
    if [[ $ip == 192.168.* ]]; then
        IFS='.' read -r part1 part2 part3 part4 <<< "$ip"
        config_file="/etc/netplan/${control}.yaml"
        found=0
        pub_ip=""
        if [[ $ip == *1 ]]; then
            pub_ip_index=$((part3 * 2 + 2))
            pub_ip=${ips[pub_ip_index]}
            found=1

        fi
        if [[ $ip == *4 ]]; then
            pub_ip=${ips[0]}
            found=1
        fi
        if [[ "$found" -eq 1 ]]; then
            cat <<EOF > $config_file
network:
  version: 2
  ethernets:
    $control:
      dhcp4: yes
  vlans:
    $control.29:
      id: 29
      link: $control
      addresses:
        - $pub_ip/26  # IP address and netmask
      routes:
        - to: 0.0.0.0/0               # Default route for general traffic
          via: 193.190.127.193         # First default gateway

EOF
            break
        fi
    fi
done
sudo netplan apply
sudo rm /usr/bin/python
sudo ln -s /usr/bin/python3 /usr/bin/python