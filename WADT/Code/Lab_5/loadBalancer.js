const http = require('http');
const httpProxy = require('http-proxy');
const proxy = httpProxy.createProxyServer({});

const targets = [
  { host: 'localhost', port: 3000, name: 'X', weight: 0.5 },
  { host: 'localhost', port: 3001, name: 'Y', weight: 0.3 },
  { host: 'localhost', port: 3002, name: 'Z', weight: 0.2 }
];

const totalWeight = targets.reduce((s, t) => s + t.weight, 0);


function pickTarget() {
  const r = Math.random() * totalWeight;
  let acc = 0;
  for (const t of targets) {
    acc += t.weight;
    if (r <= acc) return t;
  }
  return targets[targets.length - 1];
}


const server = http.createServer((req, res) => {
  // Разрешаем только /lb
  if (!req.url.startsWith('/lb')) {
    res.statusCode = 404;
    res.end('Not Found');
    return;
  }

  const target = pickTarget();
  req.url = '/A';
  const upstream = `http://${target.host}:${target.port}`;

  proxy.web(req, res, { target: upstream }, (err) => {
    console.error('Proxy error:', err);
    res.statusCode = 502;
    res.end('Bad Gateway');
  });
});


const BALANCER_PORT = 5065;
server.listen(BALANCER_PORT, () => {
  console.log(`Custom weighted balancer listening on port ${BALANCER_PORT}`);
  console.log(`Routing to X: localhost:3000 (50%), Y: localhost:3001 (30%), Z: localhost:3002 (20%)`);
});