-- ============================================================================
-- BD2603-TutorialBackupDados.sql
-- Aula 26 - Tutorial passo a passo: dados de exemplo para backup no Oracle
-- SGBD: Oracle XE 21c, container bd-oracle-xe-full (BD2602-DockerComposeFull.yml)
--
-- Passo 1 do tutorial Aula_26_..._Tutorial_Oracle.md. Rode como bd_aluno:
--   sqlplus bd_aluno/bd_aluno_pwd@//localhost/XEPDB1 @/tmp/BD2603-TutorialBackupDados.sql
-- Cria uma loja com 5 mil clientes e 100 mil pedidos, a mesma do tutorial
-- PostgreSQL, para comparar a "impressao digital" depois de cada restore.
-- ============================================================================

BEGIN
    FOR t IN (SELECT table_name FROM user_tables WHERE table_name IN ('PEDIDO', 'CLIENTE')) LOOP
        EXECUTE IMMEDIATE 'DROP TABLE ' || t.table_name || ' CASCADE CONSTRAINTS PURGE';
    END LOOP;
END;
/

CREATE TABLE cliente (
    cliente_id  NUMBER PRIMARY KEY,
    nome        VARCHAR2(100) NOT NULL,
    cidade      VARCHAR2(60)
);

CREATE TABLE pedido (
    pedido_id    NUMBER PRIMARY KEY,
    cliente_id   NUMBER NOT NULL REFERENCES cliente (cliente_id),
    data_pedido  DATE NOT NULL,
    valor        NUMBER(10,2) NOT NULL
);

CREATE INDEX idx_pedido_cliente ON pedido (cliente_id);

INSERT INTO cliente
SELECT LEVEL, 'Cliente ' || LEVEL, 'Cidade ' || MOD(LEVEL, 20) FROM dual CONNECT BY LEVEL <= 5000;

INSERT INTO pedido
SELECT LEVEL, MOD(LEVEL, 5000) + 1, DATE '2025-01-01' + MOD(LEVEL, 365),
       100 + MOD(LEVEL, 900) + MOD(LEVEL, 7) * 0.13
  FROM dual CONNECT BY LEVEL <= 100000;

COMMIT;

-- "impressao digital" do banco, para comparar depois de cada restore
SELECT (SELECT COUNT(*) FROM cliente) AS clientes,
       (SELECT COUNT(*) FROM pedido)  AS pedidos,
       (SELECT SUM(valor) FROM pedido) AS soma_valor
  FROM dual;
