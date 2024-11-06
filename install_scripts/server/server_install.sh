wget -O - -nv --ciphers DEFAULT@SECLEVEL=1 https://www.wall2.ilabt.iminds.be/enable-nat.sh | sudo bash
sudo apt update
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
sudo mkdir /control_data
sudo chmod 777 /control_data
wget https://cloud.ilabt.imec.be/index.php/s/yrgpXxFBqiMjcGw/download/listen.sh  # listen script
wget https://cloud.ilabt.imec.be/index.php/s/7zEGQwpKKkF4isP/download/listen.service # service file
sudo mv listen.sh /usr/local/bin/listen.sh
sudo chmod 777 /usr/local/bin/listen.sh
sudo mv listen.service /etc/systemd/system/directory-monitor.service
sudo systemctl daemon-reload
sudo systemctl start directory-monitor.service
sudo systemctl enable directory-monitor.service

wget https://go.dev/dl/go1.23.2.linux-amd64.tar.gz
wget https://cloud.ilabt.imec.be/index.php/s/E93rcY23NCF7rEC/download/webrtc.tar.gz # sfu
tar -xzvf webrtc.tar.gz 
sudo  rm -rf /usr/local/go && sudo tar -C /usr/local -xzf go1.23.2.linux-amd64.tar.gz

pushd webrtc

sudo /usr/local/go/bin/go build -o sfu.exe ./sfu
sudo mkdir /usr/local/bin/sfu
sudo cp -r dashboard /usr/local/bin/sfu
sudo mv sfu.exe /usr/local/bin/sfu/sfu.exe

popd

wget https://cloud.ilabt.imec.be/index.php/s/DZjcraZWr8GraZy/download/main_dashboard.tar.gz
tar -xzvf main_dashboard.tar.gz 

pushd main_dashboard

docker build -t main_dashboard_server_app .
docker rm -f main_dashboard_server_container || true
docker run -d --name main_dashboard_server_container -v /control_data:/control_data --restart always -p 5000:5000 main_dashboard_server_app

popd