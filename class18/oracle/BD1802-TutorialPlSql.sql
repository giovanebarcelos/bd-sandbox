--------------------------------------------------------------------------------
-- BD1802-TutorialPlSql.sql
-- Aula 18 - Tutorial passo a passo: PL/SQL (blocos, procedures e functions)
-- SGBD: Oracle Database XE 21c (container da Aula 03, usuario bd_aluno)
--
-- Roteiro completo do tutorial Aula_18_..._Tutorial_Oracle.md. Cada secao
-- "PASSO N" corresponde a um passo do tutorial. Pode ser executado inteiro
-- (@BD1802-TutorialPlSql.sql no SQL*Plus) ou passo a passo, copiando cada
-- secao. Os passos 11 e 12 terminam em erro DE PROPOSITO (erros de negocio).
--------------------------------------------------------------------------------

SET SERVEROUTPUT ON
SET LINESIZE 150
SET PAGESIZE 50
COLUMN titulo      FORMAT A30
COLUMN text        FORMAT A75
COLUMN object_name FORMAT A30
COLUMN v_lista     FORMAT A60


--------------------------------------------------------------------------------
-- PASSO 1. SCHEMA BookHub (pode ser reexecutado: apaga e recria tudo)
--------------------------------------------------------------------------------

BEGIN
    FOR t IN (SELECT table_name FROM user_tables
               WHERE table_name IN ('ITEM_PEDIDO', 'PEDIDO', 'CLIENTE', 'LIVRO', 'CATEGORIA')) LOOP
        EXECUTE IMMEDIATE 'DROP TABLE ' || t.table_name || ' CASCADE CONSTRAINTS PURGE';
    END LOOP;
    FOR s IN (SELECT sequence_name FROM user_sequences WHERE sequence_name = 'ITEM_PEDIDO_SEQ') LOOP
        EXECUTE IMMEDIATE 'DROP SEQUENCE ' || s.sequence_name;
    END LOOP;
END;
/

CREATE TABLE categoria (
    categoria_id   NUMBER(6)      NOT NULL,
    nome           VARCHAR2(60)   NOT NULL,
    CONSTRAINT categoria_pk PRIMARY KEY (categoria_id),
    CONSTRAINT categoria_nome_uk UNIQUE (nome)
);

CREATE TABLE livro (
    livro_id       NUMBER(6)      NOT NULL,
    categoria_id   NUMBER(6)      NOT NULL,
    titulo         VARCHAR2(120)  NOT NULL,
    preco          NUMBER(8,2)    NOT NULL,
    estoque        NUMBER(6)      DEFAULT 0 NOT NULL,
    CONSTRAINT livro_pk PRIMARY KEY (livro_id),
    CONSTRAINT livro_categoria_fk FOREIGN KEY (categoria_id)
        REFERENCES categoria (categoria_id),
    CONSTRAINT livro_preco_ck CHECK (preco > 0),
    CONSTRAINT livro_estoque_ck CHECK (estoque >= 0)
);

CREATE TABLE cliente (
    cliente_id     NUMBER(6)      NOT NULL,
    nome           VARCHAR2(80)   NOT NULL,
    email          VARCHAR2(120)  NOT NULL,
    data_cadastro  DATE           DEFAULT SYSDATE NOT NULL,
    CONSTRAINT cliente_pk PRIMARY KEY (cliente_id)
);

CREATE TABLE pedido (
    pedido_id       NUMBER(6)     NOT NULL,
    cliente_id      NUMBER(6)     NOT NULL,
    data_pedido     DATE          DEFAULT SYSDATE NOT NULL,
    valor_total     NUMBER(10,2)  DEFAULT 0,
    CONSTRAINT pedido_pk PRIMARY KEY (pedido_id),
    CONSTRAINT pedido_cliente_fk FOREIGN KEY (cliente_id)
        REFERENCES cliente (cliente_id)
);

CREATE TABLE item_pedido (
    item_pedido_id  NUMBER(6)     NOT NULL,
    pedido_id       NUMBER(6)     NOT NULL,
    livro_id        NUMBER(6)     NOT NULL,
    quantidade      NUMBER(4)     NOT NULL,
    valor_unitario  NUMBER(8,2)   NOT NULL,
    CONSTRAINT item_pedido_pk PRIMARY KEY (item_pedido_id),
    CONSTRAINT item_pedido_pedido_fk FOREIGN KEY (pedido_id)
        REFERENCES pedido (pedido_id),
    CONSTRAINT item_pedido_livro_fk FOREIGN KEY (livro_id)
        REFERENCES livro (livro_id)
);

