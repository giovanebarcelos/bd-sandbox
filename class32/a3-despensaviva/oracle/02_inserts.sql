-- DespensaViva · Oracle · 02_inserts.sql
-- Dados DETERMINÍSTICOS: todas as datas são relativas a hoje (TRUNC(SYSDATE)), então as consultas dão o mesmo resultado em qualquer dia.
-- Saldos conferem: quantidade_atual = quantidade_inicial - soma dos CONSUMOS do lote. Nenhum dado pessoal real.

INSERT INTO categoria (categoria_id, nome) VALUES (1, 'Grãos');
INSERT INTO categoria (categoria_id, nome) VALUES (2, 'Hortifrúti');
INSERT INTO categoria (categoria_id, nome) VALUES (3, 'Laticínios');
INSERT INTO categoria (categoria_id, nome) VALUES (4, 'Temperos');

INSERT INTO fornecedor (fornecedor_id, nome, tipo) VALUES (1, 'Banco de Alimentos Central', 'DOADOR');
INSERT INTO fornecedor (fornecedor_id, nome, tipo) VALUES (2, 'Feira do Produtor',          'COMERCIO');
INSERT INTO fornecedor (fornecedor_id, nome, tipo) VALUES (3, 'Padaria Solidária',          'DOADOR');
INSERT INTO fornecedor (fornecedor_id, nome, tipo) VALUES (4, 'Mercado Bom Preço',          'COMERCIO');

INSERT INTO insumo (insumo_id, nome, unidade, estoque_minimo, categoria_id) VALUES (1, 'Arroz',            'KG', 20, 1);
INSERT INTO insumo (insumo_id, nome, unidade, estoque_minimo, categoria_id) VALUES (2, 'Feijão',           'KG', 15, 1);
INSERT INTO insumo (insumo_id, nome, unidade, estoque_minimo, categoria_id) VALUES (3, 'Tomate',           'KG', 10, 2);
INSERT INTO insumo (insumo_id, nome, unidade, estoque_minimo, categoria_id) VALUES (4, 'Cebola',           'KG',  8, 2);
INSERT INTO insumo (insumo_id, nome, unidade, estoque_minimo, categoria_id) VALUES (5, 'Leite',            'L',  12, 3);
INSERT INTO insumo (insumo_id, nome, unidade, estoque_minimo, categoria_id) VALUES (6, 'Sal',              'KG',  2, 4);
INSERT INTO insumo (insumo_id, nome, unidade, estoque_minimo, categoria_id) VALUES (7, 'Alho',             'KG',  3, 4);
INSERT INTO insumo (insumo_id, nome, unidade, estoque_minimo, categoria_id) VALUES (8, 'Farinha de trigo', 'KG',  5, 1);

-- lote_id, insumo, fornecedor, inicial, atual, entrada, validade
INSERT INTO lote VALUES (1,  1, 1, 50, 38, TRUNC(SYSDATE) - 30, TRUNC(SYSDATE) + 150);
INSERT INTO lote VALUES (2,  1, 2, 30, 30, TRUNC(SYSDATE) - 5,  TRUNC(SYSDATE) + 200);
INSERT INTO lote VALUES (3,  2, 1, 40, 25, TRUNC(SYSDATE) - 25, TRUNC(SYSDATE) + 90);
INSERT INTO lote VALUES (4,  2, 4, 20, 20, TRUNC(SYSDATE) - 3,  TRUNC(SYSDATE) + 120);
-- vence em 2 dias
INSERT INTO lote VALUES (5,  3, 2, 15,  4, TRUNC(SYSDATE) - 10, TRUNC(SYSDATE) + 2);
-- vence em 7 dias (limite da janela de 7 dias da Q02)
INSERT INTO lote VALUES (6,  3, 2, 10, 10, TRUNC(SYSDATE) - 2,  TRUNC(SYSDATE) + 7);
INSERT INTO lote VALUES (7,  4, 2, 12,  7, TRUNC(SYSDATE) - 12, TRUNC(SYSDATE) + 20);
-- vence em 5 dias
INSERT INTO lote VALUES (8,  5, 3, 24,  6, TRUNC(SYSDATE) - 9,  TRUNC(SYSDATE) + 5);
INSERT INTO lote VALUES (9,  5, 4, 12, 12, TRUNC(SYSDATE) - 4,  TRUNC(SYSDATE) + 10);
INSERT INTO lote VALUES (10, 6, 4, 10,  5, TRUNC(SYSDATE) - 60, TRUNC(SYSDATE) + 400);
-- vence em 8 dias: logo FORA da janela de 7 dias da Q02
INSERT INTO lote VALUES (11, 7, 2,  3,  3, TRUNC(SYSDATE) - 6,  TRUNC(SYSDATE) + 8);
-- VENCIDO, com saldo
INSERT INTO lote VALUES (12, 8, 1, 10, 10, TRUNC(SYSDATE) - 40, TRUNC(SYSDATE) - 4);
-- VENCIDO, com saldo
INSERT INTO lote VALUES (13, 5, 3,  8,  8, TRUNC(SYSDATE) - 20, TRUNC(SYSDATE) - 2);

