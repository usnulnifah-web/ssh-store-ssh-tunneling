import http from 'node:http';
import net from 'node:net';
import { WebSocketServer } from 'ws';

const WS_PORT = Number(process.env.WS_PORT || 8080);
const WS_PATH = process.env.WS_PATH || '/ssh';
const SSH_HOST = process.env.SSH_HOST || '127.0.0.1';
const SSH_PORT = Number(process.env.SSH_PORT || 22);

const server = http.createServer((req, res) => {
  if (req.url === '/health') {
    res.writeHead(200, { 'content-type': 'application/json' });
    res.end(JSON.stringify({ ok: true, service: 'ssh-websocket-proxy' }));
    return;
  }
  res.writeHead(404);
  res.end('not found');
});

const wss = new WebSocketServer({ noServer: true, maxPayload: 1024 * 1024 });
server.on('upgrade', (req, socket, head) => {
  const url = new URL(req.url, 'http://localhost');
  if (url.pathname !== WS_PATH) {
    socket.write('HTTP/1.1 404 Not Found\r\n\r\n');
    socket.destroy();
    return;
  }
  wss.handleUpgrade(req, socket, head, ws => wss.emit('connection', ws, req));
});

wss.on('connection', ws => {
  const upstream = net.createConnection({ host: SSH_HOST, port: SSH_PORT });
  let closed = false;
  const close = () => {
    if (closed) return;
    closed = true;
    upstream.destroy();
    if (ws.readyState === ws.OPEN || ws.readyState === ws.CLOSING) ws.close();
  };
  upstream.on('connect', () => {
    ws.on('message', data => {
      if (!closed && upstream.writable) upstream.write(data);
    });
    ws.on('close', close);
    ws.on('error', close);
    upstream.on('data', data => {
      if (!closed && ws.readyState === ws.OPEN) ws.send(data);
    });
  });
  upstream.on('error', close);
  upstream.on('close', close);
});

server.listen(WS_PORT, '127.0.0.1', () => {
  console.log(`SSH WebSocket proxy listening on 127.0.0.1:${WS_PORT}${WS_PATH} -> ${SSH_HOST}:${SSH_PORT}`);
});
