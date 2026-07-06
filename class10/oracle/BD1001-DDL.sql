--------------------------------------------------------------------------------
-- BD1001-DDL.sql
-- Aula 10 - UA4: DDL: CREATE, ALTER, DROP e Constraints
-- SGBD: Oracle Database (XE 21c ou superior)
-- Estudo de caso: BookHub - livraria online (catalogo, clientes e vendas)
--
-- Convencoes adotadas neste script:
--   - Nomes de tabela em CamelCase, colunas em snake_case;
--   - Toda PK/FK/UNIQUE/CHECK recebe um nome explicito via CONSTRAINT
--     (facilita leitura de mensagens de erro e manutencao futura);
--   - Chaves primarias geradas por CREATE SEQUENCE + DEFAULT ... NEXTVAL
--     (sintaxe disponivel a partir do Oracle 12c, dispensa trigger BEFORE INSERT).
--------------------------------------------------------------------------------

-- ============================================================================
-- 1. LIMPEZA (idempotencia ao reexecutar o script em ambiente de estudo)
-- ============================================================================
-- DROP TABLE ItemVenda CASCADE CONSTRAINTS PURGE;
-- DROP TABLE Venda CASCADE CONSTRAINTS PURGE;
-- DROP TABLE Livro CASCADE CONSTRAINTS PURGE;
-- DROP TABLE Cliente CASCADE CONSTRAINTS PURGE;
-- DROP TABLE Editora CASCADE CONSTRAINTS PURGE;
-- DROP TABLE Autor CASCADE CONSTRAINTS PURGE;
-- DROP TABLE Categoria CASCADE CONSTRAINTS PURGE;
-- DROP SEQUENCE categoria_id_seq;
-- DROP SEQUENCE autor_id_seq;
-- DROP SEQUENCE editora_id_seq;
-- DROP SEQUENCE livro_id_seq;
-- DROP SEQUENCE cliente_id_seq;
-- DROP SEQUENCE venda_id_seq;
-- DROP SEQUENCE itemvenda_id_seq;

-- ============================================================================
-- 2. SEQUENCES (geradores de chave primaria)
-- ============================================================================
CREATE SEQUENCE categoria_id_seq START WITH 1 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE autor_id_seq     START WITH 1 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE editora_id_seq   START WITH 1 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE livro_id_seq     START WITH 1 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE cliente_id_seq   START WITH 1 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE venda_id_seq     START WITH 1 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE itemvenda_id_seq START WITH 1 INCREMENT BY 1 NOCACHE;

-- ============================================================================
-- 3. CREATE TABLE - entidades de referencia (sem dependencias)
-- ============================================================================
CREATE TABLE Categoria (
    categoria_id  NUMBER          DEFAULT categoria_id_seq.NEXTVAL NOT NULL,
    nome          VARCHAR2(60)    NOT NULL,
    descricao     VARCHAR2(200),
    CONSTRAINT categoria_pk PRIMARY KEY (categoria_id),
    CONSTRAINT categoria_nome_uk UNIQUE (nome)
);

CREATE TABLE Autor (
    autor_id         NUMBER        DEFAULT autor_id_seq.NEXTVAL NOT NULL,
    nome             VARCHAR2(200) NOT NULL,
    nacionalidade    VARCHAR2(60)  NOT NULL,
    data_nascimento  DATE          NOT NULL,
    CONSTRAINT autor_pk PRIMARY KEY (autor_id)
);

CREATE TABLE Editora (
    editora_id     NUMBER         DEFAULT editora_id_seq.NEXTVAL NOT NULL,
    nome           VARCHAR2(120)  NOT NULL,
    pais           VARCHAR2(60)   NOT NULL,
    ano_fundacao   NUMBER(4)      NOT NULL,
    CONSTRAINT editora_pk PRIMARY KEY (editora_id),
    CONSTRAINT editora_ano_ck CHECK (ano_fundacao >= 1400)
);

CREATE TABLE Cliente (
    cliente_id     NUMBER         DEFAULT cliente_id_seq.NEXTVAL NOT NULL,
    nome           VARCHAR2(200)  NOT NULL,
    email          VARCHAR2(150)  NOT NULL,
    telefone       VARCHAR2(20),
    data_cadastro  DATE           DEFAULT SYSDATE NOT NULL,
    CONSTRAINT cliente_pk PRIMARY KEY (cliente_id),
    CONSTRAINT cliente_email_uk UNIQUE (email)
);

