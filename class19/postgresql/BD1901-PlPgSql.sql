--------------------------------------------------------------------------------
-- BD1901-PlPgSql.sql
-- Aula 19 - PL/pgSQL: procedures e functions
-- SGBD: PostgreSQL (testado em PostgreSQL 15+)
--
-- Mesmos exemplos da Aula 18 (BD1801-PlSql.sql, Oracle/PL-SQL), traduzidos
-- para PostgreSQL/PL-pgSQL, mantendo o schema BookHub (livraria online) para
-- permitir comparacao lado a lado entre os dois bancos.
--------------------------------------------------------------------------------


--------------------------------------------------------------------------------
-- 0. SCHEMA DE APOIO (BookHub) - execute uma vez antes dos blocos abaixo
--------------------------------------------------------------------------------

DROP TABLE IF EXISTS item_pedido CASCADE;
DROP TABLE IF EXISTS pedido CASCADE;
DROP TABLE IF EXISTS cliente CASCADE;
DROP TABLE IF EXISTS livro CASCADE;
DROP TABLE IF EXISTS categoria CASCADE;

CREATE TABLE categoria (
    categoria_id   INTEGER       PRIMARY KEY,
    nome           VARCHAR(60)   NOT NULL UNIQUE
);

CREATE TABLE livro (
    livro_id       INTEGER       PRIMARY KEY,
    categoria_id   INTEGER       NOT NULL REFERENCES categoria (categoria_id),
    titulo         VARCHAR(120)  NOT NULL,
    preco          NUMERIC(8,2)  NOT NULL CHECK (preco > 0),
    estoque        INTEGER       NOT NULL DEFAULT 0 CHECK (estoque >= 0)
);

CREATE TABLE cliente (
    cliente_id     INTEGER       PRIMARY KEY,
    nome           VARCHAR(80)   NOT NULL,
    email          VARCHAR(120)  NOT NULL,
    data_cadastro  DATE          NOT NULL DEFAULT CURRENT_DATE
);

CREATE TABLE pedido (
    pedido_id       INTEGER       PRIMARY KEY,
    cliente_id      INTEGER       NOT NULL REFERENCES cliente (cliente_id),
    data_pedido     DATE          NOT NULL DEFAULT CURRENT_DATE,
    valor_total     NUMERIC(10,2) DEFAULT 0
);

CREATE TABLE item_pedido (
    item_pedido_id  INTEGER       PRIMARY KEY,
    pedido_id       INTEGER       NOT NULL REFERENCES pedido (pedido_id),
    livro_id        INTEGER       NOT NULL REFERENCES livro (livro_id),
    quantidade      INTEGER       NOT NULL,
    valor_unitario  NUMERIC(8,2)  NOT NULL
);

CREATE SEQUENCE item_pedido_seq START WITH 100 INCREMENT BY 1;

INSERT INTO categoria VALUES (1, 'Tecnologia');
INSERT INTO categoria VALUES (2, 'Literatura Nacional');
INSERT INTO categoria VALUES (3, 'Infantil');

INSERT INTO livro VALUES (101, 1, 'Banco de Dados Essencial',  89.90, 40);
INSERT INTO livro VALUES (102, 1, 'PL/pgSQL na Pratica',       74.50, 25);
INSERT INTO livro VALUES (103, 2, 'Dom Casmurro',              29.90, 60);
INSERT INTO livro VALUES (104, 3, 'Historias da Floresta',     39.00, 15);

INSERT INTO cliente (cliente_id, nome, email) VALUES (1, 'Ana Beatriz Souza', 'ana.souza@exemplo.com');
INSERT INTO cliente (cliente_id, nome, email) VALUES (2, 'Carlos Eduardo Lima', 'carlos.lima@exemplo.com');

INSERT INTO pedido (pedido_id, cliente_id) VALUES (1001, 1);
INSERT INTO item_pedido VALUES (1, 1001, 101, 1, 89.90);
INSERT INTO item_pedido VALUES (2, 1001, 103, 2, 29.90);


--------------------------------------------------------------------------------
-- 1. BLOCO ANONIMO SIMPLES
--------------------------------------------------------------------------------
-- Em PostgreSQL o bloco anonimo eh escrito com DO $$ ... $$ e sempre precisa
-- declarar LANGUAGE plpgsql (implicito quando omitido, pois eh a linguagem
-- padrao). RAISE NOTICE eh o equivalente a DBMS_OUTPUT.PUT_LINE do Oracle.

DO $$
BEGIN
    RAISE NOTICE 'Ola, PL/pgSQL! Este eh um bloco anonimo.';
END;
$$;


--------------------------------------------------------------------------------
-- 2. BLOCO ANONIMO COM VARIAVEIS E %TYPE
--------------------------------------------------------------------------------
-- PL/pgSQL tambem suporta %TYPE, com a mesma sintaxe do Oracle.

