--------------------------------------------------------------------------------
-- BD1801-PlSql.sql
-- Aula 18 - PL/SQL: blocos anonimos, procedures e functions
-- SGBD: Oracle Database (testado em Oracle Database XE 21c)
--
-- Conceitos adaptados (traduzidos de MySQL para PL/SQL) a partir do material
-- "DerekBanas SQL Tutorial" (stored procedures, functions, cursors, excecoes
-- e transacoes), reaproveitando o estudo de caso BookHub (livraria online)
-- ja utilizado nas aulas de SQL do curso (UA4/UA5).
--------------------------------------------------------------------------------


--------------------------------------------------------------------------------
-- 0. SCHEMA DE APOIO (BookHub) - execute uma vez antes dos blocos abaixo
--------------------------------------------------------------------------------

DROP TABLE item_pedido CASCADE CONSTRAINTS;
DROP TABLE pedido CASCADE CONSTRAINTS;
DROP TABLE cliente CASCADE CONSTRAINTS;
DROP TABLE livro CASCADE CONSTRAINTS;
DROP TABLE categoria CASCADE CONSTRAINTS;

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

DROP SEQUENCE item_pedido_seq;
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

INSERT INTO pedido (pedido_id, cliente_id) VALUES (1001, 1);
INSERT INTO item_pedido VALUES (1, 1001, 101, 1, 89.90);
INSERT INTO item_pedido VALUES (2, 1001, 103, 2, 29.90);

COMMIT;


--------------------------------------------------------------------------------
-- 1. BLOCO ANONIMO SIMPLES
--------------------------------------------------------------------------------
-- Estrutura basica: [DECLARE] ... BEGIN ... [EXCEPTION] ... END;
-- DBMS_OUTPUT.PUT_LINE eh o equivalente Oracle para "imprimir na tela".

SET SERVEROUTPUT ON;

BEGIN
    DBMS_OUTPUT.PUT_LINE('Ola, PL/SQL! Este eh um bloco anonimo.');
END;
/


--------------------------------------------------------------------------------
-- 2. BLOCO ANONIMO COM VARIAVEIS E %TYPE
--------------------------------------------------------------------------------
-- %TYPE ancora o tipo da variavel ao tipo de uma coluna existente, evitando
-- que a variavel fique desalinhada caso a coluna mude de tipo no futuro.

DECLARE
    v_titulo   livro.titulo%TYPE;
    v_preco    livro.preco%TYPE;
BEGIN
    SELECT titulo, preco
      INTO v_titulo, v_preco
      FROM livro
     WHERE livro_id = 101;

    DBMS_OUTPUT.PUT_LINE('Livro: ' || v_titulo || ' - R$ ' || v_preco);
END;
/


--------------------------------------------------------------------------------
-- 3. BLOCO ANONIMO COM %ROWTYPE
--------------------------------------------------------------------------------
-- %ROWTYPE cria um "registro" com uma coluna para cada coluna da tabela (ou
-- do cursor), permitindo capturar a linha inteira em uma unica variavel.

DECLARE
    v_livro    livro%ROWTYPE;
BEGIN
    SELECT *
      INTO v_livro
      FROM livro
     WHERE livro_id = 102;

    DBMS_OUTPUT.PUT_LINE('Titulo: ' || v_livro.titulo);
    DBMS_OUTPUT.PUT_LINE('Estoque atual: ' || v_livro.estoque);
END;
/


--------------------------------------------------------------------------------
-- 4. PROCEDURE SEM PARAMETROS - lista os nomes dos clientes
--------------------------------------------------------------------------------
-- Equivalente traduzido de "get_customers" (DerekBanas, MySQL) usando um
-- cursor implicito (FOR ... IN ... LOOP), a forma idiomatica em PL/SQL.

CREATE OR REPLACE PROCEDURE listar_clientes
IS
BEGIN
    FOR r_cliente IN (SELECT nome, email FROM cliente ORDER BY nome) LOOP
        DBMS_OUTPUT.PUT_LINE(r_cliente.nome || ' <' || r_cliente.email || '>');
    END LOOP;
END listar_clientes;
/

-- Execucao:
BEGIN
    listar_clientes;
END;
/


--------------------------------------------------------------------------------
-- 5. PROCEDURE COM PARAMETRO IN - valor de estoque por categoria
--------------------------------------------------------------------------------
-- Equivalente traduzido de "get_supplier_value".

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
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        DBMS_OUTPUT.PUT_LINE('Categoria nao encontrada.');
END valor_estoque_por_categoria;
/

BEGIN
    valor_estoque_por_categoria('Tecnologia');
