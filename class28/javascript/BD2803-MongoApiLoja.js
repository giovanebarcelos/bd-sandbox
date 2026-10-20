/**
 * BD2803 - API REST da TechStore com Node.js + driver oficial do MongoDB
 * Disciplina: Banco de Dados | Aula 28A - MongoDB em Profundidade
 * Prof. Giovane Barcelos
 *
 * Expoe o catalogo criado por BD2803-MongoLojaVirtual.py como uma API HTTP
 * (sem framework - apenas o modulo nativo node:http), mostrando como uma
 * aplicacao web real conversa com o MongoDB:
 *
 *   GET  /produtos?categoria=notebook&maxPreco=9000&pagina=1
 *   GET  /produtos/NTB-0001
 *   GET  /busca?q=banco
 *   POST /pedidos        {"clienteId":"cli-ana","itens":[{"sku":"LIV-0001","qtd":1}]}
 *   GET  /relatorios/categorias
 *
 * Pre-requisitos:
 *   winget install -e --id OpenJS.NodeJS.LTS   (Windows; Node >= 18)
 *   npm install            (usa o package.json desta pasta)
 *   Base populada: rode antes o BD2803 em Python ou o BD2803-ConsultasMongosh.js
 *
 * Execucao (usuario/senha por variavel de ambiente; padrao admin / mongodb):
 *   node BD2803-MongoApiLoja.js          # sobe a API na porta 3000
 *   node BD2803-MongoApiLoja.js --teste  # sobe, faz chamadas de teste e encerra
 *   node BD2803-MongoApiLoja.js --teste --sem-auth          # container bd28-mongo
 *   PowerShell:  $env:MONGO_USER="aluno"; $env:MONGO_PASS="s3nh4"; node BD2803-MongoApiLoja.js
 *   Linux/macOS: MONGO_USER=aluno MONGO_PASS=s3nh4 node BD2803-MongoApiLoja.js
 *   URI completa: MONGO_URI="mongodb://admin:mongodb@localhost:27017/" node BD2803-MongoApiLoja.js
 *
 * Transacoes: com replica set, POST /pedidos usa withTransaction; com um no
 * avulso (standalone, ex.: container "mongodb" do curso) usa baixa condicional
 * + compensacao - o resultado final e o mesmo.
 */

const http = require("node:http");
const { MongoClient } = require("mongodb");

const HOST = process.env.MONGO_HOST || "localhost";
const PORTA_MONGO = process.env.MONGO_PORT || "27017";
const USUARIO = process.env.MONGO_USER ?? "admin";
const SENHA = process.env.MONGO_PASS ?? "mongodb";
const PORTA = 3000;
const TAMANHO_PAGINA = 3;

// directConnection: fala direto com o no informado, sem exigir o nome do
// replica set (rs0) na URI - funciona com standalone e com replica set.
function montarUri() {
  if (process.env.MONGO_URI) return process.env.MONGO_URI;
  if (process.argv.includes("--sem-auth") || !USUARIO) {
    return `mongodb://${HOST}:${PORTA_MONGO}/?directConnection=true`;
  }
  return `mongodb://${encodeURIComponent(USUARIO)}:${encodeURIComponent(SENHA)}` +
    `@${HOST}:${PORTA_MONGO}/?authSource=admin&directConnection=true`;
}

const cliente = new MongoClient(montarUri(), { serverSelectionTimeoutMS: 5000 });
const db = cliente.db("techstore");
let usarTransacao = true; // definido em main() conforme o servidor

// ---------------------------------------------------------------------------
// Regras de negocio (camada de acesso a dados)
// ---------------------------------------------------------------------------
async function listarProdutos({ categoria, maxPreco, pagina = 1 }) {
  const filtro = { estoque: { $gt: 0 } };
  if (categoria) filtro.categoria = categoria;
  if (maxPreco) filtro.preco = { $lte: Number(maxPreco) };
  return db
    .collection("produtos")
    .find(filtro, { projection: { _id: 0, sku: 1, nome: 1, preco: 1, categoria: 1 } })
    .sort({ preco: 1 })
    .skip((Number(pagina) - 1) * TAMANHO_PAGINA)
    .limit(TAMANHO_PAGINA)
    .toArray();
}

async function buscarPorSku(sku) {
  return db.collection("produtos").findOne({ sku }, { projection: { _id: 0 } });
}

async function buscaTextual(q) {
  return db
    .collection("produtos")
    .find({ $text: { $search: q } }, { projection: { _id: 0, nome: 1, score: { $meta: "textScore" } } })
    .sort({ score: { $meta: "textScore" } })
    .toArray();
}

// Baixa o estoque e grava o pedido (usado com e sem transacao)
async function registrarPedido({ clienteId, itens }, sessao, baixados) {
  const linhas = [];
  let total = 0;
  for (const { sku, qtd } of itens) {
    const produto = await db.collection("produtos").findOneAndUpdate(
      { sku, estoque: { $gte: qtd } },
      { $inc: { estoque: -qtd } },
      { session: sessao, returnDocument: "after", projection: { _id: 0, nome: 1, preco: 1 } }
    );
    if (!produto) throw new Error(`Estoque insuficiente para ${sku}`);
    baixados?.push({ sku, qtd });
    const subtotal = Math.round(produto.preco * qtd * 100) / 100;
    total += subtotal;
    linhas.push({ sku, nome: produto.nome, qtd, preco_unit: produto.preco, subtotal });
  }
  const cli = await db.collection("clientes").findOne({ _id: clienteId }, { session: sessao });
  if (!cli) throw new Error(`Cliente ${clienteId} inexistente`);
  const { insertedId } = await db.collection("pedidos").insertOne(
    {
      cliente_id: clienteId,
      entrega: cli.endereco,
      itens: linhas,
      total: Math.round(total * 100) / 100,
      status: "PAGO",
      criado_em: new Date(),
    },
    { session: sessao }
  );
  return { pedidoId: insertedId, total: Math.round(total * 100) / 100 };
}

