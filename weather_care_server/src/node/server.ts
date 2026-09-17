import { serve } from '@hono/node-server';
import { app } from '../index';
import { safeErrorName } from '../observability/providerErrorDiagnostics';
import { assertNodeEnvironment, createNodeRuntime } from './runtime';

assertNodeEnvironment();
const runtime = createNodeRuntime();
const hostname = process.env.NODE_HOST?.trim() || '127.0.0.1';
const port = Number(process.env.NODE_PORT ?? '8787');
if (!Number.isInteger(port) || port < 1 || port > 65_535) {
  runtime.close();
  throw new Error('NODE_PORT_INVALID');
}

const server = serve({
  fetch: (request) => app.fetch(request, runtime.env),
  hostname,
  port,
}, ({ address, port: listeningPort }) => {
  console.log(JSON.stringify({
    event: 'node_server_started',
    address,
    port: listeningPort,
  }));
});

let closing = false;
function shutdown(signal: string): void {
  if (closing) return;
  closing = true;
  server.close((error) => {
    runtime.close();
    if (error) {
      console.error(JSON.stringify({ event: 'node_server_stop_failed', error: safeErrorName(error) }));
      process.exitCode = 1;
    } else {
      console.log(JSON.stringify({ event: 'node_server_stopped', signal }));
    }
  });
}

process.on('SIGINT', () => shutdown('SIGINT'));
process.on('SIGTERM', () => shutdown('SIGTERM'));
