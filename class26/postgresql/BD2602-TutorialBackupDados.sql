-- ============================================================================
-- BD2602-TutorialBackupDados.sql
-- Aula 26 - Tutorial passo a passo: banco de exemplo para backup e restore
-- SGBD: PostgreSQL 17 (container "postgres" do ambiente Docker da disciplina)
--
-- Passo 1 do tutorial Aula_26_..._Tutorial_PostgreSQL.md. Rode conectado
-- ao banco aula26 (CREATE DATABASE aula26; \c aula26). Cria uma loja com
-- 5 mil clientes e 100 mil pedidos, uma view, um indice e um papel
-- (analista) com permissao de leitura: tudo o que um backup precisa levar.
-- ============================================================================

SET client_min_messages = warning;
DROP VIEW  IF EXISTS vw_total_cliente;
DROP TABLE IF EXISTS pedido, cliente CASCADE;
RESET client_min_messages;

CREATE TABLE cliente (
    cliente_id  INT PRIMARY KEY,
    nome        VARCHAR(100) NOT NULL,
    cidade      VARCHAR(60)
);

CREATE TABLE pedido (
    pedido_id    INT PRIMARY KEY,
    cliente_id   INT NOT NULL REFERENCES cliente (cliente_id),
    data_pedido  DATE NOT NULL,
    valor        NUMERIC(10,2) NOT NULL
);

CREATE INDEX idx_pedido_cliente ON pedido (cliente_id);

CREATE VIEW vw_total_cliente AS
SELECT c.nome, SUM(p.valor) AS total
  FROM cliente c JOIN pedido p USING (cliente_id)
 GROUP BY c.nome;

INSERT INTO cliente
SELECT g, 'Cliente ' || g, 'Cidade ' || (g % 20) FROM generate_series(1, 5000) AS g;

INSERT INTO pedido
SELECT g, (g % 5000) + 1, DATE '2025-01-01' + (g % 365), ROUND((100 + (g % 900) + (g % 7) * 0.13)::numeric, 2)
  FROM generate_series(1, 100000) AS g;

-- um papel (role) e uma permissao: objetos GLOBAIS, que o pg_dump nao leva
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'analista') THEN
        CREATE ROLE analista LOGIN PASSWORD 'analista';
    END IF;
END;
$$;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO analista;

-- "impressao digital" do banco, para comparar depois de cada restore
SELECT (SELECT COUNT(*) FROM cliente) AS clientes,
       (SELECT COUNT(*) FROM pedido)  AS pedidos,
       (SELECT SUM(valor) FROM pedido) AS soma_valor;
