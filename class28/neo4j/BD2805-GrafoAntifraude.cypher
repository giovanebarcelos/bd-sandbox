// ============================================================================
// BD2805 - Roteiro Cypher para o Neo4j Browser (Aula 28C - Neo4j em Profundidade)
// Prof. Giovane Barcelos
//
// Abra http://localhost:7474 (usuario neo4j / senha bd28senha123) e execute
// cada bloco separadamente. Pre-requisito: BD2805-Neo4jFraudeRecomendacao.py
// (ou rode o bloco de carga minima abaixo).
// ============================================================================

// --- Carga minima (se nao rodou o script Python)
MERGE (a:Cliente {id:'c10', nome:'Joao Silva'})
MERGE (b:Cliente {id:'c11', nome:'J. da Silva'})
MERGE (c:Cliente {id:'c12', nome:'Joana Silveira'})
MERGE (t:Telefone {numero:'11-98888-7777'})
MERGE (d:Dispositivo {id:'dev-QQQ'})
MERGE (a)-[:USA_TELEFONE]->(t)<-[:USA_TELEFONE]-(b)
MERGE (b)-[:USA_DISPOSITIVO]->(d)<-[:USA_DISPOSITIVO]-(c);

// --- 1. Ver o grafo inteiro (bom para turmas: o Browser desenha)
MATCH (n) RETURN n LIMIT 100;

// --- 2. Quem compartilha identificadores?
MATCH (c1:Cliente)-->(id)<--(c2:Cliente)
WHERE elementId(c1) < elementId(c2)
RETURN c1.nome, labels(id)[0] AS via, c2.nome;

// --- 3. Anel de fraude completo a partir de um cliente (ate 8 saltos)
MATCH p = (:Cliente {id:'c10'})-[:USA_TELEFONE|USA_DISPOSITIVO|ENTREGA_EM*1..8]-(:Cliente)
RETURN p;

// --- 4. Caminho mais curto
MATCH (a:Cliente {id:'c10'}), (b:Cliente {id:'c12'})
RETURN shortestPath((a)-[*]-(b)) AS caminho;

// --- 5. Grau (quantas contas usam cada identificador) - "hubs" suspeitos
MATCH (id)<--(c:Cliente)
WHERE id:Telefone OR id:Dispositivo OR id:Endereco
RETURN labels(id)[0] AS tipo, coalesce(id.numero, id.id, id.cep) AS valor, count(c) AS contas
ORDER BY contas DESC;

// --- 6. Recomendacao: quem comprou o mesmo que c02 tambem comprou...
MATCH (eu:Cliente {id:'c02'})-[:COMPROU]->(:Produto)<-[:COMPROU]-(viz)-[:COMPROU]->(rec:Produto)
WHERE NOT (eu)-[:COMPROU]->(rec)
RETURN rec.nome, count(DISTINCT viz) AS forca ORDER BY forca DESC;

// --- 7. Plano de execucao (troque PROFILE por EXPLAIN para nao executar)
PROFILE MATCH (c:Cliente {id:'c10'})-[:USA_TELEFONE]->(t) RETURN t;

// --- 8. Esquema
SHOW CONSTRAINTS;
SHOW INDEXES;