async function criarPedido(pedido) {
  if (!usarTransacao) {
    // Standalone: cada $inc condicional e atomico (sem overselling); se um
    // item falhar, devolve ao estoque o que ja foi baixado (compensacao)
    const baixados = [];
    try {
      return await registrarPedido(pedido, undefined, baixados);
    } catch (erro) {
      for (const { sku, qtd } of baixados) {
        await db.collection("produtos").updateOne({ sku }, { $inc: { estoque: qtd } });
      }
      throw erro;
    }
  }
  const sessao = cliente.startSession();
  try {
    // withTransaction repete automaticamente em caso de erro transitorio
    return await sessao.withTransaction(() => registrarPedido(pedido, sessao));
  } finally {
    await sessao.endSession();
  }
}

async function relatorioCategorias() {
  return db
    .collection("pedidos")
    .aggregate([
      { $unwind: "$itens" },
      { $lookup: { from: "produtos", localField: "itens.sku", foreignField: "sku", as: "p" } },
      { $unwind: "$p" },
      { $group: { _id: "$p.categoria", faturamento: { $sum: "$itens.subtotal" } } },
      { $sort: { faturamento: -1 } },
    ])
    .toArray();
}

// ---------------------------------------------------------------------------
// Camada HTTP
// ---------------------------------------------------------------------------
function responder(res, status, corpo) {
  res.writeHead(status, { "Content-Type": "application/json; charset=utf-8" });
  res.end(JSON.stringify(corpo, null, 2));
}

function lerCorpo(req) {
  return new Promise((resolve, reject) => {
    let dados = "";
    req.on("data", (parte) => (dados += parte));
    req.on("end", () => {
      try {
        resolve(dados ? JSON.parse(dados) : {});
      } catch (e) {
        reject(e);
      }
    });
  });
}

const servidor = http.createServer(async (req, res) => {
  const url = new URL(req.url, `http://localhost:${PORTA}`);
  const params = Object.fromEntries(url.searchParams);
  try {
    if (req.method === "GET" && url.pathname === "/produtos") {
      return responder(res, 200, await listarProdutos(params));
    }
    if (req.method === "GET" && url.pathname.startsWith("/produtos/")) {
      const produto = await buscarPorSku(url.pathname.split("/")[2]);
      return produto ? responder(res, 200, produto) : responder(res, 404, { erro: "nao encontrado" });
    }
    if (req.method === "GET" && url.pathname === "/busca") {
      return responder(res, 200, await buscaTextual(params.q || ""));
    }
    if (req.method === "POST" && url.pathname === "/pedidos") {
      return responder(res, 201, await criarPedido(await lerCorpo(req)));
    }
    if (req.method === "GET" && url.pathname === "/relatorios/categorias") {
      return responder(res, 200, await relatorioCategorias());
    }
    responder(res, 404, { erro: "rota inexistente" });
  } catch (erro) {
    responder(res, 422, { erro: erro.message });
  }
});

async function chamadasDeTeste() {
  const base = `http://localhost:${PORTA}`;
  const chamar = async (metodo, caminho, corpo) => {
    const r = await fetch(base + caminho, {
      method: metodo,
      headers: { "Content-Type": "application/json" },
      body: corpo ? JSON.stringify(corpo) : undefined,
    });
    console.log(`\n${metodo} ${caminho} -> ${r.status}`);
    console.log(JSON.stringify(await r.json()));
  };
  await chamar("GET", "/produtos?categoria=notebook&maxPreco=9000");
  await chamar("GET", "/produtos/LIV-0002");
  await chamar("GET", "/busca?q=mongodb");
  await chamar("POST", "/pedidos", { clienteId: "cli-carla", itens: [{ sku: "LIV-0002", qtd: 1 }] });
  await chamar("POST", "/pedidos", { clienteId: "cli-carla", itens: [{ sku: "SMA-0002", qtd: 1 }] });
  await chamar("GET", "/relatorios/categorias");
}

async function main() {
  await cliente.connect();
  // Transacoes multi-documento exigem replica set (ou sharding)
  const hello = await cliente.db("admin").command({ hello: 1 });
  usarTransacao = Boolean(hello.setName) || hello.msg === "isdbgrid";
  servidor.listen(PORTA, async () => {
    console.log(`API TechStore ouvindo em http://localhost:${PORTA} | transacoes: ` +
      (usarTransacao ? "SIM (replica set)" : "NAO (standalone) -> compensacao"));
    if (process.argv.includes("--teste")) {
      await chamadasDeTeste();
      servidor.close();
      await cliente.close();
    }
  });
}

main().catch((erro) => {
  console.error("Erro ao iniciar a API:", erro.message);
  process.exit(1);
});
