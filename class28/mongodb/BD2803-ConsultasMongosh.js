// ============================================================================
// BD2803 - Roteiro de comandos mongosh (Aula 28A - MongoDB em Profundidade)
// Prof. Giovane Barcelos
//
// Roteiro AUTOSSUFICIENTE: a secao 0 recria a base techstore (mesmos dados do
// BD2803-MongoLojaVirtual.py), entao nao e preciso rodar o Python antes.
//
// Execucao (container "mongodb" do curso - usuario admin / senha mongodb):
//   docker exec -i mongodb mongosh -u admin -p mongodb --authenticationDatabase admin techstore < BD2803-ConsultasMongosh.js
//   docker exec -it mongodb mongosh -u admin -p mongodb --authenticationDatabase admin techstore   (cole bloco a bloco)
// Container "bd28-mongo" da Aula 28 (sem senha):
//   docker exec -i bd28-mongo mongosh techstore < BD2803-ConsultasMongosh.js
// PowerShell nao aceita "<": use  Get-Content BD2803-ConsultasMongosh.js | docker exec -i mongodb mongosh ...
// ============================================================================

// --- 0. CARGA: colecoes, validador e dados de exemplo
db.produtos.drop();
db.pedidos.drop();
db.clientes.drop();

db.createCollection("produtos", {
  validator: {
    $jsonSchema: {
      bsonType: "object",
      required: ["sku", "nome", "categoria", "preco", "estoque"],
      properties: {
        sku: { bsonType: "string", pattern: "^[A-Z]{3}-[0-9]{4}$" },
        nome: { bsonType: "string", minLength: 3 },
        categoria: { enum: ["notebook", "smartphone", "livro"] },
        preco: { bsonType: ["double", "int", "decimal"], minimum: 0 },
        estoque: { bsonType: "int", minimum: 0 },
        tags: { bsonType: "array", items: { bsonType: "string" } }
      }
    }
  },
  validationLevel: "strict",
  validationAction: "error"
});

db.produtos.insertMany([
  { sku: "NTB-0001", nome: "Notebook Pro 14", categoria: "notebook",
    preco: 7899.90, estoque: 11, tags: ["ultrafino", "trabalho"],
    specs: { cpu: "Ryzen 7 7840U", ram_gb: 16, ssd_gb: 512, tela: 14.0 }, avaliacoes: [] },
  { sku: "NTB-0002", nome: "Notebook Gamer X", categoria: "notebook",
    preco: 9499.00, estoque: 1, tags: ["gamer", "rtx"],
    specs: { cpu: "Core i7 13700H", ram_gb: 32, ssd_gb: 1024, gpu: "RTX 4060", tela: 15.6 }, avaliacoes: [] },
  { sku: "SMA-0001", nome: "Smartphone Z5", categoria: "smartphone",
    preco: 2999.00, estoque: 37, tags: ["5g", "camera"],
    specs: { armazenamento_gb: 256, cores: ["preto", "azul"], nfc: true }, avaliacoes: [] },
  { sku: "SMA-0002", nome: "Smartphone Lite A", categoria: "smartphone",
    preco: 1299.00, estoque: 0, tags: ["entrada"],
    specs: { armazenamento_gb: 128, cores: ["branco"], nfc: false }, avaliacoes: [] },
  { sku: "LIV-0001", nome: "Sistemas de Banco de Dados", categoria: "livro",
    preco: 289.90, estoque: 22, tags: ["sql", "modelagem", "nosql"],
    isbn: "978-8543025001", autores: ["Elmasri", "Navathe"], paginas: 1152, avaliacoes: [] },
  { sku: "LIV-0002", nome: "MongoDB: The Definitive Guide", categoria: "livro",
    preco: 249.00, estoque: 6, tags: ["nosql", "mongodb"],
    isbn: "978-1491954461", autores: ["Bradshaw", "Brazil", "Chodorow"], paginas: 514, avaliacoes: [] }
]);

db.clientes.insertMany([
  { _id: "cli-ana", nome: "Ana Ribeiro", email: "ana@email.com",
    endereco: { cidade: "Porto Alegre", uf: "RS", cep: "90010-000" } },
  { _id: "cli-bruno", nome: "Bruno Costa", email: "bruno@email.com",
    endereco: { cidade: "Canoas", uf: "RS", cep: "92010-000" } },
  { _id: "cli-carla", nome: "Carla Mendes", email: "carla@email.com",
    endereco: { cidade: "Florianopolis", uf: "SC", cep: "88010-000" } }
]);