END;
/


--------------------------------------------------------------------------------
-- 6. PROCEDURE COM PARAMETROS IN E OUT - estatisticas de pedidos do mes
--------------------------------------------------------------------------------
-- Equivalente traduzido de "get_customer_birthday" (uso de OUT). IN passa
-- por valor (somente leitura dentro da procedure); OUT devolve valor ao
-- chamador; IN OUT faz as duas coisas.

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

DECLARE
    v_qtd    NUMBER;
    v_media  NUMBER;
BEGIN
    estatisticas_pedidos_mes(EXTRACT(MONTH FROM SYSDATE), v_qtd, v_media);
    DBMS_OUTPUT.PUT_LINE('Pedidos no mes atual: ' || v_qtd || ' | Media: R$ ' || v_media);
END;
/


--------------------------------------------------------------------------------
-- 7. IF / ELSIF / ELSE - classificacao do volume de pedidos do mes
--------------------------------------------------------------------------------
-- Equivalente traduzido de "check_month_orders" (versao IF).

CREATE OR REPLACE PROCEDURE classificar_pedidos_mes_if (
    p_mes IN NUMBER
)
IS
    v_total_pedidos NUMBER;
BEGIN
    SELECT COUNT(*)
      INTO v_total_pedidos
      FROM pedido
     WHERE EXTRACT(MONTH FROM data_pedido) = p_mes;

    IF v_total_pedidos > 20 THEN
        DBMS_OUTPUT.PUT_LINE(v_total_pedidos || ' pedidos: volume ACIMA da meta');
    ELSIF v_total_pedidos BETWEEN 10 AND 20 THEN
        DBMS_OUTPUT.PUT_LINE(v_total_pedidos || ' pedidos: volume DENTRO da meta');
    ELSE
        DBMS_OUTPUT.PUT_LINE(v_total_pedidos || ' pedidos: volume ABAIXO da meta');
    END IF;
END classificar_pedidos_mes_if;
/


--------------------------------------------------------------------------------
-- 8. CASE - mesma logica reescrita com CASE
--------------------------------------------------------------------------------
-- Equivalente traduzido de "check_month_orders" (versao CASE).

CREATE OR REPLACE PROCEDURE classificar_pedidos_mes_case (
    p_mes IN NUMBER
)
IS
    v_total_pedidos NUMBER;
    v_resultado     VARCHAR2(60);
BEGIN
    SELECT COUNT(*)
      INTO v_total_pedidos
      FROM pedido
     WHERE EXTRACT(MONTH FROM data_pedido) = p_mes;

    CASE
        WHEN v_total_pedidos = 0 THEN
            v_resultado := 'Nenhum pedido registrado';
        WHEN v_total_pedidos < 10 THEN
            v_resultado := 'Volume ABAIXO da meta';
        WHEN v_total_pedidos <= 20 THEN
            v_resultado := 'Volume DENTRO da meta';
        ELSE
            v_resultado := 'Volume ACIMA da meta';
    END CASE;

    DBMS_OUTPUT.PUT_LINE(v_total_pedidos || ' pedidos: ' || v_resultado);
END classificar_pedidos_mes_case;
/


--------------------------------------------------------------------------------
-- 9. LOOP / WHILE - soma acumulada
--------------------------------------------------------------------------------
-- Equivalente traduzido de "loop_test".

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

BEGIN
    DBMS_OUTPUT.PUT_LINE('Soma de 1 a 5 = ' || soma_ate(5));
END;
/


--------------------------------------------------------------------------------
-- 10. CURSOR EXPLICITO - lista de titulos concatenados por categoria
--------------------------------------------------------------------------------
-- Equivalente traduzido de "get_companies": abre um cursor, percorre linha a
-- linha com FETCH/EXIT WHEN %NOTFOUND e concatena o resultado.

CREATE OR REPLACE PROCEDURE titulos_por_categoria (
    p_categoria_id IN  categoria.categoria_id%TYPE,
    p_lista        OUT VARCHAR2
)
IS
    CURSOR cur_livro IS
        SELECT titulo FROM livro WHERE categoria_id = p_categoria_id;

    v_titulo livro.titulo%TYPE;
BEGIN
    p_lista := NULL;

    OPEN cur_livro;
    LOOP
        FETCH cur_livro INTO v_titulo;
        EXIT WHEN cur_livro%NOTFOUND;

        IF p_lista IS NULL THEN
            p_lista := v_titulo;
        ELSE
            p_lista := p_lista || ', ' || v_titulo;
        END IF;
    END LOOP;
    CLOSE cur_livro;
