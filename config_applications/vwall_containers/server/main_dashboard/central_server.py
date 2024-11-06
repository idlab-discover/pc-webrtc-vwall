from flask import Flask, request, jsonify, send_from_directory, render_template, abort
import os
import requests
import argparse
parser = argparse.ArgumentParser()
parser.add_argument("--debug", action="store_true", help="Enable verbose output")
args = parser.parse_args()
IS_DEBUG=args.debug

app = Flask(__name__)

n = 4  # You can adjust this to set the maximum value for x
MAX_NODES=4
# Generate allowed IPs in the format 192.168.x.1
ALLOWED_IPS = {f"192.168.{x}.1" for x in range(n)}

# Directory to store uploaded files
UPLOAD_FOLDER = 'openvpn'
if not os.path.exists(UPLOAD_FOLDER):
    os.makedirs(UPLOAD_FOLDER)
SFU_CONTROLLER_PATH = "/control_data"

@app.route('/dashboard')
def dashboard():
    return render_template('dashboard.html')

# GET request handler for normal requests
@app.route('/hello', methods=['GET'])
def hello_world():
    return jsonify(message="Hello, World!")

# POST request handler for file uploads
@app.route('/openvpn/upload', methods=['POST'])
def upload_file():
    if request.remote_addr not in ALLOWED_IPS:
        return jsonify(error="No access"), 403
    # Check if the post request has the file part
    if 'file' not in request.files:
        return jsonify(error="No file part"), 400
    
    file = request.files['file']

    # If the user does not select a file
    if file.filename == '':
        return jsonify(error="No selected file"), 400

    # Save the file
    file_path = os.path.join(UPLOAD_FOLDER, file.filename)
    file.save(file_path)
    
    return jsonify(success=True, filename=file.filename, path=file_path)

@app.route('/checkopenvpn', methods=['GET'])
def check_openvpn():
    # Get the filename from the query parameter
    clientid = request.args.get('clientid')
    
    # Directory where the files are stored
    file_path = f"{UPLOAD_FOLDER}/client{clientid}.ovpn"

    # Check if the file exists
    if os.path.exists(file_path):
        return jsonify({"status": "File exists"}), 200
    else:
        return jsonify({"message": "File not found"}), 400

# Get uploaded file
@app.route('/openvpn/<filename>', methods=['GET'])
def get_file(filename):
    return send_from_directory(UPLOAD_FOLDER, filename)

@app.route('/interfaces', methods=['GET'])
def get_interfaces():
    client_id = request.args.get("clientid")
    switch_path = f"http://192.168.{client_id}.2:6000/interfaces"
    if(IS_DEBUG):
        switch_path = f"http://127.0.0.1:6000/interfaces"
    try:
        response = requests.get(switch_path)
        
        # Get the JSON response from the server
        data = response.json()
        if response.status_code == 200:
                data = response.json()
                return jsonify(data)
        else:
            # If the response code is not 200, return a 404
            abort(404, description="Resource not found")
    except requests.RequestException as e:
        # If there's an issue with the request (e.g., network issue), return a 404
        abort(404, description="Failed to reach the switch")
    #response_data = {
    #    "clientToSwitch": {
    #        "interface": f"intTo{client_id}",
    #    },
    #    "switchToServer": {
    #        "interface": f"intFrom{client_id}",
    #    }
    #}
    #for interface, ip in LOCAL_INTERFACES.items():
    #    if ip.endswith(".2"):
    #        response_data["client_to_switch"] = {
    #            "interface": interface,
    #            "ip": ip
    #        }
    #    elif ip.endswith(".3"):
    #        response_data["switch_to_server"] = {
    #            "interface": interface,
    #            "ip": ip
    #        }
    return jsonify(data)

@app.route('/interface', methods=['POST'])
def set_latency():
    data = request.json
    client_id=data.get("clientID")
    switch_path = f"http://192.168.{client_id}.2:6000/interface"
    if(IS_DEBUG):
        switch_path = f"http://127.0.0.1:6000/interface"
    try:
        response = requests.post(switch_path, json=data)
        
        # Get the JSON response from the server
        data = response.json()
        if response.status_code == 200:
                data = response.json()
                return jsonify(data)
        else:
            # If the response code is not 200, return a 404
            abort(404, description="Resource not found")
    except requests.RequestException as e:
        # If there's an issue with the request (e.g., network issue), return a 404
        print(e.strerror)
        abort(404, description="Failed to reach the switch")

@app.route('/sfu', methods=['POST'])
def start_sfu():
    data = request.json    
    enable_gcc=data.get("enableGCC")
    enable_abr=data.get("enableABR")
    print(enable_abr, enable_gcc)
    if(enable_gcc):
        with open(f'{SFU_CONTROLLER_PATH}/sfu_status.txt', 'w+') as file:
            file.write('status=1')
    elif(enable_abr):
        with open(f'{SFU_CONTROLLER_PATH}/sfu_status.txt', 'w+') as file:
            file.write('status=2')
    else:
        with open(f'{SFU_CONTROLLER_PATH}/sfu_status.txt', 'w+') as file:
            file.write('status=3')
    
    return jsonify(success=True)
@app.route('/sfustop', methods=['POST'])
def stop_sfu():
    with open(f'{SFU_CONTROLLER_PATH}/sfu_status.txt', 'w+') as file:
        file.write('status=0')
    return jsonify(success=True)


if __name__ == '__main__':
    app.run(host='0.0.0.0', debug=True)
