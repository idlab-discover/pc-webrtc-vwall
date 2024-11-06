
dev=$1
rate=$2
delay=$3
jitter=$4
loss=$5

sudo tc qdisc del dev $dev root &> /dev/null || true
sudo tc qdisc replace dev $dev root handle 1: htb default 1
sudo tc class add dev $dev parent 1: classid 1:1 htb rate "${rate}mbit"
if [ "$delay" -ne "0" ] && [ "$jitter" -ne "0" ]; then
    if [ "$loss" -ne "0" ]; then
        sudo tc qdisc add dev "$dev" parent 1:1 handle 10: netem delay "${delay}ms" "${jitter}ms" loss "${loss}%"
        sudo tc qdisc add dev "$dev" parent 10: pfifo limit 100000
    else
        sudo tc qdisc add dev "$dev" parent 1:1 handle 10: netem delay "${delay}ms" "${jitter}ms"
        sudo tc qdisc add dev "$dev" parent 10: pfifo limit 100000
    fi
elif [ "$delay" -ne "0" ]; then
    if [ "$loss" -ne "0" ]; then
        sudo tc qdisc add dev "$dev" parent 1:1 handle 10: netem delay "${delay}ms" loss "${loss}%"
        sudo tc qdisc add dev "$dev" parent 10: pfifo limit 100000
    else
        sudo tc qdisc add dev "$dev" parent 1:1 handle 10: netem delay "${delay}ms"
        sudo tc qdisc add dev "$dev" parent 10: pfifo limit 100000
    fi
elif [ "$loss" -ne "0" ]; then
    sudo tc qdisc add dev "$dev" parent 1:1 handle 10: netem loss "${loss}%"
fi