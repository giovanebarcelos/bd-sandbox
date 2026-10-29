-- ============================================================================
-- BD2402-CargaBoaSaude.sql
-- Aula 24 - Tutorial passo a passo: carga do banco BoaSaude com volume
-- SGBD: Oracle Database XE 21c (container da Aula 03, usuario bd_aluno)
--
-- Passo 1 do tutorial Aula_24_..._Tutorial_Oracle.md: 200 medicos, 50 mil
-- pacientes, 300 mil consultas e 20 mil prontuarios, gerados com
-- CONNECT BY LEVEL. Pode ser reexecutado (apaga e recria tudo).
-- Os passos seguintes estao em BD2403-TutorialIndices.sql.
-- ============================================================================

SET FEEDBACK ON
SET TIMING ON

BEGIN
    FOR t IN (SELECT table_name FROM user_tables
               WHERE table_name IN ('CONSULTA_COM_INDICES', 'CONSULTA_SEM_INDICES', 'CONSULTA_ORDENADA',
                                    'PRONTUARIO', 'CONSULTA', 'PACIENTE', 'CONVENIO',
                                    'MEDICO', 'ESPECIALIDADE')) LOOP
        EXECUTE IMMEDIATE 'DROP TABLE ' || t.table_name || ' CASCADE CONSTRAINTS PURGE';
    END LOOP;
END;
/

CREATE TABLE especialidade (
    especialidade_id NUMBER(6)    GENERATED ALWAYS AS IDENTITY,
    nome             VARCHAR2(80) NOT NULL,
    CONSTRAINT pk_especialidade PRIMARY KEY (especialidade_id)
);

CREATE TABLE medico (
    medico_id        NUMBER(6)     GENERATED ALWAYS AS IDENTITY,
    nome             VARCHAR2(120) NOT NULL,
    crm              VARCHAR2(20)  NOT NULL,
    especialidade_id NUMBER(6)     NOT NULL,
    CONSTRAINT pk_medico PRIMARY KEY (medico_id),
    CONSTRAINT uq_medico_crm UNIQUE (crm),
    CONSTRAINT fk_medico_especialidade FOREIGN KEY (especialidade_id)
        REFERENCES especialidade (especialidade_id)
);

CREATE TABLE convenio (
    convenio_id          NUMBER(6)    GENERATED ALWAYS AS IDENTITY,
    nome                 VARCHAR2(80) NOT NULL,
    percentual_cobertura NUMBER(5,2)  NOT NULL,
    CONSTRAINT pk_convenio PRIMARY KEY (convenio_id)
);

CREATE TABLE paciente (
    paciente_id     NUMBER(10)    GENERATED ALWAYS AS IDENTITY,
    nome            VARCHAR2(120) NOT NULL,
    cpf             VARCHAR2(11)  NOT NULL,
    data_nascimento DATE          NOT NULL,
    sexo            CHAR(1)       NOT NULL,
    telefone        VARCHAR2(20),
    email           VARCHAR2(120),
    CONSTRAINT pk_paciente PRIMARY KEY (paciente_id),
    CONSTRAINT uq_paciente_cpf UNIQUE (cpf)
);

CREATE TABLE consulta (
    consulta_id NUMBER(12)   GENERATED ALWAYS AS IDENTITY,
    paciente_id NUMBER(10)   NOT NULL,
    medico_id   NUMBER(6)    NOT NULL,
    convenio_id NUMBER(6),
    data_hora   TIMESTAMP    NOT NULL,
    status      VARCHAR2(15) NOT NULL,
    valor       NUMBER(10,2) NOT NULL,
    CONSTRAINT pk_consulta PRIMARY KEY (consulta_id),
    CONSTRAINT fk_consulta_paciente FOREIGN KEY (paciente_id) REFERENCES paciente (paciente_id),
    CONSTRAINT fk_consulta_medico   FOREIGN KEY (medico_id)   REFERENCES medico (medico_id),
    CONSTRAINT fk_consulta_convenio FOREIGN KEY (convenio_id) REFERENCES convenio (convenio_id),
    CONSTRAINT ck_consulta_status CHECK (status IN ('AGENDADA', 'REALIZADA', 'CANCELADA'))
);

