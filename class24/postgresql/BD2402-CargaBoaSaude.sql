-- ============================================================================
-- BD2402-CargaBoaSaude.sql
-- Aula 24 - Tutorial passo a passo: carga do banco BoaSaude com volume
-- SGBD: PostgreSQL 17 (container "postgres" do ambiente Docker da disciplina)
--
-- Passo 1 do tutorial Aula_24_..._Tutorial_PostgreSQL.md (banco aula24):
-- 200 medicos, 50 mil pacientes, 300 mil consultas e 20 mil prontuarios,
-- gerados com generate_series. Pode ser reexecutado (apaga e recria tudo).
-- Os passos seguintes estao em BD2403-TutorialIndices.sql.
-- ============================================================================


-- ----------------------------------------------------------------------------
-- SCHEMA BoaSaude + MASSA DE DADOS
-- ----------------------------------------------------------------------------
SET client_min_messages = warning;
DROP TABLE IF EXISTS consulta_com_indices, consulta_sem_indices, agenda_sala, prontuario, consulta, paciente, convenio, medico, especialidade;
RESET client_min_messages;

CREATE TABLE especialidade (
    especialidade_id  INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nome              VARCHAR(80) NOT NULL
);

CREATE TABLE medico (
    medico_id         INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nome              VARCHAR(120) NOT NULL,
    crm               VARCHAR(20) NOT NULL UNIQUE,
    especialidade_id  INTEGER NOT NULL REFERENCES especialidade (especialidade_id)
);

CREATE TABLE convenio (
    convenio_id           INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nome                  VARCHAR(80) NOT NULL,
    percentual_cobertura  NUMERIC(5,2) NOT NULL
);

CREATE TABLE paciente (
    paciente_id      INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nome             VARCHAR(120) NOT NULL,
    cpf              CHAR(11) NOT NULL UNIQUE,
    data_nascimento  DATE NOT NULL,
    sexo             CHAR(1) NOT NULL,
    telefone         VARCHAR(20),
    email            VARCHAR(120)
);

CREATE TABLE consulta (
    consulta_id  BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    paciente_id  INTEGER NOT NULL REFERENCES paciente (paciente_id),
    medico_id    INTEGER NOT NULL REFERENCES medico (medico_id),
    convenio_id  INTEGER REFERENCES convenio (convenio_id),
    data_hora    TIMESTAMP NOT NULL,
    status       VARCHAR(15) NOT NULL CHECK (status IN ('AGENDADA', 'REALIZADA', 'CANCELADA')),
    valor        NUMERIC(10,2) NOT NULL
);

CREATE TABLE prontuario (
    prontuario_id  BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    paciente_id    INTEGER NOT NULL REFERENCES paciente (paciente_id),
    descricao      TEXT,
    data_registro  DATE NOT NULL
);

INSERT INTO especialidade (nome) VALUES
    ('Clinica Geral'), ('Cardiologia'), ('Pediatria'), ('Ortopedia');

INSERT INTO convenio (nome, percentual_cobertura) VALUES
    ('Particular', 0), ('SaudeBem', 80), ('VidaPlena', 100);

INSERT INTO medico (nome, crm, especialidade_id)
SELECT 'Dr(a). Medico ' || g, 'CRM-' || LPAD(g::text, 6, '0'), (g % 4) + 1
FROM   generate_series(1, 200) AS g;

INSERT INTO paciente (nome, cpf, data_nascimento, sexo, telefone, email)
SELECT 'Paciente ' || g,
       LPAD(g::text, 11, '0'),
       DATE '1950-01-01' + (g % 18000),
       CASE g % 3 WHEN 0 THEN 'M' WHEN 1 THEN 'F' ELSE 'O' END,
       '519' || LPAD(g::text, 8, '0'),
       'paciente' || g || '@boasaude.com.br'
FROM   generate_series(1, 50000) AS g;

INSERT INTO consulta (paciente_id, medico_id, convenio_id, data_hora, status, valor)
SELECT (g % 50000) + 1,
       (g % 200) + 1,
       (g % 3) + 1,
       TIMESTAMP '2024-01-01 08:00:00' + ((g % 730) || ' days')::interval
                                       + ((g % 10) || ' hours')::interval,
       CASE g % 20 WHEN 0 THEN 'CANCELADA' WHEN 1 THEN 'AGENDADA' ELSE 'REALIZADA' END,
       ROUND((80 + random() * 420)::numeric, 2)
FROM   generate_series(1, 300000) AS g;

INSERT INTO prontuario (paciente_id, descricao, data_registro)
SELECT (g % 50000) + 1,
       CASE WHEN g % 4 = 0
            THEN 'Paciente relata dor de cabeca recorrente e cansaco. Solicitado exame de sangue.'
            ELSE 'Retorno de rotina. Pressao arterial dentro da normalidade.' END,
       DATE '2024-01-01' + (g % 730)
FROM   generate_series(1, 20000) AS g;

VACUUM ANALYZE;

SELECT relname AS tabela, n_live_tup AS linhas
  FROM pg_stat_user_tables
 ORDER BY n_live_tup DESC;
