--------------------------------------------------------------------------------
-- BD1001-DDL.sql
-- Aula 10 - UA4: DDL: CREATE, ALTER, DROP e Constraints
-- SGBD: PostgreSQL 15 ou superior
-- Estudo de caso: BookHub - livraria online (catalogo, clientes e vendas)
--
-- Convencoes adotadas neste script:
--   - Nomes de tabela em CamelCase, colunas em snake_case;
--   - Toda PK/FK/UNIQUE/CHECK recebe um nome explicito via CONSTRAINT;
--   - Chaves primarias geradas com GENERATED ALWAYS AS IDENTITY (padrao SQL:2008,
--     sucessor recomendado do SERIAL/BIGSERIAL clássico do PostgreSQL).
--------------------------------------------------------------------------------

-- ============================================================================
-- 1. LIMPEZA (idempotencia ao reexecutar o script em ambiente de estudo)
-- ============================================================================
-- DROP TABLE IF EXISTS ItemVenda, Venda, Livro, Cliente, Editora, Autor, Categoria CASCADE;

-- ============================================================================
-- 2. CREATE TABLE - entidades de referencia (sem dependencias)
-- ============================================================================
CREATE TABLE Categoria (
    categoria_id  INTEGER      GENERATED ALWAYS AS IDENTITY,
    nome          VARCHAR(60)  NOT NULL,
    descricao     VARCHAR(200),
    CONSTRAINT categoria_pk PRIMARY KEY (categoria_id),
    CONSTRAINT categoria_nome_uk UNIQUE (nome)
);

CREATE TABLE Autor (
    autor_id         INTEGER       GENERATED ALWAYS AS IDENTITY,
    nome             VARCHAR(200)  NOT NULL,
    nacionalidade    VARCHAR(60)   NOT NULL,
    data_nascimento  DATE          NOT NULL,
    CONSTRAINT autor_pk PRIMARY KEY (autor_id)
);

-- Alternativa classica (equivalente a coluna acima), citada apenas como referencia:
-- CREATE TABLE Autor (
--     autor_id  SERIAL PRIMARY KEY,
--     ...
-- );

CREATE TABLE Editora (
    editora_id     INTEGER       GENERATED ALWAYS AS IDENTITY,
    nome           VARCHAR(120)  NOT NULL,
    pais           VARCHAR(60)   NOT NULL,
    ano_fundacao   INTEGER       NOT NULL,
    CONSTRAINT editora_pk PRIMARY KEY (editora_id),
    CONSTRAINT editora_ano_ck CHECK (ano_fundacao >= 1400)
);

CREATE TABLE Cliente (
    cliente_id     INTEGER       GENERATED ALWAYS AS IDENTITY,
    nome           VARCHAR(200)  NOT NULL,
    email          VARCHAR(150)  NOT NULL,
    telefone       VARCHAR(20),
    data_cadastro  DATE          NOT NULL DEFAULT CURRENT_DATE,
    CONSTRAINT cliente_pk PRIMARY KEY (cliente_id),
    CONSTRAINT cliente_email_uk UNIQUE (email)
);

-- ============================================================================
-- 3. CREATE TABLE - entidades dependentes (com FK inline)
-- ============================================================================
CREATE TABLE Livro (
    livro_id         INTEGER        GENERATED ALWAYS AS IDENTITY,
    autor_id         INTEGER        NOT NULL,
    editora_id       INTEGER        NOT NULL,
    categoria_id     INTEGER        NOT NULL,
    titulo           VARCHAR(200)   NOT NULL,
    preco            NUMERIC(10,2)  NOT NULL,
    ano_publicacao   INTEGER        NOT NULL,
    tipo             CHAR(1)        NOT NULL DEFAULT 'F',
    CONSTRAINT livro_pk PRIMARY KEY (livro_id),
    CONSTRAINT livro_autor_fk FOREIGN KEY (autor_id)
        REFERENCES Autor (autor_id),
    CONSTRAINT livro_editora_fk FOREIGN KEY (editora_id)
        REFERENCES Editora (editora_id),
    CONSTRAINT livro_categoria_fk FOREIGN KEY (categoria_id)
        REFERENCES Categoria (categoria_id),
    CONSTRAINT livro_preco_ck CHECK (preco >= 0),
    CONSTRAINT livro_tipo_ck CHECK (tipo IN ('F', 'E')) -- F = Fisico, E = E-book
);

