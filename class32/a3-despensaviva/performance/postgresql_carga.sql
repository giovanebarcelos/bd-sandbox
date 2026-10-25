-- DespensaViva · PostgreSQL · carga em massa para medir o efeito dos índices.
-- Roda num banco SEPARADO (despensa_perf), logo depois de postgresql/01_ddl.sql. NÃO cria os índices de 04_indices.sql.
-- 200.000 lotes em 1.000 insumos (200 lotes por insumo) e 400.000 movimentações.
INSERT INTO categoria (nome) VALUES ('Carga');
INSERT INTO fornecedor (nome, tipo) SELECT 'Fornecedor ' || g, CASE WHEN g % 2 = 0 THEN 'DOADOR' ELSE 'COMERCIO' END FROM generate_series(1, 4) g;
INSERT INTO insumo (nome, unidade, estoque_minimo, categoria_id) SELECT 'Insumo ' || g, 'KG', 10, 1 FROM generate_series(1, 1000) g;
INSERT INTO lote (insumo_id, fornecedor_id, quantidade_inicial, quantidade_atual, data_entrada, data_validade)
SELECT 1 + (g % 1000), 1 + (g % 4), 100, 1 + (g % 100), CURRENT_DATE - 30, CURRENT_DATE + (g % 365) - 10
  FROM generate_series(1, 200000) g;
INSERT INTO movimentacao (lote_id, tipo, quantidade)
SELECT 1 + (g % 200000), 'CONSUMO', 1 + (g % 5) FROM generate_series(1, 400000) g;
ANALYZE;