CREATE SEQUENCE item_pedido_seq START WITH 100 INCREMENT BY 1;

INSERT INTO categoria VALUES (1, 'Tecnologia');
INSERT INTO categoria VALUES (2, 'Literatura Nacional');
INSERT INTO categoria VALUES (3, 'Infantil');

INSERT INTO livro VALUES (101, 1, 'Banco de Dados Essencial',  89.90, 40);
INSERT INTO livro VALUES (102, 1, 'PL/SQL na Pratica',         74.50, 25);
INSERT INTO livro VALUES (103, 2, 'Dom Casmurro',              29.90, 60);
INSERT INTO livro VALUES (104, 3, 'Historias da Floresta',     39.00, 15);

INSERT INTO cliente (cliente_id, nome, email) VALUES (1, 'Ana Beatriz Souza', 'ana.souza@exemplo.com');
INSERT INTO cliente (cliente_id, nome, email) VALUES (2, 'Carlos Eduardo Lima', 'carlos.lima@exemplo.com');

INSERT INTO pedido (pedido_id, cliente_id, valor_total) VALUES (1001, 1, 149.70);
INSERT INTO item_pedido VALUES (1, 1001, 101, 1, 89.90);
INSERT INTO item_pedido VALUES (2, 1001, 103, 2, 29.90);

COMMIT;

SELECT livro_id, titulo, preco, estoque FROM livro ORDER BY livro_id;


--------------------------------------------------------------------------------
-- PASSO 2. PRIMEIRO BLOCO ANONIMO
--------------------------------------------------------------------------------

BEGIN
    DBMS_OUTPUT.PUT_LINE('Ola, PL/SQL! Este eh um bloco anonimo.');
END;
/


--------------------------------------------------------------------------------
-- PASSO 3. VARIAVEIS, %TYPE, %ROWTYPE E NO_DATA_FOUND
--------------------------------------------------------------------------------

DECLARE
    v_titulo   livro.titulo%TYPE;
    v_preco    livro.preco%TYPE;
    v_livro    livro%ROWTYPE;
BEGIN
    SELECT titulo, preco INTO v_titulo, v_preco FROM livro WHERE livro_id = 101;
    DBMS_OUTPUT.PUT_LINE('Livro: ' || v_titulo || ' - R$ ' || v_preco);

    SELECT * INTO v_livro FROM livro WHERE livro_id = 102;
    DBMS_OUTPUT.PUT_LINE('Titulo: ' || v_livro.titulo || ' | Estoque: ' || v_livro.estoque);
END;
/

-- SELECT ... INTO que nao encontra linha dispara NO_DATA_FOUND
DECLARE
    v_titulo livro.titulo%TYPE;
BEGIN
    SELECT titulo INTO v_titulo FROM livro WHERE livro_id = 999;
    DBMS_OUTPUT.PUT_LINE('Nunca chega aqui: ' || v_titulo);
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        DBMS_OUTPUT.PUT_LINE('Livro 999 nao existe (NO_DATA_FOUND tratado).');
END;
/


--------------------------------------------------------------------------------
-- PASSO 4. PROCEDURE SEM PARAMETROS
--------------------------------------------------------------------------------

CREATE OR REPLACE PROCEDURE listar_clientes
IS
BEGIN
    FOR r_cliente IN (SELECT nome, email FROM cliente ORDER BY nome) LOOP
        DBMS_OUTPUT.PUT_LINE(r_cliente.nome || ' <' || r_cliente.email || '>');
    END LOOP;
END listar_clientes;
/

EXEC listar_clientes


--------------------------------------------------------------------------------
-- PASSO 5. PROCEDURE COM PARAMETRO IN
--------------------------------------------------------------------------------

CREATE OR REPLACE PROCEDURE valor_estoque_por_categoria (
    p_nome_categoria IN categoria.nome%TYPE
)
IS
    v_valor_total  NUMBER(12,2);
BEGIN
    SELECT SUM(l.preco * l.estoque)
      INTO v_valor_total
      FROM livro l
      JOIN categoria c ON c.categoria_id = l.categoria_id
     WHERE c.nome = p_nome_categoria;

    DBMS_OUTPUT.PUT_LINE('Valor em estoque de "' || p_nome_categoria ||
                          '": R$ ' || NVL(v_valor_total, 0));
