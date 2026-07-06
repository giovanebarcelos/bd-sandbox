-- =============================================================================
-- BD1201-DML.sql
-- Aula 12 - DML: INSERT / UPDATE / DELETE / INSERT ... ON CONFLICT (PostgreSQL)
-- Estudo de caso: BookHub - livraria online
-- Prof. Giovane Barcelos
-- =============================================================================
-- Este script e autocontido: recria o esquema BookHub (6 tabelas), popula com
-- dados de exemplo e demonstra os quatro comandos DML centrais desta aula.
-- Execute em um database/schema PostgreSQL vazio (a secao 0 limpa antes).
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 0. LIMPEZA (idempotencia ao reexecutar o script)
-- -----------------------------------------------------------------------------
DROP TABLE IF EXISTS ItemVenda, Venda, Estoque, LivroEstoqueStaging, Livro, Cliente, Autor CASCADE;

-- -----------------------------------------------------------------------------
-- 1. ESQUEMA BOOKHUB
-- -----------------------------------------------------------------------------
CREATE TABLE Autor (
    autor_id        INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nome            VARCHAR(150) NOT NULL,
    nacionalidade   VARCHAR(60)  NOT NULL,
    data_nascimento DATE         NOT NULL
);

CREATE TABLE Livro (
    livro_id        INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    autor_id        INTEGER      NOT NULL REFERENCES Autor (autor_id),
    titulo          VARCHAR(200) NOT NULL,
    genero          VARCHAR(60)  NOT NULL,
    preco           NUMERIC(10,2) NOT NULL,
    tipo            CHAR(1)      NOT NULL CHECK (tipo IN ('F','D')), -- F=Fisico, D=Digital
    ano_publicacao  INTEGER      NOT NULL
);

CREATE TABLE Cliente (
    cliente_id      INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nome            VARCHAR(150) NOT NULL,
    email           VARCHAR(150) NOT NULL UNIQUE,
    telefone        VARCHAR(30)  NOT NULL,
    data_cadastro   DATE         NOT NULL
);

CREATE TABLE Venda (
    venda_id        INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    data_venda      DATE         NOT NULL,
    forma_pagamento VARCHAR(30)  NOT NULL,
    valor_total     NUMERIC(10,2) NOT NULL,
    cliente_id      INTEGER      NOT NULL REFERENCES Cliente (cliente_id)
);

CREATE TABLE ItemVenda (
    itemvenda_id    INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    venda_id        INTEGER      NOT NULL REFERENCES Venda (venda_id),
    livro_id        INTEGER      NOT NULL REFERENCES Livro (livro_id),
    preco_unitario  NUMERIC(10,2) NOT NULL,
    quantidade      INTEGER      NOT NULL
);

-- Tabela de estoque, usada nos exemplos de upsert mais adiante. livro_id e a
-- CHAVE (PRIMARY KEY) que o ON CONFLICT usara para decidir insert x update.
CREATE TABLE Estoque (
    livro_id              INTEGER PRIMARY KEY REFERENCES Livro (livro_id),
    quantidade_disponivel INTEGER NOT NULL,
    ultima_atualizacao    DATE    NOT NULL
);

-- Tabela de staging: simula um arquivo/feed do fornecedor com contagens novas de
-- estoque, algumas para livros ja cadastrados em Estoque, outras para livros novos
CREATE TABLE LivroEstoqueStaging (
    livro_id        INTEGER PRIMARY KEY,
    quantidade_nova INTEGER NOT NULL
);

-- -----------------------------------------------------------------------------
-- 2. INSERT - carga inicial de dados
-- -----------------------------------------------------------------------------
-- 2.1 INSERT simples (uma linha por vez)
INSERT INTO Autor (nome, nacionalidade, data_nascimento) VALUES
    ('Dick Vigarista', 'Brasil', DATE '1978-05-12');

-- 2.2 INSERT multilinha (sintaxe padrao ANSI, tambem valida no Oracle 23c+)
INSERT INTO Autor (nome, nacionalidade, data_nascimento) VALUES
    ('Penelope Charmosa', 'Reino Unido', DATE '1965-11-02'),
    ('Muttley', 'Estados Unidos', DATE '1985-07-20'),
    ('Aurora Beltrame', 'Portugal', DATE '1990-03-15');

INSERT INTO Livro (autor_id, titulo, genero, preco, tipo, ano_publicacao) VALUES
    (1, 'Programacao em Java - Avancado', 'Tecnologia', 120.00, 'F', 2019),
    (1, 'Introducao ao SQL', 'Tecnologia', 45.00, 'F', 2015),
    (2, 'Romance das Estacoes', 'Ficcao', 35.50, 'D', 2021),
    (3, 'Historias do Oriente', 'Ficcao', 55.00, 'F', 1998),
    (2, 'Aplicacoes em Rust', 'Tecnologia', 89.90, 'D', 2022),
    (3, 'Contos de Inverno', 'Ficcao', 29.90, 'D', 2020),
    (1, 'Banco de Dados Essencial', 'Tecnologia', 99.00, 'F', 2023);

INSERT INTO Cliente (nome, email, telefone, data_cadastro) VALUES
    ('Ze Bugadinho', 'ze.bugadinho@email.com', '+55-11-99999-0001', DATE '2023-02-10'),
    ('Ana Stackoverflow', 'ana.stackoverflow@email.com', '+55-21-98888-1111', DATE '2022-11-05'),
    ('Beto Nullpointer', 'beto.nullpointer@email.com', '+55-41-97777-2222', DATE '2024-01-03'),
    ('Carla Datasteria', 'carla.datasteria@email.com', '+55-51-96666-3333', DATE '2024-06-20');

