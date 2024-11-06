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

echo 1 | sudo tee /proc/sys/net/ipv4/conf/all/proxy_arp
sudo echo "net.ipv4.ip_forward=1" > /etc/sysctl.conf
sudo echo "net.ipv4.conf.all.proxy_arp=1" > /etc/sysctl.conf

for ((i=0; i<${#lines[@]}; i+=3)); do
    dev=${lines[$i+1]}
    dev=$(echo "$dev" | awk '{$1=$1};1')
    ip=$(echo ${lines[$i+2]} | sed 's/ (netmask [0-9.]\+)//')
    if [[ $ip == 192.168.* ]]; then

        # Logic for .1 IPs (Client -> Switch)
        if [[ $ip == *2 ]]; then
            echo 1 | sudo tee /proc/sys/net/ipv4/conf/$dev/proxy_arp
            sudo echo "net.ipv4.conf.$dev.proxy_arp=1" > /etc/sysctl.conf
        fi

        # Logic for .2 IPs (Switch -> Client)
        if [[ $ip == *3 ]]; then
            echo 1 | sudo tee /proc/sys/net/ipv4/conf/$dev/proxy_arp
            sudo echo "net.ipv4.conf.$dev.proxy_arp=1" > /etc/sysctl.conf
        fi
    fi
done

sudo sysctl -p

sudo rm /usr/bin/python
sudo ln -s /usr/bin/python3 /usr/bin/python

sudo apt install apt-transport-https ca-certificates curl software-properties-common -y
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" -y
sudo apt update
sudo apt install docker-ce -y
sudo systemctl start docker
sudo systemctl enable docker

sudo apt-get install inotify-tools -y
sudo mkdir control_data
sudo chmod 777 control_data
wget https://cloud.ilabt.imec.be/index.php/s/DjSHeyp5RdFKkN5/download/listen.sh # listen script
wget https://cloud.ilabt.imec.be/index.php/s/JABHtFLz9f5rEEX/download/listen.service # service file
wget https://cloud.ilabt.imec.be/index.php/s/ayt9g2TyNpPmEPN/download/qd.sh # qd script

sudo mv listen.sh /usr/local/bin/listen.sh
sudo mv qd.sh /usr/local/bin/qd.sh
sudo chmod 777 /usr/local/bin/listen.sh
sudo chmod 777 /usr/local/bin/qd.sh
sudo chmod +x /usr/local/bin/qd.sh
sudo mv listen.service /etc/systemd/system/directory-monitor.service
sudo systemctl daemon-reload
sudo systemctl start directory-monitor.service
sudo systemctl enable directory-monitor.service

wget https://cloud.ilabt.imec.be/index.php/s/cdSbwAYKqJTxHFC/download/switch_server.tar.gz
tar -xzvf switch_server.tar.gz 

pushd switch_server

docker build --network=host -t switch_server_app . 
docker rm -f switch_server_container || true
docker run -d --name switch_server_container -v /control_data:/control_data  --restart always --network host switch_server_app

popd