// Pedidos ja "fechados": itens embutidos + copia do endereco (estoques acima ja descontados)
const agora = new Date();
const mesPassado = new Date(agora.getTime() - 35 * 24 * 60 * 60 * 1000);
db.pedidos.insertMany([
  { cliente_id: "cli-ana", entrega: { cidade: "Porto Alegre", uf: "RS", cep: "90010-000" },
    itens: [
      { sku: "NTB-0001", nome: "Notebook Pro 14", qtd: 1, preco_unit: 7899.90, subtotal: 7899.90 },
      { sku: "LIV-0001", nome: "Sistemas de Banco de Dados", qtd: 2, preco_unit: 289.90, subtotal: 579.80 }],
    total: 8479.70, status: "PAGO", criado_em: agora },
  { cliente_id: "cli-bruno", entrega: { cidade: "Canoas", uf: "RS", cep: "92010-000" },
    itens: [
      { sku: "SMA-0001", nome: "Smartphone Z5", qtd: 2, preco_unit: 2999.00, subtotal: 5998.00 }],
    total: 5998.00, status: "PAGO", criado_em: mesPassado },
  { cliente_id: "cli-carla", entrega: { cidade: "Florianopolis", uf: "SC", cep: "88010-000" },
    itens: [
      { sku: "LIV-0002", nome: "MongoDB: The Definitive Guide", qtd: 1, preco_unit: 249.00, subtotal: 249.00 },
      { sku: "LIV-0001", nome: "Sistemas de Banco de Dados", qtd: 1, preco_unit: 289.90, subtotal: 289.90 },
      { sku: "SMA-0001", nome: "Smartphone Z5", qtd: 1, preco_unit: 2999.00, subtotal: 2999.00 }],
    total: 3537.90, status: "PAGO", criado_em: agora },
  { cliente_id: "cli-bruno", entrega: { cidade: "Canoas", uf: "RS", cep: "92010-000" },
    itens: [
      { sku: "NTB-0002", nome: "Notebook Gamer X", qtd: 2, preco_unit: 9499.00, subtotal: 18998.00 },
      { sku: "LIV-0002", nome: "MongoDB: The Definitive Guide", qtd: 1, preco_unit: 249.00, subtotal: 249.00 }],
    total: 19247.00, status: "PAGO", criado_em: mesPassado }
]);

db.produtos.createIndex({ sku: 1 }, { unique: true, name: "ux_sku" });
db.produtos.createIndex({ categoria: 1, preco: 1 }, { name: "ix_categoria_preco" });
db.produtos.createIndex({ tags: 1 }, { name: "ix_tags_multikey" });
db.produtos.createIndex({ nome: "text", tags: "text" }, { default_language: "portuguese", name: "ix_texto" });
print(`Carga: ${db.produtos.countDocuments()} produtos, ${db.clientes.countDocuments()} clientes, ${db.pedidos.countDocuments()} pedidos`);

// --- 1. CRUD do Slide 14 (SQL x mongosh)
db.produtos.insertOne({ sku: "TST-0001", nome: "Produto Teste", categoria: "livro", preco: 10.0, estoque: 0 });
db.produtos.find({ categoria: "livro" }, { _id: 0, nome: 1, preco: 1 });
db.produtos.find({}, { _id: 0, nome: 1, preco: 1 }).sort({ preco: -1 }).limit(5);
db.produtos.countDocuments({ estoque: 0 });                                   // 2 (SMA-0002 e TST-0001)
db.produtos.updateOne({ sku: "TST-0001" }, { $set: { estoque: 15 } });
db.produtos.updateOne({ sku: "TST-0002" },                                    // nao existe -> insere
  { $set: { nome: "Outro Teste", categoria: "livro", preco: 20.0, estoque: 0 } }, { upsert: true });
db.produtos.deleteMany({ sku: { $in: ["TST-0001", "TST-0002"] } });

// A validacao em acao: sem 'estoque' e com SKU fora do padrao -> "Document failed validation"
try {
  db.produtos.insertOne({ sku: "x1", nome: "Produto invalido", categoria: "notebook", preco: 10.0 });
} catch (e) { print("Validacao bloqueou:", e.errmsg ?? e.message); }

// --- 2. READ: filtros, projecao, ordenacao
db.produtos.find({ categoria: "notebook" }, { _id: 0, nome: 1, preco: 1 }).sort({ preco: -1 });
db.produtos.find({ "specs.ram_gb": { $gte: 16 } }, { _id: 0, nome: 1, "specs.ram_gb": 1 });
db.produtos.find({ tags: { $in: ["nosql", "gamer"] } }, { _id: 0, nome: 1, tags: 1 });
db.produtos.find({ autores: { $size: 3 } }, { _id: 0, nome: 1 });
db.produtos.find({ $or: [{ tags: "nosql" }, { preco: { $lt: 1500 } }], estoque: { $gt: 0 } }, { _id: 0, sku: 1, nome: 1 });
db.produtos.find({ $text: { $search: "banco dados" } }, { _id: 0, nome: 1, score: { $meta: "textScore" } }).sort({ score: { $meta: "textScore" } });
db.pedidos.find({ itens: { $elemMatch: { sku: "LIV-0001", qtd: { $gte: 2 } } } }, { _id: 0, cliente_id: 1, total: 1 });
db.produtos.countDocuments({ estoque: 0 });

// --- 3. UPDATE
db.produtos.updateOne({ sku: "SMA-0002" }, { $set: { estoque: 15 }, $currentDate: { atualizado_em: true } });
db.produtos.updateMany({ categoria: "smartphone" }, { $addToSet: { tags: "promocao" } });
db.produtos.updateOne({ sku: "SMA-0002" }, { $set: { estoque: 0 } });   // volta a 0: a API (Slide 28) testa o 422 nele

// --- 4. AGGREGATE: ticket medio por cliente
db.pedidos.aggregate([
  { $group: { _id: "$cliente_id", pedidos: { $sum: 1 }, ticket_medio: { $avg: "$total" } } },
  { $lookup: { from: "clientes", localField: "_id", foreignField: "_id", as: "cli" } },
  { $project: { _id: 0, cliente: { $first: "$cli.nome" }, pedidos: 1, ticket_medio: { $round: ["$ticket_medio", 2] } } },
  { $sort: { ticket_medio: -1 } }
]);

// --- 5. Plano de execucao: IXSCAN (usa indice) x COLLSCAN (varre tudo)
db.produtos.find({ categoria: "livro", preco: { $lt: 300 } }).explain("executionStats").executionStats;
db.produtos.find({ nome: /Gamer/ }).explain().queryPlanner.winningPlan;

// --- 6. Indices existentes e validador da colecao
db.produtos.getIndexes();
db.getCollectionInfos({ name: "produtos" })[0].options.validator;