CREATE TABLE Venda (
    venda_id          INTEGER        GENERATED ALWAYS AS IDENTITY,
    cliente_id        INTEGER        NOT NULL,
    data_venda        DATE           NOT NULL DEFAULT CURRENT_DATE,
    forma_pagamento   VARCHAR(30)    NOT NULL,
    valor_total       NUMERIC(10,2)  NOT NULL,
    CONSTRAINT venda_pk PRIMARY KEY (venda_id),
    CONSTRAINT venda_cliente_fk FOREIGN KEY (cliente_id)
        REFERENCES Cliente (cliente_id),
    CONSTRAINT venda_valor_ck CHECK (valor_total >= 0),
    CONSTRAINT venda_forma_pgto_ck CHECK (
        forma_pagamento IN ('CARTAO_CREDITO', 'CARTAO_DEBITO', 'PIX', 'BOLETO')
    )
);

CREATE TABLE ItemVenda (
    itemvenda_id     INTEGER        GENERATED ALWAYS AS IDENTITY,
    venda_id         INTEGER        NOT NULL,
    livro_id         INTEGER        NOT NULL,
    quantidade       INTEGER        NOT NULL,
    preco_unitario   NUMERIC(10,2)  NOT NULL,
    CONSTRAINT itemvenda_pk PRIMARY KEY (itemvenda_id),
    CONSTRAINT itemvenda_venda_fk FOREIGN KEY (venda_id)
        REFERENCES Venda (venda_id)
        ON DELETE CASCADE,
    CONSTRAINT itemvenda_livro_fk FOREIGN KEY (livro_id)
        REFERENCES Livro (livro_id),
    CONSTRAINT itemvenda_qtd_ck CHECK (quantidade > 0),
    CONSTRAINT itemvenda_preco_ck CHECK (preco_unitario >= 0)
);

-- ============================================================================
-- 4. ALTER TABLE - evolucao do esquema (exemplos didaticos)
-- ============================================================================

-- 4.1 Adicionar coluna nova com valor padrao para linhas existentes
ALTER TABLE Cliente ADD COLUMN ativo CHAR(1) NOT NULL DEFAULT 'S';
ALTER TABLE Cliente ADD CONSTRAINT cliente_ativo_ck CHECK (ativo IN ('S', 'N'));

-- 4.2 Adicionar constraint em tabela ja existente (FK adicionada depois do CREATE)
-- ALTER TABLE Livro ADD CONSTRAINT livro_categoria_fk
--     FOREIGN KEY (categoria_id) REFERENCES Categoria (categoria_id);

-- 4.3 Modificar definicao de coluna (aumentar tamanho, sem perda de dados)
ALTER TABLE Autor ALTER COLUMN nacionalidade TYPE VARCHAR(80);

-- 4.4 Renomear coluna
ALTER TABLE Editora RENAME COLUMN pais TO pais_origem;

-- 4.5 Renomear constraint
ALTER TABLE Livro RENAME CONSTRAINT livro_preco_ck TO ck_livro_preco_nao_negativo;

-- 4.6 Remover coluna que deixou de ser necessaria
ALTER TABLE Cliente DROP COLUMN telefone;

-- 4.7 Desabilitar/reabilitar constraint (PostgreSQL so permite para CHECK/FK via NOT VALID + VALIDATE)
ALTER TABLE ItemVenda DROP CONSTRAINT itemvenda_qtd_ck;
ALTER TABLE ItemVenda ADD CONSTRAINT itemvenda_qtd_ck CHECK (quantidade > 0) NOT VALID;
ALTER TABLE ItemVenda VALIDATE CONSTRAINT itemvenda_qtd_ck;

-- 4.8 Remover constraint definitivamente
-- ALTER TABLE Livro DROP CONSTRAINT ck_livro_preco_nao_negativo;

-- ============================================================================
-- 5. DROP / TRUNCATE - cuidado: operacoes destrutivas
-- ============================================================================
-- TRUNCATE TABLE ItemVenda;                    -- remove todas as linhas, mantem a estrutura
-- DROP TABLE IF EXISTS ItemVenda CASCADE;      -- remove a tabela e as dependencias

-- ============================================================================
-- 6. Consulta de verificacao (confirma que o esquema foi criado)
-- ============================================================================
SELECT table_name FROM information_schema.tables
WHERE table_schema = 'public'
  AND table_name IN ('categoria', 'autor', 'editora', 'cliente', 'livro', 'venda', 'itemvenda')
ORDER BY table_name;
