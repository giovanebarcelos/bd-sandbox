-- ============================================================================
-- BD2401-Indices.sql
-- Aula 24 - Indices: tipos e planos de execucao - ORACLE
-- Disciplina: Banco de Dados | Prof. Giovane Barcelos
--
-- Objetivo: reconstruir o schema BoaSaude com VOLUME de dados realista e
-- demonstrar, com EXPLAIN PLAN + DBMS_XPLAN.DISPLAY, o efeito de indices
-- B-tree (comum, composto, funcional) e Bitmap sobre o plano de execucao.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1) Esquema BoaSaude (igual a Aula 23, + tabela PRONTUARIO)
-- ----------------------------------------------------------------------------
DROP TABLE prontuario PURGE;
DROP TABLE consulta PURGE;
DROP TABLE paciente PURGE;
DROP TABLE convenio PURGE;
DROP TABLE medico PURGE;
DROP TABLE especialidade PURGE;

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
    descricao      CLOB,
    data_registro  DATE NOT NULL,
    CONSTRAINT pk_prontuario PRIMARY KEY (prontuario_id),
    CONSTRAINT fk_prontuario_paciente FOREIGN KEY (paciente_id) REFERENCES paciente (paciente_id)
);

-- ----------------------------------------------------------------------------
-- 2) Massa de dados (volume suficiente para o otimizador preferir indice)
-- ----------------------------------------------------------------------------
INSERT INTO especialidade (nome) VALUES ('Clinica Geral');
INSERT INTO especialidade (nome) VALUES ('Cardiologia');
INSERT INTO especialidade (nome) VALUES ('Pediatria');
INSERT INTO especialidade (nome) VALUES ('Ortopedia');

INSERT INTO convenio (nome, percentual_cobertura) VALUES ('Particular', 0);
INSERT INTO convenio (nome, percentual_cobertura) VALUES ('SaudeBem', 80);
INSERT INTO convenio (nome, percentual_cobertura) VALUES ('VidaPlena', 100);

-- 200 medicos
INSERT INTO medico (nome, crm, especialidade_id)
SELECT 'Dr(a). Medico ' || LEVEL,
       'CRM-' || LPAD(LEVEL, 6, '0'),
       MOD(LEVEL, 4) + 1
FROM   dual
CONNECT BY LEVEL <= 200;

-- 50.000 pacientes
INSERT INTO paciente (nome, cpf, data_nascimento, sexo, telefone, email)
SELECT 'Paciente ' || LEVEL,
       LPAD(LEVEL, 11, '0'),
       DATE '1950-01-01' + MOD(LEVEL, 18000),
       CASE MOD(LEVEL, 3) WHEN 0 THEN 'M' WHEN 1 THEN 'F' ELSE 'O' END,
       '519' || LPAD(LEVEL, 8, '0'),
       'paciente' || LEVEL || '@boasaude.com.br'
FROM   dual
CONNECT BY LEVEL <= 50000;

-- 300.000 consultas (distribuidas nos ultimos ~2 anos)
INSERT INTO consulta (paciente_id, medico_id, convenio_id, data_hora, status, valor)
SELECT MOD(LEVEL, 50000) + 1,
       MOD(LEVEL, 200) + 1,
       MOD(LEVEL, 3) + 1,
       TIMESTAMP '2024-01-01 08:00:00' + NUMTODSINTERVAL(MOD(LEVEL, 730) , 'DAY')
                                       + NUMTODSINTERVAL(MOD(LEVEL, 10), 'HOUR'),
       CASE MOD(LEVEL, 20) WHEN 0 THEN 'CANCELADA' WHEN 1 THEN 'AGENDADA' ELSE 'REALIZADA' END,
       ROUND(DBMS_RANDOM.VALUE(80, 500), 2)
FROM   dual
CONNECT BY LEVEL <= 300000;

INSERT INTO prontuario (paciente_id, descricao, data_registro)
SELECT MOD(LEVEL, 50000) + 1,
       TO_CLOB('Paciente relata dor de cabeca recorrente e cansaco. ' ||
               'Pressao arterial dentro da normalidade. Solicitado exame de sangue.'),
       DATE '2024-01-01' + MOD(LEVEL, 730)
FROM   dual
CONNECT BY LEVEL <= 20000;

COMMIT;

EXEC DBMS_STATS.GATHER_TABLE_STATS(USER, 'PACIENTE');
EXEC DBMS_STATS.GATHER_TABLE_STATS(USER, 'CONSULTA');
EXEC DBMS_STATS.GATHER_TABLE_STATS(USER, 'MEDICO');
EXEC DBMS_STATS.GATHER_TABLE_STATS(USER, 'PRONTUARIO');

-- ----------------------------------------------------------------------------
-- 3) ANTES do indice: consulta por CPF faz FULL TABLE SCAN
-- ----------------------------------------------------------------------------
-- (CPF ja tem UNIQUE INDEX automatico pela constraint; para fins didaticos,
--  a primeira demonstracao usa uma coluna SEM indice: consulta.data_hora)

