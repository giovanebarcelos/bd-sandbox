-- ============================================================================
-- BD0801-TiposDeDados.sql
-- Aula 08: Modelagem Física - Tipos de Dados e Armazenamento (Oracle)
-- Disciplina: Banco de Dados | UA3 - Modelagem Logica/Fisica e Tipos de Chave
--
-- Aplica tipos fisicos, tablespace e parametros de armazenamento ao esquema
-- logico produzido na Aula 07 (estudo de caso: sistema academico simplificado).
-- ============================================================================

-- 1. Tablespace dedicada ao domínio acadêmico -------------------------------
CREATE TABLESPACE ts_academico
    DATAFILE 'ts_academico01.dbf' SIZE 100M
    AUTOEXTEND ON NEXT 10M MAXSIZE 500M
    LOGGING
    EXTENT MANAGEMENT LOCAL
    SEGMENT SPACE MANAGEMENT AUTO;

-- 2. Entidades fortes ---------------------------------------------------------

CREATE TABLE ALUNO (
    matricula        NUMBER(10)          NOT NULL,
    nome             VARCHAR2(120 CHAR)  NOT NULL,
    data_nascimento  DATE,
    email            VARCHAR2(120 CHAR),
    endereco_rua     VARCHAR2(120 CHAR),
    endereco_numero  VARCHAR2(10 CHAR),
    endereco_cidade  VARCHAR2(80 CHAR),
    endereco_uf      CHAR(2),
    CONSTRAINT pk_aluno PRIMARY KEY (matricula)
)
TABLESPACE ts_academico
PCTFREE 10
PCTUSED 60
STORAGE (INITIAL 64K NEXT 64K PCTINCREASE 0);

COMMENT ON TABLE ALUNO IS 'Entidade forte: aluno do sistema academico';
COMMENT ON COLUMN ALUNO.matricula IS 'Chave primaria - matricula institucional';
COMMENT ON COLUMN ALUNO.endereco_uf IS 'Atributo composto (endereco) achatado - UF com 2 caracteres fixos';

CREATE TABLE SALA (
    id          NUMBER(6)          NOT NULL,
    bloco       VARCHAR2(10 CHAR),
    capacidade  NUMBER(4),
    CONSTRAINT pk_sala PRIMARY KEY (id)
)
TABLESPACE ts_academico;

CREATE TABLE PROFESSOR (
    registro   NUMBER(10)          NOT NULL,
    nome       VARCHAR2(120 CHAR)  NOT NULL,
    titulacao  VARCHAR2(40 CHAR),
    sala_id    NUMBER(6),
    CONSTRAINT pk_professor PRIMARY KEY (registro),
    CONSTRAINT uq_professor_sala UNIQUE (sala_id),
    CONSTRAINT fk_professor_sala FOREIGN KEY (sala_id) REFERENCES SALA (id)
)
TABLESPACE ts_academico;

CREATE TABLE DISCIPLINA (
    codigo          VARCHAR2(10 CHAR)  NOT NULL,
    nome            VARCHAR2(120 CHAR) NOT NULL,
    carga_horaria   NUMBER(4),
    CONSTRAINT pk_disciplina PRIMARY KEY (codigo)
)
TABLESPACE ts_academico;

-- 3. Atributo multivalorado (tabela filha) -----------------------------------

CREATE TABLE ALUNO_TELEFONE (
    matricula  NUMBER(10)         NOT NULL,
    telefone   VARCHAR2(20 CHAR)  NOT NULL,
    CONSTRAINT pk_aluno_telefone PRIMARY KEY (matricula, telefone),
    CONSTRAINT fk_aluno_telefone FOREIGN KEY (matricula) REFERENCES ALUNO (matricula)
)
TABLESPACE ts_academico;

-- 4. Entidade fraca (PK composta) --------------------------------------------

CREATE TABLE TURMA (
    codigo_disciplina  VARCHAR2(10 CHAR)  NOT NULL,
    numero_turma       NUMBER(3)          NOT NULL,
    semestre           VARCHAR2(10 CHAR),
    registro_professor NUMBER(10),
    CONSTRAINT pk_turma PRIMARY KEY (codigo_disciplina, numero_turma),
    CONSTRAINT fk_turma_disciplina FOREIGN KEY (codigo_disciplina)
        REFERENCES DISCIPLINA (codigo) ON DELETE CASCADE,
    CONSTRAINT fk_turma_professor FOREIGN KEY (registro_professor)
        REFERENCES PROFESSOR (registro)
)
TABLESPACE ts_academico;

-- 5. Relacionamento N:N resolvido (tabela associativa) -----------------------

CREATE TABLE MATRICULA (
    matricula_aluno    NUMBER(10)        NOT NULL,
    codigo_disciplina  VARCHAR2(10 CHAR) NOT NULL,
    numero_turma       NUMBER(3)         NOT NULL,
    data_matricula     DATE DEFAULT SYSDATE,
    nota               NUMBER(4,2),
    situacao           VARCHAR2(15 CHAR)
        CHECK (situacao IN ('ATIVA','TRANCADA','CONCLUIDA')),
    CONSTRAINT pk_matricula PRIMARY KEY (matricula_aluno, codigo_disciplina, numero_turma),
    CONSTRAINT fk_matricula_aluno FOREIGN KEY (matricula_aluno)
        REFERENCES ALUNO (matricula),
    CONSTRAINT fk_matricula_turma FOREIGN KEY (codigo_disciplina, numero_turma)
        REFERENCES TURMA (codigo_disciplina, numero_turma)
)
TABLESPACE ts_academico
PCTFREE 15;

-- ============================================================================
-- Observacoes de tipos fisicos (Oracle):
--  - VARCHAR2(n CHAR) garante 'n' caracteres mesmo com acentuacao multibyte
--    (UTF-8), evitando truncamento de nomes com acentos.
--  - NUMBER(p) sem escala representa inteiros; NUMBER(p,s) representa decimais
--    exatos (usado em MATRICULA.nota, p.ex.).
--  - DATE do Oracle sempre grava hora (ate o segundo); usar TRUNC() em
--    comparacoes quando se quer ignorar a hora.
--  - PCTFREE mais alto em MATRICULA reserva espaco para futuras atualizacoes
--    de nota/situacao sem migracao de linha (row migration).
-- ============================================================================
