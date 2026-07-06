--------------------------------------------------------------------------------
-- BD1101-DDLAvancado.sql
-- Aula 11 - UA4: DDL Avancado - Views, Schemas e Particionamento Inicial
-- SGBD: PostgreSQL 15 ou superior
-- Pre-requisito: repository/class10/postgresql/BD1001-DDL.sql (esquema BookHub)
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

-- 1.4 View atualizavel com CHECK OPTION: somente clientes ativos
-- (INSERT/UPDATE que violem a clausula WHERE sao rejeitados pelo PostgreSQL)
CREATE OR REPLACE VIEW vw_cliente_ativo AS
SELECT cliente_id, nome, email, data_cadastro, ativo
FROM Cliente
WHERE ativo = 'S'
WITH LOCAL CHECK OPTION;

-- ============================================================================
-- 2. SCHEMAS - namespaces para organizar objetos (o PostgreSQL nao tem SYNONYM;
--    a organizacao por SCHEMA cumpre um papel equivalente na pratica)
-- ============================================================================

-- 2.1 Criando um schema dedicado a relatorios gerenciais
CREATE SCHEMA IF NOT EXISTS relatorios;

-- 2.2 Movendo (ou recriando) uma view dentro do novo schema
CREATE OR REPLACE VIEW relatorios.vw_resumo_vendas_categoria AS
SELECT * FROM public.vw_resumo_vendas_categoria;

-- 2.3 Ajustando o search_path da sessao para acessar objetos sem qualificar o schema
-- SET search_path TO relatorios, public;
-- SELECT * FROM vw_resumo_vendas_categoria;  -- resolvido em relatorios, depois public

-- 2.4 Controlando privilegios por schema (organizacao multiusuario)
-- GRANT USAGE ON SCHEMA relatorios TO leitor_relatorios;
-- GRANT SELECT ON ALL TABLES IN SCHEMA relatorios TO leitor_relatorios;

-- 2.5 Removendo um schema (CASCADE remove os objetos dentro dele)
-- DROP SCHEMA relatorios CASCADE;

-- ============================================================================
-- 3. PARTICIONAMENTO DECLARATIVO - Venda particionada por RANGE (data_venda)
-- ============================================================================

-- 3.1 Recriando Venda como tabela particionada (particionamento e definido na
--     criacao da tabela; para tabela existente e preciso migrar os dados)
DROP TABLE IF EXISTS Venda CASCADE;

CREATE TABLE Venda (
    venda_id          INTEGER        GENERATED ALWAYS AS IDENTITY,
    cliente_id        INTEGER        NOT NULL,
    data_venda        DATE           NOT NULL DEFAULT CURRENT_DATE,
    forma_pagamento   VARCHAR(30)    NOT NULL,
    valor_total       NUMERIC(10,2)  NOT NULL,
    CONSTRAINT venda_pk PRIMARY KEY (venda_id, data_venda),
    CONSTRAINT venda_cliente_fk FOREIGN KEY (cliente_id)
        REFERENCES Cliente (cliente_id),
    CONSTRAINT venda_valor_ck CHECK (valor_total >= 0)
)
PARTITION BY RANGE (data_venda);
-- Observacao: no particionamento declarativo do PostgreSQL, a chave de
-- particionamento (data_venda) precisa fazer parte de toda UNIQUE/PK da tabela
-- particionada - por isso venda_pk aqui e composta (venda_id, data_venda).

-- 3.2 Criando as particoes filhas, uma faixa por ano
CREATE TABLE Venda_ate_2024 PARTITION OF Venda
    FOR VALUES FROM (MINVALUE) TO ('2025-01-01');

CREATE TABLE Venda_2025 PARTITION OF Venda
    FOR VALUES FROM ('2025-01-01') TO ('2026-01-01');

-- Particao "coringa" para datas fora do intervalo mapeado (evita erro de insert)
CREATE TABLE Venda_futuro PARTITION OF Venda DEFAULT;

-- ItemVenda recriada apos a recriacao de Venda (a FK depende da PK de Venda)
DROP TABLE IF EXISTS ItemVenda CASCADE;

CREATE TABLE ItemVenda (
    itemvenda_id     INTEGER        GENERATED ALWAYS AS IDENTITY,
    venda_id         INTEGER        NOT NULL,
    data_venda       DATE           NOT NULL,
    livro_id         INTEGER        NOT NULL,
    quantidade       INTEGER        NOT NULL,
    preco_unitario   NUMERIC(10,2)  NOT NULL,
    CONSTRAINT itemvenda_pk PRIMARY KEY (itemvenda_id),
    CONSTRAINT itemvenda_venda_fk FOREIGN KEY (venda_id, data_venda)
        REFERENCES Venda (venda_id, data_venda) ON DELETE CASCADE,
    CONSTRAINT itemvenda_livro_fk FOREIGN KEY (livro_id)
        REFERENCES Livro (livro_id),
    CONSTRAINT itemvenda_qtd_ck CHECK (quantidade > 0)
);

-- 3.3 Consultando o catalogo para ver as particoes criadas
SELECT
    parent.relname  AS tabela_particionada,
    child.relname   AS particao,
    pg_get_expr(child.relpartbound, child.oid) AS faixa
FROM pg_inherits
JOIN pg_class parent ON parent.oid = pg_inherits.inhparent
JOIN pg_class child  ON child.oid = pg_inherits.inhrelid
WHERE parent.relname = 'venda';

-- 3.4 Manutencao de particoes (comandos de referencia)
-- CREATE TABLE Venda_2027 PARTITION OF Venda FOR VALUES FROM ('2027-01-01') TO ('2028-01-01');
-- ALTER TABLE Venda DETACH PARTITION Venda_ate_2024;   -- desanexa sem apagar os dados
-- DROP TABLE Venda_ate_2024;                            -- descarta dados antigos

-- 3.5 Consulta que se beneficia de partition pruning (PostgreSQL le so Venda_2025)
-- EXPLAIN ANALYZE
-- SELECT * FROM Venda WHERE data_venda BETWEEN '2025-01-01' AND '2025-12-31';