END titulos_por_categoria;
/

DECLARE
    v_lista VARCHAR2(2000);
BEGIN
    titulos_por_categoria(1, v_lista);
    DBMS_OUTPUT.PUT_LINE('Titulos de Tecnologia: ' || v_lista);
END;
/


--------------------------------------------------------------------------------
-- 11. TRATAMENTO DE EXCECOES - insercao de categoria com nome duplicado
--------------------------------------------------------------------------------
-- Equivalente traduzido de "create_product_type" (bloqueio da chave
-- duplicada). DUP_VAL_ON_INDEX eh a excecao predefinida do Oracle para
-- violacao de UNIQUE/PRIMARY KEY (analoga ao erro 1062 do MySQL).

CREATE OR REPLACE PROCEDURE inserir_categoria (
    p_categoria_id IN categoria.categoria_id%TYPE,
    p_nome         IN categoria.nome%TYPE
)
IS
BEGIN
    INSERT INTO categoria (categoria_id, nome)
    VALUES (p_categoria_id, p_nome);

    DBMS_OUTPUT.PUT_LINE('Categoria "' || p_nome || '" inserida com sucesso.');
EXCEPTION
    WHEN DUP_VAL_ON_INDEX THEN
        DBMS_OUTPUT.PUT_LINE('Erro: ja existe categoria com este ID ou nome.');
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Erro inesperado: ' || SQLERRM);
END inserir_categoria;
/

BEGIN
    inserir_categoria(1, 'Tecnologia'); -- ja existe -> dispara DUP_VAL_ON_INDEX
END;
/


--------------------------------------------------------------------------------
-- 12. ERRO PERSONALIZADO COM RAISE_APPLICATION_ERROR
--------------------------------------------------------------------------------
-- Equivalente traduzido de "insert_product_type" com SIGNAL. Em PL/SQL o
-- equivalente idiomatico a SIGNAL eh RAISE_APPLICATION_ERROR, que usa uma
-- faixa reservada de codigos (-20000 a -20999) para erros definidos pelo
-- desenvolvedor.

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
END inserir_livro;
/

BEGIN
    inserir_livro(105, 1, 'Introducao ao Oracle', -10, 5); -- dispara erro -20001
END;
/


--------------------------------------------------------------------------------
-- 13. CONTROLE DE TRANSACAO - registro completo de um pedido
--------------------------------------------------------------------------------
-- Equivalente traduzido de "insert_sales_item" (START TRANSACTION / COMMIT /
-- ROLLBACK). Em Oracle toda instrucao DML ja abre uma transacao implicita;
-- SAVEPOINT permite reverter parcialmente sem descartar o que veio antes.

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

    IF v_estoque < p_quantidade THEN
        RAISE_APPLICATION_ERROR(-20003, 'Estoque insuficiente para o pedido.');
    END IF;

    INSERT INTO pedido (pedido_id, cliente_id, valor_total)
    VALUES (p_pedido_id, p_cliente_id, v_preco * p_quantidade);

    INSERT INTO item_pedido (item_pedido_id, pedido_id, livro_id, quantidade, valor_unitario)
    VALUES (item_pedido_seq.NEXTVAL, p_pedido_id, p_livro_id, p_quantidade, v_preco);

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


--------------------------------------------------------------------------------
-- 14. FUNCTION - valor total de um pedido (com base nos itens)
--------------------------------------------------------------------------------
-- Equivalente traduzido de "get_order_total". Uma FUNCTION em PL/SQL sempre
-- devolve um unico valor via RETURN e pode ser usada dentro de comandos SQL.

CREATE OR REPLACE FUNCTION calcular_valor_total_pedido (
    p_pedido_id IN item_pedido.pedido_id%TYPE
) RETURN NUMBER
DETERMINISTIC
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

-- Chamando a function dentro de um SELECT:
SELECT pedido_id, calcular_valor_total_pedido(pedido_id) AS valor_calculado
  FROM pedido
 ORDER BY pedido_id;


--------------------------------------------------------------------------------
-- 15. FUNCTION RETORNANDO CURSOR (SYS_REFCURSOR)
--------------------------------------------------------------------------------
-- Quando uma function precisa devolver um conjunto de linhas (nao apenas um
-- escalar), o tipo de retorno idiomatico em Oracle eh SYS_REFCURSOR.

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

-- Consumo tipico (em SQL*Plus/SQL Developer):
-- VARIABLE cur REFCURSOR;
-- BEGIN :cur := obter_livros_por_categoria(1); END;
-- /
-- PRINT cur;
