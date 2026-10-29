--------------------------------------------------------------------------------
-- BD1902-TutorialPlPgSql.sql
-- Aula 19 - Tutorial passo a passo: PL/pgSQL (blocos, procedures e functions)
-- SGBD: PostgreSQL 17 (container "postgres" do ambiente Docker da disciplina)
--
-- Roteiro completo do tutorial Aula_19_..._Tutorial_PostgreSQL.md. Cada secao
-- "PASSO N" corresponde a um passo do tutorial. Rode conectado ao banco
-- aula19 (CREATE DATABASE aula19; e depois \c aula19). Os passos 11, 12 e 15
-- tem erros PROPOSITAIS (o script segue em frente no psql).
--------------------------------------------------------------------------------


--------------------------------------------------------------------------------
-- PASSO 1. SCHEMA BookHub (pode ser reexecutado: apaga e recria tudo)
--------------------------------------------------------------------------------

SET client_min_messages = warning;   -- esconde os avisos "does not exist, skipping"
DROP TABLE IF EXISTS item_pedido, pedido, cliente, livro, categoria CASCADE;
DROP SEQUENCE IF EXISTS item_pedido_seq;
RESET client_min_messages;

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

INSERT INTO categoria VALUES (1, 'Tecnologia'), (2, 'Literatura Nacional'), (3, 'Infantil');

INSERT INTO livro VALUES
    (101, 1, 'Banco de Dados Essencial', 89.90, 40),
    (102, 1, 'PL/pgSQL na Pratica',      74.50, 25),
    (103, 2, 'Dom Casmurro',             29.90, 60),
    (104, 3, 'Historias da Floresta',    39.00, 15);

INSERT INTO cliente (cliente_id, nome, email) VALUES
    (1, 'Ana Beatriz Souza',   'ana.souza@exemplo.com'),
    (2, 'Carlos Eduardo Lima', 'carlos.lima@exemplo.com');

INSERT INTO pedido (pedido_id, cliente_id, valor_total) VALUES (1001, 1, 149.70);
INSERT INTO item_pedido VALUES (1, 1001, 101, 1, 89.90), (2, 1001, 103, 2, 29.90);

SELECT livro_id, titulo, preco, estoque FROM livro ORDER BY livro_id;


--------------------------------------------------------------------------------
-- PASSO 2. PRIMEIRO BLOCO ANONIMO (DO $$ ... $$)
--------------------------------------------------------------------------------

DO $$
BEGIN
    RAISE NOTICE 'Ola, PL/pgSQL! Este eh um bloco anonimo.';
END;
$$;


--------------------------------------------------------------------------------
-- PASSO 3. %TYPE, %ROWTYPE, FOUND E SELECT ... INTO STRICT
--------------------------------------------------------------------------------

DO $$
DECLARE
    v_titulo livro.titulo%TYPE;
    v_preco  livro.preco%TYPE;
    v_livro  livro%ROWTYPE;
BEGIN
    SELECT titulo, preco INTO v_titulo, v_preco FROM livro WHERE livro_id = 101;
    RAISE NOTICE 'Livro: % - R$ %', v_titulo, v_preco;

    SELECT * INTO v_livro FROM livro WHERE livro_id = 102;
    RAISE NOTICE 'Titulo: % | Estoque: %', v_livro.titulo, v_livro.estoque;
END;
$$;

-- Sem STRICT, um SELECT INTO que nao acha linha NAO gera erro: a variavel
-- fica NULL e a pseudovariavel FOUND fica false.
DO $$
DECLARE
    v_titulo livro.titulo%TYPE;
BEGIN
    SELECT titulo INTO v_titulo FROM livro WHERE livro_id = 999;
    RAISE NOTICE 'Sem STRICT: titulo = %, FOUND = %', v_titulo, FOUND;
END;
$$;

-- Com STRICT, o comportamento fica igual ao do Oracle: NO_DATA_FOUND
DO $$
DECLARE
    v_titulo livro.titulo%TYPE;
BEGIN
    SELECT titulo INTO STRICT v_titulo FROM livro WHERE livro_id = 999;
EXCEPTION
    WHEN no_data_found THEN
        RAISE NOTICE 'Com STRICT: livro 999 nao existe (no_data_found tratado).';
END;
$$;


--------------------------------------------------------------------------------
-- PASSO 4. FUNCTION SEM PARAMETROS (RETURNS void)
--------------------------------------------------------------------------------

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

SELECT listar_clientes();


--------------------------------------------------------------------------------
-- PASSO 5. PROCEDURE COM PARAMETRO IN
--------------------------------------------------------------------------------