DO $$
DECLARE
    v_titulo   livro.titulo%TYPE;
    v_preco    livro.preco%TYPE;
BEGIN
    SELECT titulo, preco
      INTO v_titulo, v_preco
      FROM livro
     WHERE livro_id = 101;

    RAISE NOTICE 'Livro: % - R$ %', v_titulo, v_preco;
END;
$$;


--------------------------------------------------------------------------------
-- 3. BLOCO ANONIMO COM %ROWTYPE
--------------------------------------------------------------------------------
-- Assim como no Oracle, %ROWTYPE cria uma variavel com uma coluna para cada
-- coluna da tabela.

DO $$
DECLARE
    v_livro livro%ROWTYPE;
BEGIN
    SELECT * INTO v_livro FROM livro WHERE livro_id = 102;

    RAISE NOTICE 'Titulo: %', v_livro.titulo;
    RAISE NOTICE 'Estoque atual: %', v_livro.estoque;
END;
$$;


--------------------------------------------------------------------------------
-- 4. FUNCTION SEM PARAMETROS - lista os nomes dos clientes
--------------------------------------------------------------------------------
-- Diferenca chave: PostgreSQL nao tem "PROCEDURE sem retorno" tradicional
-- antes da versao 11; hoje CREATE PROCEDURE existe, mas rotinas que so
-- produzem efeito colateral (como imprimir mensagens) sao comumente escritas
-- como FUNCTION RETURNS void.

CREATE OR REPLACE FUNCTION listar_clientes()
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
    r_cliente RECORD;
BEGIN
    FOR r_cliente IN SELECT nome, email FROM cliente ORDER BY nome LOOP
        RAISE NOTICE '% <%>', r_cliente.nome, r_cliente.email;
    END LOOP;
END;
$$;

-- Execucao:
SELECT listar_clientes();


--------------------------------------------------------------------------------
-- 5. FUNCTION COM PARAMETRO IN - valor de estoque por categoria
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION valor_estoque_por_categoria (
    p_nome_categoria VARCHAR
)
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
    v_valor_total NUMERIC(12,2);
BEGIN
    SELECT SUM(l.preco * l.estoque)
      INTO v_valor_total
      FROM livro l
      JOIN categoria c ON c.categoria_id = l.categoria_id
     WHERE c.nome = p_nome_categoria;

    IF v_valor_total IS NULL THEN
        RAISE NOTICE 'Categoria nao encontrada ou sem estoque.';
    ELSE
        RAISE NOTICE 'Valor em estoque de "%": R$ %', p_nome_categoria, v_valor_total;
    END IF;
END;
$$;

SELECT valor_estoque_por_categoria('Tecnologia');


--------------------------------------------------------------------------------
-- 6. PROCEDURE COM PARAMETROS IN E OUT - estatisticas de pedidos do mes
--------------------------------------------------------------------------------
-- Desde o PostgreSQL 14, CREATE PROCEDURE aceita parametros OUT (devolvidos
-- em uma unica linha de resultado ao chamar via CALL). IN eh o modo padrao;
-- INOUT combina os dois sentidos, como no Oracle.

CREATE OR REPLACE PROCEDURE estatisticas_pedidos_mes (
    IN  p_mes         INTEGER,
    OUT p_qtd_pedidos INTEGER,
    OUT p_valor_medio NUMERIC
)
LANGUAGE plpgsql
AS $$
BEGIN
    SELECT COUNT(*), COALESCE(AVG(valor_total), 0)
      INTO p_qtd_pedidos, p_valor_medio
      FROM pedido
     WHERE EXTRACT(MONTH FROM data_pedido) = p_mes;
END;
$$;

-- Chamada (PostgreSQL 14+): os parametros OUT sao devolvidos como resultado
CALL estatisticas_pedidos_mes(EXTRACT(MONTH FROM CURRENT_DATE)::INTEGER, NULL, NULL);


--------------------------------------------------------------------------------
-- 7. IF / ELSIF / ELSE - classificacao do volume de pedidos do mes
--------------------------------------------------------------------------------