EXPLAIN PLAN FOR
SELECT consulta_id, paciente_id, status, valor
FROM   consulta
WHERE  data_hora BETWEEN TIMESTAMP '2025-06-01 00:00:00' AND TIMESTAMP '2025-06-07 23:59:59';

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY);
-- Esperado: TABLE ACCESS FULL em CONSULTA (sem indice na coluna data_hora)

-- ----------------------------------------------------------------------------
-- 4) Indice B-TREE composto (medico_id, data_hora) — agenda por medico
-- ----------------------------------------------------------------------------
CREATE INDEX idx_consulta_medico_data ON consulta (medico_id, data_hora);

EXPLAIN PLAN FOR
SELECT consulta_id, data_hora, status
FROM   consulta
WHERE  medico_id = 42
AND    data_hora BETWEEN TIMESTAMP '2025-06-01 00:00:00' AND TIMESTAMP '2025-06-07 23:59:59';

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY);
-- Esperado: INDEX RANGE SCAN em IDX_CONSULTA_MEDICO_DATA seguido de
-- TABLE ACCESS BY INDEX ROWID BATCHED (busca rapida, sem varrer a tabela toda)

-- ----------------------------------------------------------------------------
-- 5) Indice B-TREE funcional — busca case-insensitive por nome
-- ----------------------------------------------------------------------------
EXPLAIN PLAN FOR
SELECT paciente_id, nome FROM paciente WHERE UPPER(nome) = 'PACIENTE 12345';
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY);
-- Esperado (antes): TABLE ACCESS FULL, pois nao existe indice sobre UPPER(nome)

CREATE INDEX idx_paciente_nome_upper ON paciente (UPPER(nome));

EXPLAIN PLAN FOR
SELECT paciente_id, nome FROM paciente WHERE UPPER(nome) = 'PACIENTE 12345';
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY);
-- Esperado (depois): INDEX RANGE SCAN em IDX_PACIENTE_NOME_UPPER

-- ----------------------------------------------------------------------------
-- 6) Indice BITMAP — colunas de baixa cardinalidade (status, sexo)
--    Recurso Enterprise Edition; ideal para colunas com poucos valores
--    distintos em tabelas de leitura predominante (BI/relatorios), NAO
--    recomendado para tabelas com muitas escritas concorrentes (lock de
--    granularidade maior que o B-tree).
-- ----------------------------------------------------------------------------
EXPLAIN PLAN FOR
SELECT status, COUNT(*) FROM consulta WHERE status = 'CANCELADA' GROUP BY status;
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY);
-- Esperado (antes): TABLE ACCESS FULL

CREATE BITMAP INDEX idx_consulta_status_bmp ON consulta (status);

EXPLAIN PLAN FOR
SELECT status, COUNT(*) FROM consulta WHERE status = 'CANCELADA' GROUP BY status;
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY);
-- Esperado (depois): BITMAP INDEX SINGLE VALUE em IDX_CONSULTA_STATUS_BMP

-- Combinacao de bitmaps (AND) e muito eficiente para filtros multiplos:
EXPLAIN PLAN FOR
SELECT COUNT(*) FROM consulta WHERE status = 'REALIZADA' AND convenio_id = 2;
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY);
-- Esperado: BITMAP AND combinando os bitmaps de status e convenio_id
-- (crie tambem idx_consulta_convenio_bmp para observar o BITMAP AND)
CREATE BITMAP INDEX idx_consulta_convenio_bmp ON consulta (convenio_id);

-- ----------------------------------------------------------------------------
-- 7) Prevencao de conflito de horario (equivalente ao EXCLUDE/GiST do Postgres)
--    Oracle nao possui tipos de intervalo nem indice GiST; a validacao de
--    sobreposicao de horarios do mesmo medico e feita via trigger + consulta,
--    apoiada pelo indice B-tree composto criado no passo 4.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE TRIGGER trg_consulta_sem_conflito
BEFORE INSERT OR UPDATE ON consulta
FOR EACH ROW
DECLARE
    v_conflitos NUMBER;
BEGIN
    SELECT COUNT(*) INTO v_conflitos
    FROM   consulta
    WHERE  medico_id = :NEW.medico_id
    AND    status <> 'CANCELADA'
    AND    ABS(EXTRACT(MINUTE FROM (data_hora - :NEW.data_hora)) ) < 30
    AND    consulta_id <> NVL(:NEW.consulta_id, -1);

    IF v_conflitos > 0 THEN
        RAISE_APPLICATION_ERROR(-20001, 'Conflito de horario para este medico.');
    END IF;
END;
/

-- ----------------------------------------------------------------------------
-- 8) Limpeza dos planos armazenados (boa pratica ao final da sessao didatica)
-- ----------------------------------------------------------------------------
-- DELETE FROM plan_table;