INSERT INTO Venda (data_venda, forma_pagamento, valor_total, cliente_id) VALUES
    (DATE '2025-08-10', 'Cartao', 165.00, 1),
    (DATE '2025-08-12', 'Boleto', 160.90, 2),
    (DATE '2025-09-01', 'Pix', 99.00, 3);

INSERT INTO ItemVenda (venda_id, livro_id, preco_unitario, quantidade) VALUES
    (1, 1, 120.00, 1),
    (1, 2, 45.00, 1),
    (2, 3, 35.50, 2),
    (2, 5, 89.90, 1),
    (3, 7, 99.00, 1);

INSERT INTO Estoque (livro_id, quantidade_disponivel, ultima_atualizacao) VALUES
    (1, 12, DATE '2025-09-01'),
    (2, 30, DATE '2025-09-01'),
    (3, 5,  DATE '2025-09-01'),
    (4, 0,  DATE '2025-09-01');

-- -----------------------------------------------------------------------------
-- 3. UPDATE
-- -----------------------------------------------------------------------------
-- 3.1 UPDATE simples: reajuste de 10% em todos os livros fisicos
UPDATE Livro
   SET preco = ROUND(preco * 1.10, 2)
 WHERE tipo = 'F';

-- 3.2 UPDATE com subquery correlacionada: zera estoque de livros descontinuados
--     (ano de publicacao anterior a 2000)
UPDATE Estoque e
   SET quantidade_disponivel = 0
  FROM Livro l
 WHERE l.livro_id = e.livro_id
   AND l.ano_publicacao < 2000;

-- 3.3 UPDATE multi-coluna com CASE: reclassifica forma de pagamento em vendas
UPDATE Venda
   SET forma_pagamento = CASE
                            WHEN forma_pagamento = 'Boleto' THEN 'Boleto Bancario'
                            ELSE forma_pagamento
                          END
 WHERE forma_pagamento = 'Boleto';

-- -----------------------------------------------------------------------------
-- 4. DELETE
-- -----------------------------------------------------------------------------
-- 4.1 DELETE simples: remove livros anteriores a 1990 (nenhum na carga atual,
--     mas ilustra o padrao antes de popular novos dados de teste)
DELETE FROM Livro WHERE ano_publicacao < 1990;

-- 4.2 DELETE com subquery: remove itens de estoque de livros sem nenhuma venda
--     registrada (demonstra cuidado com integridade referencial)
DELETE FROM Estoque e
 WHERE e.quantidade_disponivel = 0
   AND NOT EXISTS (SELECT 1 FROM ItemVenda iv WHERE iv.livro_id = e.livro_id);

-- (o script Oracle equivalente usa ROLLBACK aqui para fins didaticos; no
--  PostgreSQL sem transacao explicita cada comando e autocommit por padrao,
--  entao seguimos direto para o upsert)

-- -----------------------------------------------------------------------------
-- 5. INSERT ... ON CONFLICT (upsert nativo do PostgreSQL)
-- -----------------------------------------------------------------------------
-- Cenario: o fornecedor envia uma atualizacao de estoque (LivroEstoqueStaging).
-- Se o livro ja existe em Estoque, ATUALIZA a quantidade; senao, INSERE a linha.
INSERT INTO LivroEstoqueStaging (livro_id, quantidade_nova) VALUES
    (1, 8),   -- existe -> update
    (3, 20),  -- existe -> update
    (6, 15),  -- novo   -> insert
    (7, 40);  -- novo   -> insert

INSERT INTO Estoque (livro_id, quantidade_disponivel, ultima_atualizacao)
SELECT livro_id, quantidade_nova, CURRENT_DATE
  FROM LivroEstoqueStaging
ON CONFLICT (livro_id)
DO UPDATE SET quantidade_disponivel = EXCLUDED.quantidade_disponivel,
              ultima_atualizacao    = EXCLUDED.ultima_atualizacao;

-- Conferindo o resultado do upsert
SELECT livro_id, quantidade_disponivel, ultima_atualizacao FROM Estoque ORDER BY livro_id;

-- -----------------------------------------------------------------------------
-- 6. ON CONFLICT DO NOTHING e ON CONFLICT ... WHERE (variantes uteis)
-- -----------------------------------------------------------------------------
-- 6.1 Ignora silenciosamente se o livro ja tiver registro de estoque
INSERT INTO Estoque (livro_id, quantidade_disponivel, ultima_atualizacao)
VALUES (1, 999, CURRENT_DATE)
ON CONFLICT (livro_id) DO NOTHING;

-- 6.2 So atualiza se a nova quantidade for maior que zero (upsert condicional)
INSERT INTO Estoque (livro_id, quantidade_disponivel, ultima_atualizacao)
VALUES (5, 0, CURRENT_DATE)
ON CONFLICT (livro_id)
DO UPDATE SET quantidade_disponivel = EXCLUDED.quantidade_disponivel,
              ultima_atualizacao    = EXCLUDED.ultima_atualizacao
      WHERE EXCLUDED.quantidade_disponivel > 0;

-- =============================================================================
-- Fim do script. Equivalente Oracle: repository/class12/oracle/BD1201-DML.sql
-- Observacao: no Oracle, MERGE tambem serve para "upsert" vindo de outra tabela
-- inteira de uma vez (como no passo 5). O PostgreSQL, a partir da versao 15,
-- tambem oferece o comando MERGE completo (INSERT/UPDATE/DELETE em um so
-- comando), mas ON CONFLICT continua sendo a forma idiomatica para upsert
-- linha a linha vindo de uma unica tabela de origem.
-- =============================================================================
