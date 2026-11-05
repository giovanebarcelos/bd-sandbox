-- ============================================================================
-- BD3102-TutorialSegurancaBase.sql (Oracle)
-- Aula 31 - Seguranca: Usuarios, Roles, Grants e Views - base do tutorial
-- Prof. Giovane Barcelos
--
-- Cria (ou recria) o schema CLINICA no PDB FREEPDB1, com as tabelas e os dados
-- ficticios da clinica veterinaria - SEM nenhuma regra de seguranca. Os
-- usuarios, as roles, os GRANTs, a view e o VPD sao feitos passo a passo no
-- tutorial (ou de uma vez com o BD3103-TutorialSegurancaCompleto.sql).
--
-- Executar como SYSTEM (container "oracle" do A1/DBTools, profile "oracle"):
--   docker exec -i oracle sqlplus -s system/oracle@localhost/FREEPDB1 < BD3102-TutorialSegurancaBase.sql
-- PowerShell:
--   Get-Content BD3102-TutorialSegurancaBase.sql | docker exec -i oracle sqlplus -s system/oracle@localhost/FREEPDB1
--
-- Pode ser executado de novo: apaga os usuarios, as roles e o schema.
-- Dados ficticios (LGPD): nenhum CPF ou telefone pertence a uma pessoa real.
-- ============================================================================
SET FEEDBACK OFF
SET LINESIZE 120

-- Remove o que o tutorial cria (IF EXISTS: Oracle 23ai em diante)
BEGIN
  FOR p IN (SELECT policy_name FROM dba_policies WHERE object_owner = 'CLINICA') LOOP
    DBMS_RLS.DROP_POLICY('CLINICA', 'CONSULTAS', p.policy_name);
  END LOOP;
END;
/
DROP USER IF EXISTS gestor_rui CASCADE;
DROP USER IF EXISTS dra_ana CASCADE;
DROP USER IF EXISTS dr_carlos CASCADE;
DROP USER IF EXISTS recep_bia CASCADE;
DROP ROLE IF EXISTS vet_admin;
DROP ROLE IF EXISTS vet_veterinario;
DROP ROLE IF EXISTS vet_recepcao;
DROP USER IF EXISTS clinica CASCADE;

-- Dono dos objetos SEM senha (schema-only account): ninguem faz login como
-- CLINICA, entao uma senha vazada nao entrega o dono das tabelas.
CREATE USER clinica NO AUTHENTICATION
    DEFAULT TABLESPACE users QUOTA UNLIMITED ON users;

CREATE TABLE clinica.veterinarios (
    id     NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nome   VARCHAR2(100) NOT NULL,
    crmv   VARCHAR2(20)  NOT NULL UNIQUE,
    login  VARCHAR2(30)  NOT NULL UNIQUE     -- usuario Oracle de cada veterinario
);

CREATE TABLE clinica.tutores (
    id        NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nome      VARCHAR2(100) NOT NULL,
    cpf       CHAR(14)      NOT NULL UNIQUE,  -- formato 000.000.000-00
    telefone  VARCHAR2(20),
    email     VARCHAR2(100)
);

CREATE TABLE clinica.animais (
    id        NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nome      VARCHAR2(60) NOT NULL,
    especie   VARCHAR2(30) NOT NULL,
    tutor_id  NUMBER NOT NULL REFERENCES clinica.tutores (id)
);

CREATE TABLE clinica.consultas (
    id              NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    animal_id       NUMBER NOT NULL REFERENCES clinica.animais (id),
    veterinario_id  NUMBER NOT NULL REFERENCES clinica.veterinarios (id),
    data            DATE DEFAULT SYSDATE NOT NULL,
    diagnostico     VARCHAR2(400),
    valor           NUMBER(10,2) NOT NULL
);

CREATE TABLE clinica.agendamentos (
    id              NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    animal_id       NUMBER NOT NULL REFERENCES clinica.animais (id),
    veterinario_id  NUMBER NOT NULL REFERENCES clinica.veterinarios (id),
    data_hora       TIMESTAMP NOT NULL,
    criado_por      VARCHAR2(30) DEFAULT SYS_CONTEXT('USERENV', 'SESSION_USER') NOT NULL
);

INSERT INTO clinica.veterinarios (nome, crmv, login) VALUES ('Dra. Ana Souza',    'CRMV-RS 1001', 'DRA_ANA');
INSERT INTO clinica.veterinarios (nome, crmv, login) VALUES ('Dr. Carlos Mendes', 'CRMV-RS 1002', 'DR_CARLOS');

INSERT INTO clinica.tutores (nome, cpf, telefone, email) VALUES ('Marina Costa', '111.222.333-44', '(51) 99999-0001', 'marina@exemplo.com');
INSERT INTO clinica.tutores (nome, cpf, telefone, email) VALUES ('Paulo Lima',   '222.333.444-55', '(51) 99999-0002', 'paulo@exemplo.com');
INSERT INTO clinica.tutores (nome, cpf, telefone, email) VALUES ('Renata Alves', '333.444.555-66', '(51) 99999-0003', 'renata@exemplo.com');

INSERT INTO clinica.animais (nome, especie, tutor_id) VALUES ('Thor', 'Cachorro', 1);
INSERT INTO clinica.animais (nome, especie, tutor_id) VALUES ('Mimi', 'Gato',     1);
INSERT INTO clinica.animais (nome, especie, tutor_id) VALUES ('Bidu', 'Cachorro', 2);
INSERT INTO clinica.animais (nome, especie, tutor_id) VALUES ('Luna', 'Gato',     3);

INSERT INTO clinica.consultas (animal_id, veterinario_id, data, diagnostico, valor) VALUES (1, 1, DATE '2026-10-01', 'Vacinacao anual',         180);
INSERT INTO clinica.consultas (animal_id, veterinario_id, data, diagnostico, valor) VALUES (2, 1, DATE '2026-10-03', 'Otite leve',              220);
INSERT INTO clinica.consultas (animal_id, veterinario_id, data, diagnostico, valor) VALUES (3, 2, DATE '2026-10-05', 'Fratura na pata',         950);
INSERT INTO clinica.consultas (animal_id, veterinario_id, data, diagnostico, valor) VALUES (4, 2, DATE '2026-10-08', 'Check-up',                150);
INSERT INTO clinica.consultas (animal_id, veterinario_id, data, diagnostico, valor) VALUES (1, 2, DATE '2026-10-12', 'Retorno - sem alteracao',  90);

INSERT INTO clinica.agendamentos (animal_id, veterinario_id, data_hora, criado_por)
VALUES (3, 2, TIMESTAMP '2026-11-10 14:00:00', 'SYSTEM');
COMMIT;

SET FEEDBACK ON
COLUMN tabela FORMAT A15
SELECT 'veterinarios' AS tabela, COUNT(*) AS linhas FROM clinica.veterinarios
UNION ALL SELECT 'tutores',      COUNT(*) FROM clinica.tutores
UNION ALL SELECT 'animais',      COUNT(*) FROM clinica.animais
UNION ALL SELECT 'consultas',    COUNT(*) FROM clinica.consultas
UNION ALL SELECT 'agendamentos', COUNT(*) FROM clinica.agendamentos;
EXIT
