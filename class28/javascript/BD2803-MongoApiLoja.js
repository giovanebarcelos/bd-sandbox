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
 *   npm install            (usa o package.json desta pasta)
 *   MongoDB em replica set e base populada (rode antes o BD2803 em Python)
 *
 * Execucao:
 *   node BD2803-MongoApiLoja.js          # sobe a API na porta 3000
 *   node BD2803-MongoApiLoja.js --teste  # sobe, faz chamadas de teste e encerra
 */

const http = require("node:http");
const { MongoClient } = require("mongodb");

const MONGO_URI = "mongodb://localhost:27017/?replicaSet=rs0&directConnection=true";
const PORTA = 3000;
const TAMANHO_PAGINA = 3;

const cliente = new MongoClient(MONGO_URI, { serverSelectionTimeoutMS: 5000 });
const db = cliente.db("techstore");

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

async function criarPedido({ clienteId, itens }) {
  const sessao = cliente.startSession();
  try {
    // withTransaction repete automaticamente em caso de erro transitorio
    return await sessao.withTransaction(async () => {
      const linhas = [];
      let total = 0;
      for (const { sku, qtd } of itens) {
        const produto = await db.collection("produtos").findOneAndUpdate(
          { sku, estoque: { $gte: qtd } },
          { $inc: { estoque: -qtd } },
          { session: sessao, returnDocument: "after", projection: { _id: 0, nome: 1, preco: 1 } }
        );
        if (!produto) throw new Error(`Estoque insuficiente para ${sku}`);
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
    });
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
  servidor.listen(PORTA, async () => {
    console.log(`API TechStore ouvindo em http://localhost:${PORTA}`);
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
