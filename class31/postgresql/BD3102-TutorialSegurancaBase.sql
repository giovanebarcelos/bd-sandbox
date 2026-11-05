-- ============================================================================
-- BD3102-TutorialSegurancaBase.sql (PostgreSQL)
-- Aula 31 - Seguranca: Usuarios, Roles, Grants e Views - base do tutorial
-- Prof. Giovane Barcelos
--
-- Cria (ou recria) o schema "clinica" no banco vetcare, com as tabelas e os
-- dados ficticios da clinica veterinaria - SEM nenhuma regra de seguranca.
-- As roles, os GRANTs, a view e o RLS sao feitos passo a passo no tutorial
-- (ou de uma vez com o BD3103-TutorialSegurancaCompleto.sql).
--
-- Execucao (container "postgres" do A1/DBTools/Docker):
--   docker exec -i postgres psql -U postgres < BD3102-TutorialSegurancaBase.sql
-- PowerShell:
--   Get-Content BD3102-TutorialSegurancaBase.sql | docker exec -i postgres psql -U postgres
--
-- Pode ser executado de novo: apaga o schema e as roles do tutorial.
-- Dados ficticios (LGPD): nenhum CPF ou telefone pertence a uma pessoa real.
-- ============================================================================

-- Cria o banco vetcare se ele ainda nao existir (o tutorial da Aula 30 cria)
SELECT 'CREATE DATABASE vetcare'
 WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'vetcare') \gexec
\c vetcare

-- Remove as roles do tutorial (DROP OWNED revoga os privilegios delas aqui)
DO $$
DECLARE r text;
BEGIN
  FOREACH r IN ARRAY ARRAY['gestor_rui', 'dra_ana', 'dr_carlos', 'recep_bia',
                           'vet_admin', 'vet_veterinario', 'vet_recepcao'] LOOP
    IF EXISTS (SELECT FROM pg_roles WHERE rolname = r) THEN
      EXECUTE format('DROP OWNED BY %I', r);
      EXECUTE format('DROP ROLE %I', r);
    END IF;
  END LOOP;
END $$;

DROP SCHEMA IF EXISTS clinica CASCADE;
CREATE SCHEMA clinica;

-- Ninguem alem dos convidados entra no banco (o padrao e CONNECT para PUBLIC)
REVOKE ALL ON DATABASE vetcare FROM PUBLIC;

CREATE TABLE clinica.veterinarios (
    id     INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nome   VARCHAR(100) NOT NULL,
    crmv   VARCHAR(20)  NOT NULL UNIQUE,
    login  VARCHAR(30)  NOT NULL UNIQUE     -- role do PostgreSQL de cada veterinario
);

CREATE TABLE clinica.tutores (
    id        INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nome      VARCHAR(100) NOT NULL,
    cpf       CHAR(14)     NOT NULL UNIQUE,  -- formato 000.000.000-00
    telefone  VARCHAR(20),
    email     VARCHAR(100)
);

CREATE TABLE clinica.animais (
    id        INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nome      VARCHAR(60) NOT NULL,
    especie   VARCHAR(30) NOT NULL,
    tutor_id  INT NOT NULL REFERENCES clinica.tutores (id)
);

CREATE TABLE clinica.consultas (
    id              INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    animal_id       INT NOT NULL REFERENCES clinica.animais (id),
    veterinario_id  INT NOT NULL REFERENCES clinica.veterinarios (id),
    data            DATE NOT NULL DEFAULT CURRENT_DATE,
    diagnostico     TEXT,
    valor           NUMERIC(10,2) NOT NULL
);

CREATE TABLE clinica.agendamentos (
    id              INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    animal_id       INT NOT NULL REFERENCES clinica.animais (id),
    veterinario_id  INT NOT NULL REFERENCES clinica.veterinarios (id),
    data_hora       TIMESTAMP NOT NULL,
    criado_por      VARCHAR(30) NOT NULL DEFAULT current_user
);

INSERT INTO clinica.veterinarios (nome, crmv, login) VALUES
    ('Dra. Ana Souza',    'CRMV-RS 1001', 'dra_ana'),
    ('Dr. Carlos Mendes', 'CRMV-RS 1002', 'dr_carlos');

INSERT INTO clinica.tutores (nome, cpf, telefone, email) VALUES
    ('Marina Costa',  '111.222.333-44', '(51) 99999-0001', 'marina@exemplo.com'),
    ('Paulo Lima',    '222.333.444-55', '(51) 99999-0002', 'paulo@exemplo.com'),
    ('Renata Alves',  '333.444.555-66', '(51) 99999-0003', 'renata@exemplo.com');

INSERT INTO clinica.animais (nome, especie, tutor_id) VALUES
    ('Thor',  'Cachorro', 1),
    ('Mimi',  'Gato',     1),
    ('Bidu',  'Cachorro', 2),
    ('Luna',  'Gato',     3);

INSERT INTO clinica.consultas (animal_id, veterinario_id, data, diagnostico, valor) VALUES
    (1, 1, '2026-10-01', 'Vacinacao anual',        180.00),
    (2, 1, '2026-10-03', 'Otite leve',             220.00),
    (3, 2, '2026-10-05', 'Fratura na pata',        950.00),
    (4, 2, '2026-10-08', 'Check-up',               150.00),
    (1, 2, '2026-10-12', 'Retorno - sem alteracao', 90.00);

INSERT INTO clinica.agendamentos (animal_id, veterinario_id, data_hora, criado_por) VALUES
    (3, 2, '2026-11-10 14:00', 'postgres');

SELECT 'veterinarios' AS tabela, count(*) FROM clinica.veterinarios
UNION ALL SELECT 'tutores',      count(*) FROM clinica.tutores
UNION ALL SELECT 'animais',      count(*) FROM clinica.animais
UNION ALL SELECT 'consultas',    count(*) FROM clinica.consultas
UNION ALL SELECT 'agendamentos', count(*) FROM clinica.agendamentos;