CREATE OR REPLACE PROCEDURE valor_estoque_por_categoria (
    p_nome_categoria VARCHAR
)
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

    RAISE NOTICE 'Valor em estoque de "%": R$ %', p_nome_categoria, COALESCE(v_valor_total, 0);
END;
$$;

CALL valor_estoque_por_categoria('Tecnologia');
CALL valor_estoque_por_categoria('Culinaria');


--------------------------------------------------------------------------------
-- PASSO 6. PROCEDURE COM PARAMETROS OUT (PostgreSQL 14+)
--------------------------------------------------------------------------------

CREATE OR REPLACE PROCEDURE estatisticas_pedidos_mes (
    IN  p_mes         INTEGER,
    OUT p_qtd_pedidos INTEGER,
    OUT p_valor_medio NUMERIC
)
LANGUAGE plpgsql
AS $$
BEGIN
    SELECT COUNT(*), ROUND(COALESCE(AVG(valor_total), 0), 2)
      INTO p_qtd_pedidos, p_valor_medio
      FROM pedido
     WHERE EXTRACT(MONTH FROM data_pedido) = p_mes;
END;
$$;

-- No psql, os parametros OUT recebem NULL na chamada e voltam como uma linha
CALL estatisticas_pedidos_mes(EXTRACT(MONTH FROM CURRENT_DATE)::INTEGER, NULL, NULL);

-- Dentro de PL/pgSQL, os OUT sao recebidos em variaveis
DO $$
DECLARE
    v_qtd   INTEGER;
    v_media NUMERIC;
BEGIN
    CALL estatisticas_pedidos_mes(EXTRACT(MONTH FROM CURRENT_DATE)::INTEGER, v_qtd, v_media);
    RAISE NOTICE 'Pedidos no mes: % | Media: R$ %', v_qtd, v_media;
END;
$$;


--------------------------------------------------------------------------------
-- PASSO 7. IF/ELSIF E CASE
--------------------------------------------------------------------------------

