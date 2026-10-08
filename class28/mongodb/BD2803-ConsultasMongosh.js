// ============================================================================
// BD2803 - Roteiro de comandos mongosh (Aula 28A - MongoDB em Profundidade)
// Prof. Giovane Barcelos
//
// Pre-requisito: rodar BD2803-MongoLojaVirtual.py (popula a base techstore)
// Execucao:  docker exec -i bd28-mongo mongosh techstore < BD2803-ConsultasMongosh.js
//      ou    docker exec -it bd28-mongo mongosh techstore   (e cole linha a linha)
// ============================================================================

// --- READ: filtros, projecao, ordenacao
db.produtos.find({ categoria: "notebook" }, { _id: 0, nome: 1, preco: 1 }).sort({ preco: -1 });
db.produtos.find({ "specs.ram_gb": { $gte: 16 } }, { _id: 0, nome: 1, "specs.ram_gb": 1 });
db.produtos.find({ tags: { $in: ["nosql", "gamer"] } }, { _id: 0, nome: 1, tags: 1 });
db.produtos.find({ autores: { $size: 3 } }, { _id: 0, nome: 1 });
db.produtos.countDocuments({ estoque: 0 });

// --- UPDATE
db.produtos.updateOne({ sku: "SMA-0002" }, { $set: { estoque: 15 }, $currentDate: { atualizado_em: true } });
db.produtos.updateMany({ categoria: "smartphone" }, { $addToSet: { tags: "promocao" } });

// --- AGGREGATE: ticket medio por cliente
db.pedidos.aggregate([
  { $group: { _id: "$cliente_id", pedidos: { $sum: 1 }, ticket_medio: { $avg: "$total" } } },
  { $lookup: { from: "clientes", localField: "_id", foreignField: "_id", as: "cli" } },
  { $project: { _id: 0, cliente: { $first: "$cli.nome" }, pedidos: 1, ticket_medio: { $round: ["$ticket_medio", 2] } } },
  { $sort: { ticket_medio: -1 } }
]);

// --- Plano de execucao: IXSCAN (usa indice) x COLLSCAN (varre tudo)
db.produtos.find({ categoria: "livro", preco: { $lt: 300 } }).explain("executionStats").executionStats;
db.produtos.find({ nome: /Gamer/ }).explain().queryPlanner.winningPlan;

// --- Indices existentes e validador da colecao
db.produtos.getIndexes();
db.getCollectionInfos({ name: "produtos" })[0].options.validator;
