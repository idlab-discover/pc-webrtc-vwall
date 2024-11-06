from flask import Flask, request, jsonify
import os
import psutil
import socket
import subprocess
import argparse
parser = argparse.ArgumentParser()
parser.add_argument("--debug", action="store_true", help="Enable verbose output")
args = parser.parse_args()
IS_DEBUG=args.debug

SWITCH_CONTROLLER_PATH = "/control_data"

def get_local_interfaces():
    interfaces = psutil.net_if_addrs()
    active_ips = {}

    for interface_name, addresses in interfaces.items():
        for address in addresses:
            if address.family == socket.AF_INET:  # Check for IPv4
                ip_address = address.address
                if ip_address.startswith(IP_PREFIX) or IS_DEBUG:  # Filter for IPs starting with 192.168
                    active_ips[interface_name] = ip_address

    return active_ips

#def get_local_ips(interfaces):
#    for interface, ip in interfaces.items():
#            third_octet = int(ip.split('.')[2]) 
#            if 0 <= third_octet < MAX_NODES:
#                outgoing_third_octet = third_octet + MAX_NODES
#                outgoing_ip_address = f"192.168.{outgoing_third_octet}.3"
#                return (ip, outgoing_ip_address)

def get_server_ip(local_interfaces):
    for interface, ip in local_interfaces.items():
            third_octet = int(ip.split('.')[2]) 
            fourth_octet = int(ip.split('.')[3]) 
            if MAX_NODES <= third_octet < MAX_NODES*2:
                outgoing_fourth_octet = fourth_octet + +1
                outgoing_ip_address = f"192.168.{third_octet}.{outgoing_fourth_octet}"
                return outgoing_ip_address

app = Flask(__name__)

IP_PREFIX = "192.168."
MAX_NODES = 4

LOCAL_INTERFACES=get_local_interfaces()
SERVER_IP=get_server_ip(LOCAL_INTERFACES)
SCRIPT_PATH="qd.sh"
# POST request handler for file uploads
@app.route('/interface', methods=['POST'])
def set_latency():
 
    if request.remote_addr != SERVER_IP and not IS_DEBUG:
        return jsonify(error="No access"), 403
    data = request.json
    interface=data.get("interface")
    if interface not in LOCAL_INTERFACES:
        return jsonify(error="Invalid interface"), 400
   
    latency_value=data.get("latency")
    jitter_value=data.get("jitter")
    if latency_value==None and not isinstance(latency_value, int):
        latency_value=0
        jitter_value=0
    elif jitter_value==None and not isinstance(jitter_value, int):
        jitter_value=0

    bandwidth_value=data.get("bandwidth")
    if bandwidth_value==None and not isinstance(bandwidth_value, int):
        bandwidth_value=1000

    loss_value=data.get("loss")
    if loss_value==None and not isinstance(loss_value, float):
        loss_value=0
    if(not IS_DEBUG):
        with open(f'{SWITCH_CONTROLLER_PATH}/sfu_status.txt', 'w+') as file:
            file.write(f'{interface} {bandwidth_value} {latency_value} {jitter_value} {loss_value}')
        #result = subprocess.run(['bash', SCRIPT_PATH, interface, str(bandwidth_value), str(latency_value), str(jitter_value), str(loss_value)], capture_output=True, text=True, check=True)
    print(interface,"|", latency_value, jitter_value, bandwidth_value, loss_value)
    return jsonify(success=True)

@app.route('/interfaces', methods=['GET'])
def get_interfaces():
    response_data = {
        "clientToSwitch": {},
        "switchToServer": {}
    }
    for interface, ip in LOCAL_INTERFACES.items():
        if ip.endswith(".2") or IS_DEBUG:
            response_data["clientToSwitch"] = {
                "interface": interface,
                "ip": ip
            }
        elif ip.endswith(".3") or IS_DEBUG:
            response_data["switchToServer"] = {
                "interface": interface,
                "ip": ip
            }
    return jsonify(response_data)


if __name__ == '__main__':
    app.run(host='0.0.0.0',port=6000, debug=True)
