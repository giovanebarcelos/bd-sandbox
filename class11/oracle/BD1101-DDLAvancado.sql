--------------------------------------------------------------------------------
-- BD1101-DDLAvancado.sql
-- Aula 11 - UA4: DDL Avancado - Views, Sinonimos e Particionamento Inicial
-- SGBD: Oracle Database (XE 21c ou superior)
-- Pre-requisito: repository/class10/oracle/BD1001-DDL.sql (esquema BookHub)
--------------------------------------------------------------------------------

-- ============================================================================
-- 1. VIEWS - simplificando consultas recorrentes e controlando exposicao
-- ============================================================================

-- 1.1 View somente leitura: catalogo de livros com nome de autor/editora/categoria
CREATE OR REPLACE VIEW vw_livro_catalogo AS
SELECT
    l.livro_id,
    l.titulo,
    a.nome        AS autor,
    ed.nome       AS editora,
    c.nome        AS categoria,
    l.preco,
    l.ano_publicacao,
    l.tipo
FROM Livro l
JOIN Autor a     ON a.autor_id = l.autor_id
JOIN Editora ed  ON ed.editora_id = l.editora_id
JOIN Categoria c ON c.categoria_id = l.categoria_id;

-- 1.2 View de vendas detalhadas (junta Venda + ItemVenda + Livro + Cliente)
CREATE OR REPLACE VIEW vw_venda_detalhada AS
SELECT
    v.venda_id,
    v.data_venda,
    cl.nome         AS cliente,
    v.forma_pagamento,
    l.titulo        AS livro,
    iv.quantidade,
    iv.preco_unitario,
    (iv.quantidade * iv.preco_unitario) AS subtotal
FROM Venda v
JOIN Cliente cl    ON cl.cliente_id = v.cliente_id
JOIN ItemVenda iv  ON iv.venda_id = v.venda_id
JOIN Livro l       ON l.livro_id = iv.livro_id;

-- 1.3 View agregada: total vendido por categoria (base para relatorios gerenciais)
CREATE OR REPLACE VIEW vw_resumo_vendas_categoria AS
SELECT
    c.nome AS categoria,
    COUNT(DISTINCT v.venda_id) AS qtd_vendas,
    SUM(iv.quantidade)         AS qtd_livros_vendidos,
    SUM(iv.quantidade * iv.preco_unitario) AS receita_total
FROM Categoria c
JOIN Livro l      ON l.categoria_id = c.categoria_id
JOIN ItemVenda iv ON iv.livro_id = l.livro_id
JOIN Venda v      ON v.venda_id = iv.venda_id
GROUP BY c.nome;

-- 1.4 View atualizavel com WITH CHECK OPTION: somente clientes ativos
-- (INSERT/UPDATE que violem a clausula WHERE sao rejeitados pelo Oracle)
CREATE OR REPLACE VIEW vw_cliente_ativo AS
SELECT cliente_id, nome, email, data_cadastro, ativo
FROM Cliente
WHERE ativo = 'S'
WITH CHECK OPTION CONSTRAINT vw_cliente_ativo_cc;

-- ============================================================================
-- 2. SYNONYMS - apelidos para simplificar acesso a objetos
-- ============================================================================

-- 2.1 Sinonimo privado: encurta o nome de uma view usada com frequencia
CREATE SYNONYM livros FOR vw_livro_catalogo;
-- Uso: SELECT * FROM livros;  (equivale a SELECT * FROM vw_livro_catalogo;)

-- 2.2 Sinonimo privado apontando para tabela em outro schema (cenario multiusuario)
-- CREATE SYNONYM vendas_bookhub FOR bookhub_app.Venda;

-- 2.3 Sinonimo publico: visivel para todos os usuarios do banco
-- (requer privilegio CREATE PUBLIC SYNONYM; tipicamente usado por DBA)
-- CREATE PUBLIC SYNONYM relatorio_vendas FOR vw_resumo_vendas_categoria;

-- 2.4 Remocao de sinonimo
-- DROP SYNONYM livros;
-- DROP PUBLIC SYNONYM relatorio_vendas;

-- ============================================================================
-- 3. PARTICIONAMENTO - Venda particionada por RANGE (data_venda), ganho de
--    performance em tabelas de fato que crescem continuamente (fact-like).
-- ============================================================================

-- 3.1 Recriando Venda como tabela particionada (didatico: em producao usar
--     DBMS_REDEFINITION para particionar uma tabela ja existente sem downtime)
DROP TABLE Venda CASCADE CONSTRAINTS PURGE;

CREATE TABLE Venda (
    venda_id          NUMBER         DEFAULT venda_id_seq.NEXTVAL NOT NULL,
    cliente_id        NUMBER         NOT NULL,
    data_venda        DATE           DEFAULT SYSDATE NOT NULL,
    forma_pagamento   VARCHAR2(30)   NOT NULL,
    valor_total       NUMBER(10,2)   NOT NULL,
    CONSTRAINT venda_pk PRIMARY KEY (venda_id),
    CONSTRAINT venda_cliente_fk FOREIGN KEY (cliente_id)
        REFERENCES Cliente (cliente_id),
    CONSTRAINT venda_valor_ck CHECK (valor_total >= 0)
)
PARTITION BY RANGE (data_venda)
INTERVAL (NUMTOYMINTERVAL(1, 'YEAR'))  -- Oracle cria automaticamente novas
                                        -- particoes anuais conforme os dados chegam
(
    PARTITION p_ate_2024 VALUES LESS THAN (DATE '2025-01-01'),
    PARTITION p_2025     VALUES LESS THAN (DATE '2026-01-01')
);

-- ItemVenda recriada apos a recriacao de Venda (a FK depende da PK de Venda)
DROP TABLE ItemVenda CASCADE CONSTRAINTS PURGE;

CREATE TABLE ItemVenda (
    itemvenda_id     NUMBER         DEFAULT itemvenda_id_seq.NEXTVAL NOT NULL,
    venda_id         NUMBER         NOT NULL,
    livro_id         NUMBER         NOT NULL,
    quantidade       NUMBER(6)      NOT NULL,
    preco_unitario   NUMBER(10,2)   NOT NULL,
    CONSTRAINT itemvenda_pk PRIMARY KEY (itemvenda_id),
    CONSTRAINT itemvenda_venda_fk FOREIGN KEY (venda_id)
        REFERENCES Venda (venda_id) ON DELETE CASCADE,
    CONSTRAINT itemvenda_livro_fk FOREIGN KEY (livro_id)
        REFERENCES Livro (livro_id),
    CONSTRAINT itemvenda_qtd_ck CHECK (quantidade > 0)
);

-- 3.2 Consultando o dicionario de dados para ver as particoes criadas
SELECT partition_name, high_value
FROM user_tab_partitions
WHERE table_name = 'VENDA'
ORDER BY partition_position;

-- 3.3 Manutencao de particoes (comandos de referencia, nao executar em sequencia)
-- ALTER TABLE Venda ADD PARTITION p_2027 VALUES LESS THAN (DATE '2028-01-01');
-- ALTER TABLE Venda DROP PARTITION p_ate_2024;                -- descarta dados antigos
-- ALTER TABLE Venda MERGE PARTITIONS p_ate_2024, p_2025 INTO PARTITION p_historico;

-- 3.4 Consulta que se beneficia de partition pruning (Oracle le so a particao 2025)
-- SELECT * FROM Venda WHERE data_venda BETWEEN DATE '2025-01-01' AND DATE '2025-12-31';