END valor_estoque_por_categoria;
/

EXEC valor_estoque_por_categoria('Tecnologia')
EXEC valor_estoque_por_categoria('Culinaria')


--------------------------------------------------------------------------------
-- PASSO 6. PARAMETROS IN E OUT (variaveis de ligacao do SQL*Plus)
--------------------------------------------------------------------------------

CREATE OR REPLACE PROCEDURE estatisticas_pedidos_mes (
    p_mes         IN  NUMBER,
    p_qtd_pedidos OUT NUMBER,
    p_valor_medio OUT NUMBER
)
IS
BEGIN
    SELECT COUNT(*), NVL(AVG(valor_total), 0)
      INTO p_qtd_pedidos, p_valor_medio
      FROM pedido
     WHERE EXTRACT(MONTH FROM data_pedido) = p_mes;
END estatisticas_pedidos_mes;
/

VARIABLE v_qtd   NUMBER
VARIABLE v_media NUMBER
EXEC estatisticas_pedidos_mes(EXTRACT(MONTH FROM SYSDATE), :v_qtd, :v_media)
PRINT v_qtd v_media


--------------------------------------------------------------------------------
-- PASSO 7. IF/ELSIF E CASE
--------------------------------------------------------------------------------

CREATE OR REPLACE PROCEDURE classificar_pedidos_mes (
    p_mes IN NUMBER
)
IS
    v_total_pedidos NUMBER;
    v_resultado     VARCHAR2(60);
BEGIN
    SELECT COUNT(*) INTO v_total_pedidos
      FROM pedido
     WHERE EXTRACT(MONTH FROM data_pedido) = p_mes;

    -- versao IF/ELSIF
    IF v_total_pedidos > 20 THEN
        DBMS_OUTPUT.PUT_LINE('[IF]   ' || v_total_pedidos || ' pedidos: ACIMA da meta');
    ELSIF v_total_pedidos BETWEEN 10 AND 20 THEN
        DBMS_OUTPUT.PUT_LINE('[IF]   ' || v_total_pedidos || ' pedidos: DENTRO da meta');
    ELSE
        DBMS_OUTPUT.PUT_LINE('[IF]   ' || v_total_pedidos || ' pedidos: ABAIXO da meta');
    END IF;

    -- mesma regra com CASE
    CASE
        WHEN v_total_pedidos = 0  THEN v_resultado := 'Nenhum pedido registrado';
        WHEN v_total_pedidos < 10 THEN v_resultado := 'ABAIXO da meta';
        WHEN v_total_pedidos <= 20 THEN v_resultado := 'DENTRO da meta';
        ELSE v_resultado := 'ACIMA da meta';
    END CASE;
    DBMS_OUTPUT.PUT_LINE('[CASE] ' || v_total_pedidos || ' pedidos: ' || v_resultado);
END classificar_pedidos_mes;
/

EXEC classificar_pedidos_mes(EXTRACT(MONTH FROM SYSDATE))

-- Gera mais 11 pedidos no mes atual com um FOR numerico e classifica de novo
BEGIN
    FOR i IN 1..11 LOOP
        INSERT INTO pedido (pedido_id, cliente_id, valor_total)
        VALUES (1100 + i, MOD(i, 2) + 1, 50 * i);
    END LOOP;
    COMMIT;
END;
/

EXEC classificar_pedidos_mes(EXTRACT(MONTH FROM SYSDATE))


--------------------------------------------------------------------------------
-- PASSO 8. WHILE LOOP DENTRO DE UMA FUNCTION
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION soma_ate (
    p_limite IN NUMBER
) RETURN NUMBER
IS
    v_indice NUMBER := 1;
    v_soma   NUMBER := 0;
BEGIN
    WHILE v_indice <= p_limite LOOP
        v_soma   := v_soma + v_indice;
        v_indice := v_indice + 1;
    END LOOP;
    RETURN v_soma;
END soma_ate;
/

SELECT soma_ate(5) AS soma_1_a_5, soma_ate(100) AS soma_1_a_100 FROM dual;


--------------------------------------------------------------------------------
-- PASSO 9. CURSOR EXPLICITO (OPEN / FETCH / EXIT WHEN / CLOSE)
--------------------------------------------------------------------------------