CREATE OR REPLACE PROCEDURE classificar_pedidos_mes_if (
    p_mes INTEGER
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_total_pedidos INTEGER;
BEGIN
    SELECT COUNT(*)
      INTO v_total_pedidos
      FROM pedido
     WHERE EXTRACT(MONTH FROM data_pedido) = p_mes;

    IF v_total_pedidos > 20 THEN
        RAISE NOTICE '% pedidos: volume ACIMA da meta', v_total_pedidos;
    ELSIF v_total_pedidos BETWEEN 10 AND 20 THEN
        RAISE NOTICE '% pedidos: volume DENTRO da meta', v_total_pedidos;
    ELSE
        RAISE NOTICE '% pedidos: volume ABAIXO da meta', v_total_pedidos;
    END IF;
END;
$$;


--------------------------------------------------------------------------------
-- 8. CASE - mesma logica reescrita com CASE
--------------------------------------------------------------------------------

CREATE OR REPLACE PROCEDURE classificar_pedidos_mes_case (
    p_mes INTEGER
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_total_pedidos INTEGER;
    v_resultado     VARCHAR(60);
BEGIN
    SELECT COUNT(*)
      INTO v_total_pedidos
      FROM pedido
     WHERE EXTRACT(MONTH FROM data_pedido) = p_mes;

    v_resultado := CASE
        WHEN v_total_pedidos = 0 THEN 'Nenhum pedido registrado'
        WHEN v_total_pedidos < 10 THEN 'Volume ABAIXO da meta'
        WHEN v_total_pedidos <= 20 THEN 'Volume DENTRO da meta'
        ELSE 'Volume ACIMA da meta'
    END;

    RAISE NOTICE '% pedidos: %', v_total_pedidos, v_resultado;
END;
$$;


--------------------------------------------------------------------------------
-- 9. LOOP / WHILE - soma acumulada
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION soma_ate (
    p_limite INTEGER
)
RETURNS INTEGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_indice INTEGER := 1;
    v_soma   INTEGER := 0;
BEGIN
    WHILE v_indice <= p_limite LOOP
        v_soma   := v_soma + v_indice;
        v_indice := v_indice + 1;
    END LOOP;

    RETURN v_soma;
END;
$$;

SELECT soma_ate(5); -- 15


--------------------------------------------------------------------------------
-- 10. CURSOR EXPLICITO - lista de titulos concatenados por categoria
--------------------------------------------------------------------------------
-- PL/pgSQL permite tanto o cursor implicito (FOR rec IN SELECT ... LOOP,
-- forma idiomatica) quanto o cursor explicito (OPEN/FETCH/CLOSE), mostrado
-- aqui para espelhar exatamente a versao Oracle da Aula 18.

CREATE OR REPLACE PROCEDURE titulos_por_categoria (
    p_categoria_id INTEGER,
    INOUT p_lista  VARCHAR DEFAULT NULL
)
LANGUAGE plpgsql
AS $$
DECLARE
    cur_livro CURSOR (p_cat INTEGER) FOR
        SELECT titulo FROM livro WHERE categoria_id = p_cat;
    v_titulo livro.titulo%TYPE;
BEGIN
    p_lista := NULL;

    OPEN cur_livro(p_categoria_id);
    LOOP
        FETCH cur_livro INTO v_titulo;
        EXIT WHEN NOT FOUND;

        IF p_lista IS NULL THEN
            p_lista := v_titulo;
        ELSE
            p_lista := p_lista || ', ' || v_titulo;
        END IF;
    END LOOP;
    CLOSE cur_livro;
END;
$$;

CALL titulos_por_categoria(1, NULL);


--------------------------------------------------------------------------------
-- 11. TRATAMENTO DE EXCECOES - insercao de categoria com nome duplicado
--------------------------------------------------------------------------------
-- PL/pgSQL usa nomes de condicao (unique_violation, no_data_found etc.) em
-- vez de excecoes nomeadas fixas do Oracle. SQLSTATE/SQLERRM tambem existem
-- (via GET STACKED DIAGNOSTICS ou a variavel implicita SQLERRM em contextos
-- de excecao).

CREATE OR REPLACE PROCEDURE inserir_categoria (
    p_categoria_id INTEGER,
    p_nome         VARCHAR
)
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO categoria (categoria_id, nome)
    VALUES (p_categoria_id, p_nome);

    RAISE NOTICE 'Categoria "%" inserida com sucesso.', p_nome;
EXCEPTION
    WHEN unique_violation THEN
        RAISE NOTICE 'Erro: ja existe categoria com este ID ou nome.';
    WHEN OTHERS THEN
        RAISE NOTICE 'Erro inesperado: %', SQLERRM;
END;
$$;

CALL inserir_categoria(1, 'Tecnologia'); -- ja existe -> dispara unique_violation


--------------------------------------------------------------------------------
-- 12. ERRO PERSONALIZADO COM RAISE EXCEPTION
--------------------------------------------------------------------------------
-- O equivalente idiomatico a RAISE_APPLICATION_ERROR do Oracle eh
-- RAISE EXCEPTION, opcionalmente com USING ERRCODE para definir um SQLSTATE
-- proprio (deve seguir o padrao de 5 caracteres alfanumericos).

CREATE OR REPLACE PROCEDURE inserir_livro (
    p_livro_id     INTEGER,
    p_categoria_id INTEGER,
    p_titulo       VARCHAR,
    p_preco        NUMERIC,
    p_estoque      INTEGER
)
LANGUAGE plpgsql
AS $$
BEGIN
    IF p_preco <= 0 THEN
        RAISE EXCEPTION 'O preco do livro deve ser maior que zero.'
            USING ERRCODE = 'P0001';
    END IF;

    IF p_estoque < 0 THEN
        RAISE EXCEPTION 'O estoque nao pode ser negativo.'
            USING ERRCODE = 'P0002';
    END IF;

    INSERT INTO livro (livro_id, categoria_id, titulo, preco, estoque)
    VALUES (p_livro_id, p_categoria_id, p_titulo, p_preco, p_estoque);
END;
$$;

CALL inserir_livro(105, 1, 'Introducao ao PostgreSQL', -10, 5); -- dispara P0001


--------------------------------------------------------------------------------
-- 13. CONTROLE DE TRANSACAO - registro completo de um pedido
--------------------------------------------------------------------------------
-- Diferenca importante: FUNCTIONS em PostgreSQL executam dentro da
-- transacao do chamador e NAO podem conter COMMIT/ROLLBACK. Apenas
-- PROCEDURES (chamadas via CALL, fora de outra transacao explicita) podem
-- controlar a transacao com COMMIT/ROLLBACK internamente.

CREATE OR REPLACE PROCEDURE registrar_pedido_completo (
    p_pedido_id  INTEGER,
    p_cliente_id INTEGER,
    p_livro_id   INTEGER,
    p_quantidade INTEGER
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_preco   livro.preco%TYPE;
    v_estoque livro.estoque%TYPE;
BEGIN
    SELECT preco, estoque INTO v_preco, v_estoque
      FROM livro WHERE livro_id = p_livro_id
      FOR UPDATE;

    IF v_estoque < p_quantidade THEN
        RAISE EXCEPTION 'Estoque insuficiente para o pedido.' USING ERRCODE = 'P0003';
    END IF;

    INSERT INTO pedido (pedido_id, cliente_id, valor_total)
    VALUES (p_pedido_id, p_cliente_id, v_preco * p_quantidade);

    INSERT INTO item_pedido (item_pedido_id, pedido_id, livro_id, quantidade, valor_unitario)
    VALUES (nextval('item_pedido_seq'), p_pedido_id, p_livro_id, p_quantidade, v_preco);

    UPDATE livro SET estoque = estoque - p_quantidade WHERE livro_id = p_livro_id;

    COMMIT;
    RAISE NOTICE 'Pedido % registrado com sucesso.', p_pedido_id;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE NOTICE 'Pedido cancelado (rollback): %', SQLERRM;
        RAISE;
END;
$$;


--------------------------------------------------------------------------------
-- 14. FUNCTION - valor total de um pedido (com base nos itens)
--------------------------------------------------------------------------------
-- Assim como no Oracle, uma FUNCTION em PL/pgSQL devolve um unico valor
-- (RETURNS tipo) e pode ser usada dentro de comandos SQL. IMMUTABLE eh o
-- equivalente conceitual a DETERMINISTIC do Oracle.

CREATE OR REPLACE FUNCTION calcular_valor_total_pedido (
    p_pedido_id INTEGER
)
RETURNS NUMERIC
LANGUAGE plpgsql
AS $$
DECLARE
    v_total NUMERIC(12,2);
BEGIN
    SELECT SUM(quantidade * valor_unitario)
      INTO v_total
      FROM item_pedido
     WHERE pedido_id = p_pedido_id;

    RETURN COALESCE(v_total, 0);
END;
$$;

-- Chamando a function dentro de um SELECT:
SELECT pedido_id, calcular_valor_total_pedido(pedido_id) AS valor_calculado
  FROM pedido
 ORDER BY pedido_id;


--------------------------------------------------------------------------------
-- 15. FUNCTION RETORNANDO CONJUNTO DE LINHAS (RETURNS TABLE)
--------------------------------------------------------------------------------
-- Quando o retorno eh um conjunto de linhas, o idiomatico em PostgreSQL eh
-- RETURNS TABLE(...) ou RETURNS SETOF <tabela> (o equivalente funcional ao
-- SYS_REFCURSOR do Oracle, porem consumido diretamente como uma tabela).

CREATE OR REPLACE FUNCTION obter_livros_por_categoria (
    p_categoria_id INTEGER
)
RETURNS TABLE (
    livro_id INTEGER,
    titulo   VARCHAR,
    preco    NUMERIC,
    estoque  INTEGER
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
        SELECT l.livro_id, l.titulo, l.preco, l.estoque
          FROM livro l
         WHERE l.categoria_id = p_categoria_id
         ORDER BY l.titulo;
END;
$$;

-- Consumo direto, como uma tabela:
SELECT * FROM obter_livros_por_categoria(1);
