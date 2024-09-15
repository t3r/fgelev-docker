const express = require('express');
const app = express();
const childProcess = require('child_process');
const uuid = require('uuid');

// Create a single instance of the fgelev tool
const fgelevProcess = childProcess.spawn('fgelev');

// Create a cache to store responses
const responseCache = {};

// Create a map to store pending requests
const pendingRequests = {};

app.use(express.json({ strict: false }));

app.post('/api/command', (req, res) => {
  // Get the JSON data from the request body
  const { uid, lon, lat } = req.body;

  // Create a command by combining the unique identifier with the request data
  const command = `${uid} ${lon} ${lat}`;

  // Write the command to the fgelev tool's stdin
  fgelevProcess.stdin.write(`${command}\n`);

  // Store the request in the pending requests map
  pendingRequests[uid] = res;
});

// Handle responses from fgelev independently of the requests
fgelevProcess.stdout.on('data', (data) => {
  const response = data.toString().trim();
  const [uid, responseData] = response.split(':', 1);

  // Store the response in the cache
  responseCache[uid] = responseData;

  // Check if there's a pending request for this response
  if (pendingRequests[uid]) {
    const res = pendingRequests[uid];
    delete pendingRequests[uid];
    res.json({ response: response });
  }
});

app.get('/api/response/:uid', (req, res) => {
  // Check the cache for a matching unique identifier
  const uid = req.params.uid;
  if (responseCache[uid]) {
    const response = responseCache[uid];
    delete responseCache[uid];
    res.json({ response });
  } else {
    res.status(404).json({ error: 'no response found' });
  }
});

// Add a handler to gracefully shut down the server on SIGTERM and SIGINT signals
process.on('SIGTERM', shutdown);
process.on('SIGINT', shutdown);

function shutdown() {
  console.log('Received signal to shut down');

  // Close the server
  server.close((err) => {
    if (err) {
      console.error('Error closing server:', err);
    } else {
      console.log('Server closed');
    }
  });
}

const server = app.listen(3000, () => {
  console.log('Server listening on port 3000');
});