CREATE OR REPLACE PROCEDURE titulos_por_categoria (
    p_categoria_id IN  categoria.categoria_id%TYPE,
    p_lista        OUT VARCHAR2
)
IS
    CURSOR cur_livro IS
        SELECT titulo FROM livro WHERE categoria_id = p_categoria_id ORDER BY titulo;
    v_titulo livro.titulo%TYPE;
BEGIN
    p_lista := NULL;
    OPEN cur_livro;
    LOOP
        FETCH cur_livro INTO v_titulo;
        EXIT WHEN cur_livro%NOTFOUND;
        p_lista := CASE WHEN p_lista IS NULL THEN v_titulo
                        ELSE p_lista || ', ' || v_titulo END;
    END LOOP;
    DBMS_OUTPUT.PUT_LINE('Linhas lidas pelo cursor: ' || cur_livro%ROWCOUNT);
    CLOSE cur_livro;
END titulos_por_categoria;
/

VARIABLE v_lista VARCHAR2(2000)
EXEC titulos_por_categoria(1, :v_lista)
PRINT v_lista


--------------------------------------------------------------------------------
-- PASSO 10. TRATAMENTO DE EXCECOES PREDEFINIDAS
--------------------------------------------------------------------------------

CREATE OR REPLACE PROCEDURE inserir_categoria (
    p_categoria_id IN categoria.categoria_id%TYPE,
    p_nome         IN categoria.nome%TYPE
)
IS
BEGIN
    INSERT INTO categoria (categoria_id, nome) VALUES (p_categoria_id, p_nome);
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('Categoria "' || p_nome || '" inserida com sucesso.');
EXCEPTION
    WHEN DUP_VAL_ON_INDEX THEN
        DBMS_OUTPUT.PUT_LINE('Erro: ja existe categoria com este ID ou nome.');
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Erro inesperado: ' || SQLERRM);
        RAISE;
END inserir_categoria;
/

EXEC inserir_categoria(4, 'Culinaria')
EXEC inserir_categoria(1, 'Tecnologia')


--------------------------------------------------------------------------------
-- PASSO 11. ERRO DE NEGOCIO COM RAISE_APPLICATION_ERROR (termina em ORA-20001)
--------------------------------------------------------------------------------

CREATE OR REPLACE PROCEDURE inserir_livro (
    p_livro_id     IN livro.livro_id%TYPE,
    p_categoria_id IN livro.categoria_id%TYPE,
    p_titulo       IN livro.titulo%TYPE,
    p_preco        IN livro.preco%TYPE,
    p_estoque      IN livro.estoque%TYPE
)
IS
BEGIN
    IF p_preco <= 0 THEN
        RAISE_APPLICATION_ERROR(-20001, 'O preco do livro deve ser maior que zero.');
    END IF;
    IF p_estoque < 0 THEN
        RAISE_APPLICATION_ERROR(-20002, 'O estoque nao pode ser negativo.');
    END IF;
    INSERT INTO livro (livro_id, categoria_id, titulo, preco, estoque)
    VALUES (p_livro_id, p_categoria_id, p_titulo, p_preco, p_estoque);
    COMMIT;
END inserir_livro;
/

EXEC inserir_livro(105, 1, 'Introducao ao Oracle', -10, 5)

-- O chamador pode capturar o codigo -20001 com PRAGMA EXCEPTION_INIT
DECLARE
    e_preco_invalido EXCEPTION;
    PRAGMA EXCEPTION_INIT(e_preco_invalido, -20001);
BEGIN
    inserir_livro(105, 1, 'Introducao ao Oracle', -10, 5);
EXCEPTION
    WHEN e_preco_invalido THEN
        DBMS_OUTPUT.PUT_LINE('Capturado no chamador: ' || SQLERRM);
END;
/


--------------------------------------------------------------------------------
-- PASSO 12. TRANSACAO DENTRO DE PROCEDURE (SAVEPOINT / ROLLBACK TO)
--------------------------------------------------------------------------------

CREATE OR REPLACE PROCEDURE registrar_pedido_completo (
    p_pedido_id   IN pedido.pedido_id%TYPE,
    p_cliente_id  IN pedido.cliente_id%TYPE,
    p_livro_id    IN livro.livro_id%TYPE,
    p_quantidade  IN NUMBER
)
IS
    v_preco   livro.preco%TYPE;
    v_estoque livro.estoque%TYPE;