-- mov_id, lote, tipo, quantidade, data_hora, motivo  (entradas e consumos que explicam os saldos acima)
INSERT INTO movimentacao VALUES (1,  1,  'ENTRADA', 50, TRUNC(SYSDATE) - 30 + 8/24, 'Doação');
INSERT INTO movimentacao VALUES (2,  2,  'ENTRADA', 30, TRUNC(SYSDATE) - 5 + 8/24, 'Compra');
INSERT INTO movimentacao VALUES (3,  3,  'ENTRADA', 40, TRUNC(SYSDATE) - 25 + 8/24, 'Doação');
INSERT INTO movimentacao VALUES (4,  4,  'ENTRADA', 20, TRUNC(SYSDATE) - 3 + 8/24, 'Compra');
INSERT INTO movimentacao VALUES (5,  5,  'ENTRADA', 15, TRUNC(SYSDATE) - 10 + 8/24, 'Compra');
INSERT INTO movimentacao VALUES (6,  6,  'ENTRADA', 10, TRUNC(SYSDATE) - 2 + 8/24, 'Compra');
INSERT INTO movimentacao VALUES (7,  7,  'ENTRADA', 12, TRUNC(SYSDATE) - 12 + 8/24, 'Compra');
INSERT INTO movimentacao VALUES (8,  8,  'ENTRADA', 24, TRUNC(SYSDATE) - 9 + 8/24, 'Doação');
INSERT INTO movimentacao VALUES (9,  9,  'ENTRADA', 12, TRUNC(SYSDATE) - 4 + 8/24, 'Compra');
INSERT INTO movimentacao VALUES (10, 10, 'ENTRADA', 10, TRUNC(SYSDATE) - 60 + 8/24, 'Compra');
INSERT INTO movimentacao VALUES (11, 11, 'ENTRADA',  3, TRUNC(SYSDATE) - 6 + 8/24, 'Compra');
INSERT INTO movimentacao VALUES (12, 12, 'ENTRADA', 10, TRUNC(SYSDATE) - 40 + 8/24, 'Doação');
INSERT INTO movimentacao VALUES (13, 13, 'ENTRADA',  8, TRUNC(SYSDATE) - 20 + 8/24, 'Doação');
INSERT INTO movimentacao VALUES (14, 1,  'CONSUMO',  5, TRUNC(SYSDATE) - 20 + 12/24, 'Almoço');
INSERT INTO movimentacao VALUES (15, 1,  'CONSUMO',  7, TRUNC(SYSDATE) - 8 + 12/24, 'Almoço');
INSERT INTO movimentacao VALUES (16, 3,  'CONSUMO', 10, TRUNC(SYSDATE) - 18 + 12/24, 'Almoço');
INSERT INTO movimentacao VALUES (17, 3,  'CONSUMO',  5, TRUNC(SYSDATE) - 6 + 12/24, 'Almoço');
INSERT INTO movimentacao VALUES (18, 5,  'CONSUMO',  6, TRUNC(SYSDATE) - 7 + 12/24, 'Sopa');
INSERT INTO movimentacao VALUES (19, 5,  'CONSUMO',  5, TRUNC(SYSDATE) - 3 + 12/24, 'Sopa');
INSERT INTO movimentacao VALUES (20, 7,  'CONSUMO',  5, TRUNC(SYSDATE) - 4 + 12/24, 'Almoço');
INSERT INTO movimentacao VALUES (21, 8,  'CONSUMO', 10, TRUNC(SYSDATE) - 6 + 9/24, 'Café da manhã');
INSERT INTO movimentacao VALUES (22, 8,  'CONSUMO',  8, TRUNC(SYSDATE) - 2 + 9/24, 'Café da manhã');
INSERT INTO movimentacao VALUES (23, 10, 'CONSUMO',  5, TRUNC(SYSDATE) - 30 + 12/24, 'Almoço');

INSERT INTO receita (receita_id, nome, porcoes) VALUES (1, 'Arroz e feijão', 10);
INSERT INTO receita (receita_id, nome, porcoes) VALUES (2, 'Sopa de tomate', 10);
INSERT INTO receita (receita_id, nome, porcoes) VALUES (3, 'Pão caseiro',    10);

INSERT INTO receita_insumo VALUES (1, 1, 0.080);
INSERT INTO receita_insumo VALUES (1, 2, 0.060);
INSERT INTO receita_insumo VALUES (1, 4, 0.010);
INSERT INTO receita_insumo VALUES (2, 3, 0.290);
INSERT INTO receita_insumo VALUES (2, 4, 0.020);
INSERT INTO receita_insumo VALUES (2, 6, 0.003);
INSERT INTO receita_insumo VALUES (2, 5, 0.050);
INSERT INTO receita_insumo VALUES (3, 8, 0.100);
INSERT INTO receita_insumo VALUES (3, 5, 0.040);
INSERT INTO receita_insumo VALUES (3, 6, 0.002);

-- Os ids foram informados à mão: reinicia cada identidade depois do maior id, para os próximos INSERTs não colidirem.
ALTER TABLE categoria    MODIFY categoria_id  GENERATED BY DEFAULT AS IDENTITY (START WITH LIMIT VALUE);
ALTER TABLE fornecedor   MODIFY fornecedor_id GENERATED BY DEFAULT AS IDENTITY (START WITH LIMIT VALUE);
ALTER TABLE insumo       MODIFY insumo_id     GENERATED BY DEFAULT AS IDENTITY (START WITH LIMIT VALUE);
ALTER TABLE lote         MODIFY lote_id       GENERATED BY DEFAULT AS IDENTITY (START WITH LIMIT VALUE);
ALTER TABLE movimentacao MODIFY mov_id        GENERATED BY DEFAULT AS IDENTITY (START WITH LIMIT VALUE);
ALTER TABLE receita      MODIFY receita_id    GENERATED BY DEFAULT AS IDENTITY (START WITH LIMIT VALUE);
COMMIT;
