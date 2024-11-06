
function startSfuServer() {
    // Get the value of the checkbox (true if checked, false otherwise)
    const enableGCC = document.getElementById('enableGCC').checked;
    const enableABR = document.getElementById('enableABR').checked;
    // Prepare data to send in the POST request
    const data = { enableGCC: enableGCC, enableABR: enableABR };

    // Send POST request using Fetch API
    fetch('/sfu', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json'
        },
        body: JSON.stringify(data) // Send the checkbox value in the request body
    })
    .then(response => response.json())
    .then(data => {
        console.log('Success:', data);
        // You can add any further actions upon success here
    })
    .catch((error) => {
        console.error('Error:', error);
    });
}
function stopSfuServer() {
    // Send POST request using Fetch API
    fetch('/sfustop', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json'
        },
    })
    .then(response => response.json())
    .then(data => {
        console.log('Success:', data);
        // You can add any further actions upon success here
    })
    .catch((error) => {
        console.error('Error:', error);
    });
}

function setInterfaceParameters(clientID, isTo) {
    let fix = "To"
    if(!isTo) {
        fix = "From"
    }
    console.log(`packetLoss${fix}Client${clientID}`)
    const bandwidth = parseInt(document.getElementById(`bandwidth${fix}Client${clientID}`).value);
    const latency = parseInt(document.getElementById(`latency${fix}Client${clientID}`).value);
    const jitter = parseInt(document.getElementById(`jitter${fix}Client${clientID}`).value);
    const loss = parseFloat(document.getElementById(`packetloss${fix}Client${clientID}`).value);

    const interface = document.getElementById(`interface${fix}${clientID}`).value;

    // Create the object conditionally
    let postBody = {clientID: clientID, interface: interface};
    // Add each property only if the value is not empty or 0
    if (!isNaN(bandwidth) && bandwidth !== 0) {
        postBody.bandwidth = bandwidth;
    }
    if (!isNaN(latency) && latency !== 0) {
        postBody.latency = latency;
    }
    if (!isNaN(jitter) && jitter !== 0) {
        postBody.jitter = jitter;
    }
    if (!isNaN(loss) && loss !== 0) {
        postBody.loss = loss;
    }

    // Send POST request using Fetch API
    fetch('/interface', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json'
        },
        body: JSON.stringify(postBody) // Send the checkbox value in the request body
    })
    .then(response => response.json())
    .then(data => {
        console.log('Success:', data);
        // You can add any further actions upon success here
    })
    .catch((error) => {
        console.error('Error:', error);
    });

}

function checkOpenVPN(clientID) {
    

    // Send POST request using Fetch API
    fetch(`/checkopenvpn?clientid=${clientID}`, {
        method: 'GET',
    })
    .then(response => {
        if (response.ok) {
          return response.json(); // Parse JSON data if response is 200
        } else {
          throw new Error(`HTTP error! status: ${response.status}`); // Handle errors
        }
      })
    .then(data => {
        console.log('Success:', data);
        // You can add any further actions upon success here
        document.getElementById(`overlay${clientID}`).remove()
    })
    .catch((error) => {
        console.error('Error:', error);
        pollOpenVPNStatus(clientID, 5000)
    });

}

function getOpenVPN(clientID) {
    
    const fileName =  `client${clientID}.ovpn`
    // Send POST request using Fetch API
    fetch(`/openvpn/${fileName}`, {
        method: 'GET',
    })
    .then(response => response.blob())
    .then(blob => {
        // Create a URL for the Blob
        const url = window.URL.createObjectURL(blob);
        
        // Create a link element
        const a = document.createElement('a');
        a.style.display = 'none'; // Hide the link
        a.href = url;
        
        // Set the filename (you can customize this)
        a.download = fileName; // Replace with your desired filename
  
        // Append the link to the body
        document.body.appendChild(a);
        
        // Programmatically click the link to trigger the download
        a.click();
        
        // Clean up and remove the link
        window.URL.revokeObjectURL(url);
        document.body.removeChild(a);
      })
    .catch((error) => {
        console.error('Error:', error);
    });

}

function getInterfaces(clientID) {
    

    // Send POST request using Fetch API
    fetch(`/interfaces?clientid=${clientID}`, {
        method: 'GET',
    })
    .then(response => {
        if (response.ok) {
          return response.json(); // Parse JSON data if response is 200
        } else {
          throw new Error(`HTTP error! status: ${response.status}`); // Handle errors
        }
      })
    .then(data => {
        console.log('Success:', data);
        // You can add any further actions upon success here
        document.getElementById(`interfaceTo${clientID}`).value = data.clientToSwitch.interface
        document.getElementById(`interfaceFrom${clientID}`).value = data.switchToServer.interface
        pollOpenVPNStatus(clientID, 0)
    })
    .catch((error) => {
        console.error('Error:', error);
        pollInterfaceStatus(clientID, 5000)
    });

}

function pollInterfaceStatus(clientID, timeout) {
    setTimeout(() => {
        getInterfaces(clientID)
    }, timeout);
}
function pollOpenVPNStatus(clientID, timeout) {
    setTimeout(() => {
        checkOpenVPN(clientID)
    }, timeout);
}

function init() {
    for(i=0; i < 4; i++) {
        pollInterfaceStatus(i, 0);
    }
}

init()