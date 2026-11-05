-- ============================================================================
-- BD3003-TutorialVetcare.sql (PostgreSQL)
-- Aula 30 - Conectividade JDBC e DB-API - preparacao do banco do tutorial
-- Prof. Giovane Barcelos
--
-- Cria o banco vetcare, a tabela funcionarios e o role app_user, que tem SO
-- o necessario para os programas BD3001/BD3002/BD3004 (menor privilegio).
--
-- Execucao (container "postgres" do A1/DBTools/Docker):
--   docker exec -i postgres psql -U postgres < BD3003-TutorialVetcare.sql
-- PowerShell:
--   Get-Content BD3003-TutorialVetcare.sql | docker exec -i postgres psql -U postgres
--
-- Pode ser executado de novo: apaga e recria o banco vetcare.
-- ============================================================================
DROP DATABASE IF EXISTS vetcare WITH (FORCE);
DROP ROLE IF EXISTS app_user;

-- Senha de LABORATORIO: em producao ela viria de um cofre de segredos
CREATE ROLE app_user LOGIN PASSWORD 'senha_segura' CONNECTION LIMIT 10;

CREATE DATABASE vetcare;
\c vetcare

CREATE TABLE funcionarios (
    id       SERIAL PRIMARY KEY,
    nome     VARCHAR(100) NOT NULL,
    cargo    VARCHAR(50)  NOT NULL,
    salario  NUMERIC(10,2)
);

INSERT INTO funcionarios (nome, cargo, salario) VALUES
    ('Ana Souza',     'Veterinario',   6500.00),
    ('Bruno Lima',    'Recepcionista', 2800.00),
    ('Carla Dias',    'Veterinario',   7200.00),
    ('Diego Alves',   'Auxiliar',      2400.00),
    ('Joana D''Arc',  'Veterinario',   6900.00);

-- Menor privilegio: conectar, enxergar o schema e LER a tabela. Nada mais.
REVOKE ALL ON DATABASE vetcare FROM PUBLIC;
GRANT CONNECT ON DATABASE vetcare TO app_user;
GRANT USAGE ON SCHEMA public TO app_user;
GRANT SELECT ON funcionarios TO app_user;

SELECT id, nome, cargo, salario FROM funcionarios ORDER BY id;
