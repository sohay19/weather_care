import { loadRelayConfig } from './config.js';
import { createRelayServer } from './server.js';

const config = loadRelayConfig();
const server = createRelayServer({ config });

server.listen(config.port, config.host, () => {
  console.log(
    JSON.stringify({
      event: 'relay_listening',
      host: config.host,
      port: config.port,
    }),
  );
});

function shutDown(signal: string): void {
  console.log(JSON.stringify({ event: 'relay_stopping', signal }));
  server.close((error) => {
    if (error) {
      console.error(
        JSON.stringify({ event: 'relay_stop_failed', error: error.name }),
      );
      process.exitCode = 1;
    }
  });
}

process.once('SIGINT', () => shutDown('SIGINT'));
process.once('SIGTERM', () => shutDown('SIGTERM'));
