const express = require('express');
const app = express();
const PORT = process.env.PORT || 3000;
const ENV = process.env.NODE_ENV || 'development';
const VERSION = process.env.APP_VERSION || '0.0.0';

app.get('/health', (req, res) => res.json({ status: 'ok' }));

app.get('/', (req, res) => {
  res.json({
    message: 'Hello from hello-service!',
    environment: ENV,
    version: VERSION,
  });
});

app.listen(PORT, () => console.log(`Running on port ${PORT} | ENV: ${ENV}`));