CREATE OR REPLACE PROCEDURE classificar_pedidos_mes (
    p_mes INTEGER
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_total_pedidos INTEGER;
    v_resultado     VARCHAR(60);
BEGIN
    SELECT COUNT(*) INTO v_total_pedidos
      FROM pedido
     WHERE EXTRACT(MONTH FROM data_pedido) = p_mes;

    -- versao IF/ELSIF
    IF v_total_pedidos > 20 THEN
        RAISE NOTICE '[IF]   % pedidos: ACIMA da meta', v_total_pedidos;
    ELSIF v_total_pedidos BETWEEN 10 AND 20 THEN
        RAISE NOTICE '[IF]   % pedidos: DENTRO da meta', v_total_pedidos;
    ELSE
        RAISE NOTICE '[IF]   % pedidos: ABAIXO da meta', v_total_pedidos;
    END IF;

    -- mesma regra com CASE (como expressao)
    v_resultado := CASE
        WHEN v_total_pedidos = 0   THEN 'Nenhum pedido registrado'
        WHEN v_total_pedidos < 10  THEN 'ABAIXO da meta'
        WHEN v_total_pedidos <= 20 THEN 'DENTRO da meta'
        ELSE 'ACIMA da meta'
    END;
    RAISE NOTICE '[CASE] % pedidos: %', v_total_pedidos, v_resultado;
END;
$$;

CALL classificar_pedidos_mes(EXTRACT(MONTH FROM CURRENT_DATE)::INTEGER);

-- Gera mais 11 pedidos no mes atual com um FOR numerico e classifica de novo
DO $$
BEGIN
    FOR i IN 1..11 LOOP
        INSERT INTO pedido (pedido_id, cliente_id, valor_total)
        VALUES (1100 + i, (i % 2) + 1, 50 * i);
    END LOOP;
END;
$$;

CALL classificar_pedidos_mes(EXTRACT(MONTH FROM CURRENT_DATE)::INTEGER);


--------------------------------------------------------------------------------
-- PASSO 8. WHILE LOOP DENTRO DE UMA FUNCTION
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION soma_ate (
    p_limite INTEGER
)
RETURNS INTEGER
LANGUAGE plpgsql
IMMUTABLE
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

SELECT soma_ate(5) AS soma_1_a_5, soma_ate(100) AS soma_1_a_100;


--------------------------------------------------------------------------------
-- PASSO 9. CURSOR EXPLICITO PARAMETRIZADO (OPEN / FETCH / EXIT WHEN / CLOSE)
--------------------------------------------------------------------------------

CREATE OR REPLACE PROCEDURE titulos_por_categoria (
    p_categoria_id INTEGER,
    INOUT p_lista  VARCHAR DEFAULT NULL
)
LANGUAGE plpgsql
AS $$
DECLARE
    cur_livro CURSOR (p_cat INTEGER) FOR
        SELECT titulo FROM livro WHERE categoria_id = p_cat ORDER BY titulo;
    v_titulo livro.titulo%TYPE;
    v_linhas INTEGER := 0;
BEGIN
    p_lista := NULL;
    OPEN cur_livro(p_categoria_id);
    LOOP
        FETCH cur_livro INTO v_titulo;
        EXIT WHEN NOT FOUND;
        v_linhas := v_linhas + 1;
        p_lista := CASE WHEN p_lista IS NULL THEN v_titulo
                        ELSE p_lista || ', ' || v_titulo END;
    END LOOP;
    CLOSE cur_livro;
    RAISE NOTICE 'Linhas lidas pelo cursor: %', v_linhas;
END;
$$;

CALL titulos_por_categoria(1);


--------------------------------------------------------------------------------
-- PASSO 10. TRATAMENTO DE EXCECOES (nomes de condicao)
--------------------------------------------------------------------------------

CREATE OR REPLACE PROCEDURE inserir_categoria (
    p_categoria_id INTEGER,
    p_nome         VARCHAR
)
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO categoria (categoria_id, nome) VALUES (p_categoria_id, p_nome);
    RAISE NOTICE 'Categoria "%" inserida com sucesso.', p_nome;
EXCEPTION
    WHEN unique_violation THEN
        RAISE NOTICE 'Erro: ja existe categoria com este ID ou nome.';
    WHEN OTHERS THEN
        RAISE NOTICE 'Erro inesperado: % (SQLSTATE %)', SQLERRM, SQLSTATE;
        RAISE;
END;
$$;

CALL inserir_categoria(4, 'Culinaria');
CALL inserir_categoria(1, 'Tecnologia');


--------------------------------------------------------------------------------
-- PASSO 11. ERRO DE NEGOCIO COM RAISE EXCEPTION ... USING ERRCODE (erro proposital)
--------------------------------------------------------------------------------

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
            USING ERRCODE = 'P0001', HINT = 'Informe um preco positivo.';
    END IF;
    IF p_estoque < 0 THEN
        RAISE EXCEPTION 'O estoque nao pode ser negativo.'
            USING ERRCODE = 'P0002';
    END IF;
    INSERT INTO livro (livro_id, categoria_id, titulo, preco, estoque)
    VALUES (p_livro_id, p_categoria_id, p_titulo, p_preco, p_estoque);
END;
$$;

CALL inserir_livro(105, 1, 'Introducao ao PostgreSQL', -10, 5);

-- O chamador captura o erro pelo SQLSTATE
DO $$
BEGIN
    CALL inserir_livro(105, 1, 'Introducao ao PostgreSQL', -10, 5);
EXCEPTION
    WHEN SQLSTATE 'P0001' THEN
        RAISE NOTICE 'Capturado no chamador: % (SQLSTATE %)', SQLERRM, SQLSTATE;
END;
$$;


--------------------------------------------------------------------------------
-- PASSO 12. CONTROLE DE TRANSACAO: SO EM PROCEDURE (e fora de bloco EXCEPTION)
--------------------------------------------------------------------------------

-- 12a. COMMIT dentro de FUNCTION e proibido
CREATE OR REPLACE FUNCTION funcao_com_commit()
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE livro SET estoque = estoque WHERE livro_id = 101;
    COMMIT;
END;
$$;

SELECT funcao_com_commit();
DROP FUNCTION funcao_com_commit();

-- 12b. Versao do slide: COMMIT DENTRO de um bloco que tem EXCEPTION.
-- Falha ate no pedido valido: o bloco com EXCEPTION abre uma subtransacao,
-- e o PostgreSQL nao deixa fazer COMMIT enquanto ela esta ativa.
CREATE OR REPLACE PROCEDURE registrar_pedido_completo (
    p_pedido_id  INTEGER,
    p_cliente_id INTEGER,
    p_livro_id   INTEGER,
    p_quantidade INTEGER
)
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO pedido (pedido_id, cliente_id, valor_total)
    VALUES (p_pedido_id, p_cliente_id, 0);
    COMMIT;
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Pedido cancelado (rollback): %', SQLERRM;
        RAISE;
END;
$$;

CALL registrar_pedido_completo(2001, 2, 104, 5);

-- 12c. Versao CORRETA: o trabalho fica num sub-bloco BEGIN ... EXCEPTION ... END
-- (que funciona como um SAVEPOINT implicito) e o COMMIT fica FORA dele.
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
    BEGIN
        SELECT preco, estoque INTO v_preco, v_estoque
          FROM livro WHERE livro_id = p_livro_id
          FOR UPDATE;

        INSERT INTO pedido (pedido_id, cliente_id, valor_total)
        VALUES (p_pedido_id, p_cliente_id, v_preco * p_quantidade);

        INSERT INTO item_pedido (item_pedido_id, pedido_id, livro_id, quantidade, valor_unitario)
        VALUES (nextval('item_pedido_seq'), p_pedido_id, p_livro_id, p_quantidade, v_preco);

        IF v_estoque < p_quantidade THEN
            RAISE EXCEPTION 'Estoque insuficiente para o pedido.' USING ERRCODE = 'P0003';
        END IF;

        UPDATE livro SET estoque = estoque - p_quantidade WHERE livro_id = p_livro_id;
    EXCEPTION
        WHEN OTHERS THEN
            -- ao entrar aqui, tudo o que o sub-bloco fez ja foi desfeito
            RAISE NOTICE 'Pedido cancelado (rollback): %', SQLERRM;
            RAISE;
    END;

    COMMIT;
    RAISE NOTICE 'Pedido % registrado com sucesso.', p_pedido_id;
END;
$$;

-- Pedido valido: 5 unidades do livro 104 (estoque 15 -> 10)
CALL registrar_pedido_completo(2001, 2, 104, 5);

-- Pedido invalido: 999 unidades (erro proposital; pedido e item sao desfeitos)
CALL registrar_pedido_completo(2002, 2, 104, 999);

SELECT livro_id, estoque FROM livro WHERE livro_id = 104;
SELECT pedido_id, valor_total FROM pedido WHERE pedido_id IN (2001, 2002) ORDER BY pedido_id;

-- 12d. Uma PROCEDURE com COMMIT nao pode ser chamada dentro de BEGIN ... COMMIT
BEGIN;
CALL registrar_pedido_completo(2003, 1, 101, 1);
ROLLBACK;


--------------------------------------------------------------------------------
-- PASSO 13. FUNCTION USADA DENTRO DE UM SELECT (volatilidade STABLE)
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION calcular_valor_total_pedido (
    p_pedido_id INTEGER
)
RETURNS NUMERIC
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    v_total NUMERIC(12,2);
BEGIN
    SELECT SUM(quantidade * valor_unitario) INTO v_total
      FROM item_pedido
     WHERE pedido_id = p_pedido_id;
    RETURN COALESCE(v_total, 0);
END;
$$;

SELECT pedido_id, valor_total, calcular_valor_total_pedido(pedido_id) AS valor_calculado
  FROM pedido
 WHERE pedido_id IN (1001, 2001)
 ORDER BY pedido_id;


--------------------------------------------------------------------------------
-- PASSO 14. FUNCTION QUE DEVOLVE UMA TABELA (RETURNS TABLE)
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION obter_livros_por_categoria (
    p_categoria_id INTEGER
)
RETURNS TABLE (livro_id INTEGER, titulo VARCHAR, preco NUMERIC, estoque INTEGER)
LANGUAGE plpgsql
STABLE
AS $$
BEGIN
    RETURN QUERY
        SELECT l.livro_id, l.titulo, l.preco, l.estoque
          FROM livro l
         WHERE l.categoria_id = p_categoria_id
         ORDER BY l.titulo;
END;
$$;

SELECT * FROM obter_livros_por_categoria(1);

-- Como e uma "tabela", da para filtrar, juntar e agregar
SELECT COUNT(*) AS qtd, SUM(preco * estoque) AS valor_estoque
  FROM obter_livros_por_categoria(1);


--------------------------------------------------------------------------------
-- PASSO 15. DEPURACAO: ERRO DE SINTAXE x ERRO SO NA EXECUCAO
--------------------------------------------------------------------------------

-- 15a. Erro de sintaxe (falta o ; depois do RAISE): rejeitado ja no CREATE
CREATE OR REPLACE PROCEDURE procedure_com_erro()
LANGUAGE plpgsql
AS $$
BEGIN
    RAISE NOTICE 'falta o ponto e virgula'
END;
$$;

-- 15b. Tabela inexistente: o CREATE passa, o erro so aparece no CALL
CREATE OR REPLACE PROCEDURE procedure_tabela_errada()
LANGUAGE plpgsql
AS $$
BEGIN
    DELETE FROM tabela_que_nao_existe;
END;
$$;

CALL procedure_tabela_errada();
DROP PROCEDURE procedure_tabela_errada();

-- 15c. Rotinas criadas neste banco (equivalente ao \df do psql)
SELECT p.proname AS rotina,
       CASE p.prokind WHEN 'f' THEN 'FUNCTION' WHEN 'p' THEN 'PROCEDURE' END AS tipo
  FROM pg_proc p
  JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname = 'public'
 ORDER BY p.proname;