CREATE TABLE prontuario (
    prontuario_id  NUMBER(12) GENERATED ALWAYS AS IDENTITY,
    paciente_id    NUMBER(10) NOT NULL,
    descricao      VARCHAR2(400),
    data_registro  DATE NOT NULL,
    CONSTRAINT pk_prontuario PRIMARY KEY (prontuario_id),
    CONSTRAINT fk_prontuario_paciente FOREIGN KEY (paciente_id) REFERENCES paciente (paciente_id)
);

INSERT INTO especialidade (nome) VALUES ('Clinica Geral');
INSERT INTO especialidade (nome) VALUES ('Cardiologia');
INSERT INTO especialidade (nome) VALUES ('Pediatria');
INSERT INTO especialidade (nome) VALUES ('Ortopedia');

INSERT INTO convenio (nome, percentual_cobertura) VALUES ('Particular', 0);
INSERT INTO convenio (nome, percentual_cobertura) VALUES ('SaudeBem', 80);
INSERT INTO convenio (nome, percentual_cobertura) VALUES ('VidaPlena', 100);

INSERT INTO medico (nome, crm, especialidade_id)
SELECT 'Dr(a). Medico ' || LEVEL, 'CRM-' || LPAD(LEVEL, 6, '0'), MOD(LEVEL, 4) + 1
FROM   dual CONNECT BY LEVEL <= 200;

INSERT INTO paciente (nome, cpf, data_nascimento, sexo, telefone, email)
SELECT 'Paciente ' || LEVEL,
       LPAD(LEVEL, 11, '0'),
       DATE '1950-01-01' + MOD(LEVEL, 18000),
       CASE MOD(LEVEL, 3) WHEN 0 THEN 'M' WHEN 1 THEN 'F' ELSE 'O' END,
       '519' || LPAD(LEVEL, 8, '0'),
       'paciente' || LEVEL || '@boasaude.com.br'
FROM   dual CONNECT BY LEVEL <= 50000;

INSERT INTO consulta (paciente_id, medico_id, convenio_id, data_hora, status, valor)
SELECT MOD(LEVEL, 50000) + 1,
       MOD(LEVEL, 200) + 1,
       MOD(LEVEL, 3) + 1,
       TIMESTAMP '2024-01-01 08:00:00' + NUMTODSINTERVAL(MOD(LEVEL, 730), 'DAY')
                                       + NUMTODSINTERVAL(MOD(LEVEL, 10), 'HOUR'),
       CASE MOD(LEVEL, 20) WHEN 0 THEN 'CANCELADA' WHEN 1 THEN 'AGENDADA' ELSE 'REALIZADA' END,
       ROUND(DBMS_RANDOM.VALUE(80, 500), 2)
FROM   dual CONNECT BY LEVEL <= 300000;

INSERT INTO prontuario (paciente_id, descricao, data_registro)
SELECT MOD(LEVEL, 50000) + 1,
       CASE WHEN MOD(LEVEL, 4) = 0
            THEN 'Paciente relata dor de cabeca recorrente e cansaco. Solicitado exame de sangue.'
            ELSE 'Retorno de rotina. Pressao arterial dentro da normalidade.' END,
       DATE '2024-01-01' + MOD(LEVEL, 730)
FROM   dual CONNECT BY LEVEL <= 20000;

COMMIT;

-- estatisticas para o otimizador (equivalente ao ANALYZE do PostgreSQL)
EXEC DBMS_STATS.GATHER_SCHEMA_STATS(USER)

SET TIMING OFF
SELECT table_name, num_rows FROM user_tables
 WHERE table_name IN ('ESPECIALIDADE', 'MEDICO', 'CONVENIO', 'PACIENTE', 'CONSULTA', 'PRONTUARIO')
 ORDER BY num_rows DESC;
