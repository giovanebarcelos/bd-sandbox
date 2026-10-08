/**
 * BD2804 - Redis com Node.js: rate limiter deslizante, Pub/Sub e worker de fila
 * Disciplina: Banco de Dados | Aula 28B - Redis em Profundidade
 * Prof. Giovane Barcelos
 *
 * Tres pecas que aparecem em quase todo back-end Node.js de producao:
 *
 *   1. Rate limiter de JANELA DESLIZANTE (Sorted Set + MULTI/EXEC)
 *      - mais justo que a janela fixa do exemplo em Python: nao permite
 *        rajada dupla na virada da janela.
 *   2. Pub/Sub: o servico de estoque publica "estoque baixo" e o painel
 *      administrativo recebe na hora (fire-and-forget, sem persistencia).
 *   3. Worker de fila com Streams: XREADGROUP bloqueante + XACK, e
 *      recuperacao de mensagens orfas com XAUTOCLAIM.
 *
 * Pre-requisitos:
 *   npm install
 *   docker run -d --name bd28-redis -p 6379:6379 redis:7-alpine
 *
 * Execucao:
 *   node BD2804-RedisRateLimiterFila.js
 */

const { createClient } = require("redis");

const URL_REDIS = "redis://localhost:6379";

// ---------------------------------------------------------------------------
// 1. Rate limiter de janela deslizante
// ---------------------------------------------------------------------------
async function permitir(redis, usuario, limite = 3, janelaMs = 1000) {
  const chave = `rl:sw:${usuario}`;
  const agora = Date.now();
  // MULTI/EXEC: os 4 comandos sao executados de forma atomica e em 1 round-trip
  const [, , contagem] = await redis
    .multi()
    .zRemRangeByScore(chave, 0, agora - janelaMs) // descarta o que saiu da janela
    .zAdd(chave, { score: agora, value: `${agora}-${Math.random()}` })
    .zCard(chave) // quantas requisicoes na ultima janela
    .pExpire(chave, janelaMs)
    .exec();
  return { permitido: contagem <= limite, contagem };
}

async function demoRateLimiter(redis) {
  console.log("\n=== 1. Rate limiter deslizante (3 req/segundo) ===");
  await redis.del("rl:sw:api-key-42");
  for (let i = 1; i <= 5; i++) {
    const { permitido, contagem } = await permitir(redis, "api-key-42");
    console.log(`req ${i}: ${permitido ? "200 OK" : "429"} (na janela: ${contagem})`);
  }
  console.log("aguardando 1,1 s para a janela deslizar...");
  await new Promise((r) => setTimeout(r, 1100));
  const { permitido } = await permitir(redis, "api-key-42");
  console.log(`req 6: ${permitido ? "200 OK" : "429"}`);
}

// ---------------------------------------------------------------------------
// 2. Pub/Sub
// ---------------------------------------------------------------------------
async function demoPubSub(redis) {
  console.log("\n=== 2. Pub/Sub de alertas de estoque ===");
  const assinante = redis.duplicate(); // conexao em modo subscribe e exclusiva
  await assinante.connect();
  const recebidas = [];
  await assinante.subscribe("alertas:estoque", (mensagem) => {
    const alerta = JSON.parse(mensagem);
    recebidas.push(alerta);
    console.log(`[painel admin] ALERTA: ${alerta.produto} com ${alerta.estoque} unidade(s)`);
  });

  const estoque = { "Monitor 27 4K": 1, "Fone Bluetooth": 150, "Notebook Gamer X": 2 };
  for (const [produto, qtd] of Object.entries(estoque)) {
    if (qtd < 5) {
      const n = await redis.publish("alertas:estoque", JSON.stringify({ produto, estoque: qtd }));
      console.log(`[servico estoque] publicou alerta de ${produto} para ${n} assinante(s)`);
    }
  }
  await new Promise((r) => setTimeout(r, 200));
  await assinante.unsubscribe("alertas:estoque");
  await assinante.quit();
  console.log(`total de alertas recebidos: ${recebidas.length}`);
}

// ---------------------------------------------------------------------------
// 3. Worker de fila com Streams
// ---------------------------------------------------------------------------
async function demoWorker(redis) {
  console.log("\n=== 3. Worker de e-mails com Streams ===");
  const stream = "emails:enviar";
  const grupo = "mailer";
  await redis.del(stream);
  await redis.xGroupCreate(stream, grupo, "0", { MKSTREAM: true });

  for (const destino of ["ana@email.com", "bruno@email.com", "carla@email.com"]) {
    await redis.xAdd(stream, "*", { destino, assunto: "Seu pedido foi aprovado" });
  }

  // worker-A le 3 mensagens mas "morre" depois de confirmar so a primeira
  const lidas = await redis.xReadGroup(grupo, "worker-A", { key: stream, id: ">" }, { COUNT: 3 });
  const [primeira] = lidas[0].messages;
  console.log(`worker-A enviou e-mail para ${primeira.message.destino}`);
  await redis.xAck(stream, grupo, primeira.id);
  console.log("worker-A caiu! pendentes:", (await redis.xPending(stream, grupo)).pending);

  // worker-B assume mensagens paradas ha mais de 0 ms (em producao: 60000 ms)
  const { messages } = await redis.xAutoClaim(stream, grupo, "worker-B", 0, "0-0");
  for (const { id, message } of messages) {
    console.log(`worker-B recuperou e enviou e-mail para ${message.destino}`);
    await redis.xAck(stream, grupo, id);
  }

  // leitura bloqueante: espera ate 500 ms por mensagens novas
  const nada = await redis.xReadGroup(grupo, "worker-B", { key: stream, id: ">" }, { COUNT: 1, BLOCK: 500 });
  console.log("nova leitura bloqueante (500 ms):", nada === null ? "fila vazia" : nada);
  console.log("pendentes ao final:", (await redis.xPending(stream, grupo)).pending);
}

async function main() {
  const redis = createClient({ url: URL_REDIS });
  redis.on("error", (e) => console.error("Erro Redis:", e.message));
  await redis.connect();
  await demoRateLimiter(redis);
  await demoPubSub(redis);
  await demoWorker(redis);
  await redis.quit();
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
