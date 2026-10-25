-- DespensaViva · Oracle · carga em massa para medir o efeito dos índices.
-- Roda num esquema SEPARADO (despensa_perf), logo depois de oracle/01_ddl.sql. NÃO cria os índices de 04_indices.sql.
-- 200.000 lotes em 1.000 insumos (200 lotes por insumo) e 400.000 movimentações.
INSERT INTO categoria (nome) VALUES ('Carga');
INSERT INTO fornecedor (nome, tipo) SELECT 'Fornecedor ' || LEVEL, CASE WHEN MOD(LEVEL, 2) = 0 THEN 'DOADOR' ELSE 'COMERCIO' END FROM dual CONNECT BY LEVEL <= 4;
INSERT INTO insumo (nome, unidade, estoque_minimo, categoria_id) SELECT 'Insumo ' || LEVEL, 'KG', 10, 1 FROM dual CONNECT BY LEVEL <= 1000;
INSERT INTO lote (insumo_id, fornecedor_id, quantidade_inicial, quantidade_atual, data_entrada, data_validade)
SELECT 1 + MOD(LEVEL, 1000), 1 + MOD(LEVEL, 4), 100, 1 + MOD(LEVEL, 100), TRUNC(SYSDATE) - 30, TRUNC(SYSDATE) + MOD(LEVEL, 365) - 10
  FROM dual CONNECT BY LEVEL <= 200000;
INSERT INTO movimentacao (lote_id, tipo, quantidade)
SELECT 1 + MOD(LEVEL, 200000), 'CONSUMO', 1 + MOD(LEVEL, 5) FROM dual CONNECT BY LEVEL <= 400000;
COMMIT;
BEGIN DBMS_STATS.GATHER_SCHEMA_STATS(USER); END;
/