-- ============================================================================
-- 4. CREATE TABLE - entidades dependentes (com FK inline)
-- ============================================================================
CREATE TABLE Livro (
    livro_id         NUMBER          DEFAULT livro_id_seq.NEXTVAL NOT NULL,
    autor_id         NUMBER          NOT NULL,
    editora_id       NUMBER          NOT NULL,
    categoria_id     NUMBER          NOT NULL,
    titulo           VARCHAR2(200)   NOT NULL,
    preco            NUMBER(10,2)    NOT NULL,
    ano_publicacao   NUMBER(4)       NOT NULL,
    tipo             CHAR(1)         DEFAULT 'F' NOT NULL,
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
    venda_id          NUMBER         DEFAULT venda_id_seq.NEXTVAL NOT NULL,
    cliente_id        NUMBER         NOT NULL,
    data_venda        DATE           DEFAULT SYSDATE NOT NULL,
    forma_pagamento   VARCHAR2(30)   NOT NULL,
    valor_total       NUMBER(10,2)   NOT NULL,
    CONSTRAINT venda_pk PRIMARY KEY (venda_id),
    CONSTRAINT venda_cliente_fk FOREIGN KEY (cliente_id)
        REFERENCES Cliente (cliente_id),
    CONSTRAINT venda_valor_ck CHECK (valor_total >= 0),
    CONSTRAINT venda_forma_pgto_ck CHECK (
        forma_pagamento IN ('CARTAO_CREDITO', 'CARTAO_DEBITO', 'PIX', 'BOLETO')
    )
);

CREATE TABLE ItemVenda (
    itemvenda_id     NUMBER         DEFAULT itemvenda_id_seq.NEXTVAL NOT NULL,
    venda_id         NUMBER         NOT NULL,
    livro_id         NUMBER         NOT NULL,
    quantidade       NUMBER(6)      NOT NULL,
    preco_unitario   NUMBER(10,2)   NOT NULL,
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
-- 5. ALTER TABLE - evolucao do esquema (exemplos didaticos)
-- ============================================================================

-- 5.1 Adicionar coluna nova com valor padrao para linhas existentes
ALTER TABLE Cliente ADD (
    ativo  CHAR(1) DEFAULT 'S' NOT NULL
);
ALTER TABLE Cliente ADD CONSTRAINT cliente_ativo_ck CHECK (ativo IN ('S', 'N'));

-- 5.2 Adicionar constraint em tabela ja existente (FK adicionada depois do CREATE)
-- (equivalente didatico a quando o vinculo e descoberto apos a modelagem inicial)
-- ALTER TABLE Livro ADD CONSTRAINT livro_categoria_fk
--     FOREIGN KEY (categoria_id) REFERENCES Categoria (categoria_id);

-- 5.3 Modificar definicao de coluna (aumentar tamanho, sem perda de dados)
ALTER TABLE Autor MODIFY (nacionalidade VARCHAR2(80));

-- 5.4 Renomear coluna
ALTER TABLE Editora RENAME COLUMN pais TO pais_origem;

-- 5.5 Renomear constraint
ALTER TABLE Livro RENAME CONSTRAINT livro_preco_ck TO ck_livro_preco_nao_negativo;

-- 5.6 Remover coluna que deixou de ser necessaria
ALTER TABLE Cliente DROP COLUMN telefone;

-- 5.7 Desabilitar/reabilitar constraint sem remove-la (util em cargas em lote)
ALTER TABLE ItemVenda DISABLE CONSTRAINT itemvenda_qtd_ck;
ALTER TABLE ItemVenda ENABLE CONSTRAINT itemvenda_qtd_ck;

-- 5.8 Remover constraint definitivamente
-- ALTER TABLE Livro DROP CONSTRAINT ck_livro_preco_nao_negativo;

-- ============================================================================
-- 6. DROP / TRUNCATE - cuidado: operacoes destrutivas
-- ============================================================================
-- TRUNCATE TABLE ItemVenda;              -- remove todas as linhas, mantem a estrutura
-- DROP TABLE ItemVenda CASCADE CONSTRAINTS PURGE;  -- remove a tabela e libera espaco definitivamente

-- ============================================================================
-- 7. Consulta de verificacao (confirma que o esquema foi criado)
-- ============================================================================
SELECT table_name FROM user_tables
WHERE table_name IN ('CATEGORIA', 'AUTOR', 'EDITORA', 'CLIENTE', 'LIVRO', 'VENDA', 'ITEMVENDA')
ORDER BY table_name;