BEGIN
    SAVEPOINT antes_do_pedido;

    SELECT preco, estoque INTO v_preco, v_estoque
      FROM livro WHERE livro_id = p_livro_id
      FOR UPDATE;

    INSERT INTO pedido (pedido_id, cliente_id, valor_total)
    VALUES (p_pedido_id, p_cliente_id, v_preco * p_quantidade);

    INSERT INTO item_pedido (item_pedido_id, pedido_id, livro_id, quantidade, valor_unitario)
    VALUES (item_pedido_seq.NEXTVAL, p_pedido_id, p_livro_id, p_quantidade, v_preco);

    IF v_estoque < p_quantidade THEN
        RAISE_APPLICATION_ERROR(-20003, 'Estoque insuficiente para o pedido.');
    END IF;

    UPDATE livro SET estoque = estoque - p_quantidade WHERE livro_id = p_livro_id;

    COMMIT;
    DBMS_OUTPUT.PUT_LINE('Pedido ' || p_pedido_id || ' registrado com sucesso.');
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK TO antes_do_pedido;
        DBMS_OUTPUT.PUT_LINE('Pedido cancelado (rollback): ' || SQLERRM);
        RAISE;
END registrar_pedido_completo;
/

-- 12a. Pedido valido: 5 unidades do livro 104 (estoque 15 -> 10)
EXEC registrar_pedido_completo(2001, 2, 104, 5)

-- 12b. Pedido invalido: 999 unidades (o pedido e o item ja inseridos sao desfeitos)
EXEC registrar_pedido_completo(2002, 2, 104, 999)

SELECT livro_id, estoque FROM livro WHERE livro_id = 104;
SELECT pedido_id, valor_total FROM pedido WHERE pedido_id IN (2001, 2002) ORDER BY pedido_id;


--------------------------------------------------------------------------------
-- PASSO 13. FUNCTION USADA DENTRO DE UM SELECT
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION calcular_valor_total_pedido (
    p_pedido_id IN item_pedido.pedido_id%TYPE
) RETURN NUMBER
IS
    v_total NUMBER(12,2);
BEGIN
    SELECT SUM(quantidade * valor_unitario)
      INTO v_total
      FROM item_pedido
     WHERE pedido_id = p_pedido_id;
    RETURN NVL(v_total, 0);
END calcular_valor_total_pedido;
/

SELECT pedido_id, valor_total, calcular_valor_total_pedido(pedido_id) AS valor_calculado
  FROM pedido
 WHERE pedido_id IN (1001, 2001)
 ORDER BY pedido_id;


--------------------------------------------------------------------------------
-- PASSO 14. FUNCTION QUE DEVOLVE UM CONJUNTO DE LINHAS (SYS_REFCURSOR)
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION obter_livros_por_categoria (
    p_categoria_id IN livro.categoria_id%TYPE
) RETURN SYS_REFCURSOR
IS
    v_cursor SYS_REFCURSOR;
BEGIN
    OPEN v_cursor FOR
        SELECT livro_id, titulo, preco, estoque
          FROM livro
         WHERE categoria_id = p_categoria_id
         ORDER BY titulo;
    RETURN v_cursor;
END obter_livros_por_categoria;
/

VARIABLE cur REFCURSOR
EXEC :cur := obter_livros_por_categoria(1)
PRINT cur


--------------------------------------------------------------------------------
-- PASSO 15. DEPURACAO: ERRO DE COMPILACAO, SHOW ERRORS E USER_ERRORS
--------------------------------------------------------------------------------

-- Falta o ponto e virgula depois do PUT_LINE: a procedure fica INVALID
CREATE OR REPLACE PROCEDURE procedure_com_erro
IS
BEGIN
    DBMS_OUTPUT.PUT_LINE('falta o ponto e virgula')
END procedure_com_erro;
/

SHOW ERRORS PROCEDURE procedure_com_erro

SELECT line, position, SUBSTR(text, 1, 80) AS text
  FROM user_errors
 WHERE name = 'PROCEDURE_COM_ERRO';

SELECT object_name, object_type, status
  FROM user_objects
 WHERE object_type IN ('PROCEDURE', 'FUNCTION')
 ORDER BY object_name;

DROP PROCEDURE procedure_com_erro;
