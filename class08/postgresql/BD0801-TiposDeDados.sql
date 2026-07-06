-- ============================================================================
-- BD0801-TiposDeDados.sql
-- Aula 08: Modelagem Física - Tipos de Dados e Armazenamento (PostgreSQL)
-- Disciplina: Banco de Dados | UA3 - Modelagem Logica/Fisica e Tipos de Chave
--
-- Aplica tipos fisicos, tablespace e parametros de armazenamento ao esquema
-- logico produzido na Aula 07 (estudo de caso: sistema academico simplificado).
-- Equivalente funcional de repository/class08/oracle/BD0801-TiposDeDados.sql
-- ============================================================================

-- 1. Tablespace dedicada ao domínio acadêmico -------------------------------
-- (o diretorio deve existir e ter permissao de escrita para o usuario postgres)
CREATE TABLESPACE ts_academico
    LOCATION '/var/lib/postgresql/tablespaces/ts_academico';

-- 2. Entidades fortes ---------------------------------------------------------

CREATE TABLE aluno (
    matricula        INTEGER      PRIMARY KEY,
    nome             VARCHAR(120) NOT NULL,
    data_nascimento  DATE,
    email            VARCHAR(120),
    endereco_rua     VARCHAR(120),
    endereco_numero  VARCHAR(10),
    endereco_cidade  VARCHAR(80),
    endereco_uf      CHAR(2)
)
TABLESPACE ts_academico
WITH (fillfactor = 90);

COMMENT ON TABLE aluno IS 'Entidade forte: aluno do sistema academico';
COMMENT ON COLUMN aluno.matricula IS 'Chave primaria - matricula institucional';
COMMENT ON COLUMN aluno.endereco_uf IS 'Atributo composto (endereco) achatado - UF com 2 caracteres fixos';

CREATE TABLE sala (
    id          SMALLINT PRIMARY KEY,
    bloco       VARCHAR(10),
    capacidade  SMALLINT
)
TABLESPACE ts_academico;

CREATE TABLE professor (
    registro   INTEGER      PRIMARY KEY,
    nome       VARCHAR(120) NOT NULL,
    titulacao  VARCHAR(40),
    sala_id    SMALLINT UNIQUE REFERENCES sala (id)
)
TABLESPACE ts_academico;

CREATE TABLE disciplina (
    codigo         VARCHAR(10) PRIMARY KEY,
    nome           VARCHAR(120) NOT NULL,
    carga_horaria  SMALLINT
)
TABLESPACE ts_academico;

-- 3. Atributo multivalorado (tabela filha) -----------------------------------

CREATE TABLE aluno_telefone (
    matricula  INTEGER      NOT NULL REFERENCES aluno (matricula),
    telefone   VARCHAR(20)  NOT NULL,
    PRIMARY KEY (matricula, telefone)
)
TABLESPACE ts_academico;

-- 4. Entidade fraca (PK composta) --------------------------------------------

CREATE TABLE turma (
    codigo_disciplina   VARCHAR(10) NOT NULL REFERENCES disciplina (codigo) ON DELETE CASCADE,
    numero_turma        SMALLINT    NOT NULL,
    semestre            VARCHAR(10),
    registro_professor  INTEGER REFERENCES professor (registro),
    PRIMARY KEY (codigo_disciplina, numero_turma)
)
TABLESPACE ts_academico;

-- 5. Relacionamento N:N resolvido (tabela associativa) -----------------------

CREATE TABLE matricula (
    matricula_aluno    INTEGER     NOT NULL REFERENCES aluno (matricula),
    codigo_disciplina  VARCHAR(10) NOT NULL,
    numero_turma       SMALLINT    NOT NULL,
    data_matricula     DATE DEFAULT CURRENT_DATE,
    nota               NUMERIC(4,2),
    situacao           VARCHAR(15)
        CHECK (situacao IN ('ATIVA','TRANCADA','CONCLUIDA')),
    PRIMARY KEY (matricula_aluno, codigo_disciplina, numero_turma),
    FOREIGN KEY (codigo_disciplina, numero_turma)
        REFERENCES turma (codigo_disciplina, numero_turma)
)
TABLESPACE ts_academico
WITH (fillfactor = 85);

-- ============================================================================
-- Observacoes de tipos fisicos (PostgreSQL):
--  - VARCHAR(n) conta sempre em caracteres (nao em bytes), diferente do
--    VARCHAR2 BYTE do Oracle - texto acentuado nao corre risco de truncamento.
--  - SMALLINT/INTEGER/BIGINT sao tipos dedicados de 2/4/8 bytes, diferente do
--    NUMBER unico do Oracle.
--  - DATE do PostgreSQL guarda apenas data (sem hora) - usar TIMESTAMP quando
--    a hora for relevante.
--  - FILLFACTOR menor que 100 reserva espaco na pagina para HOT updates
--    (updates que nao mudam colunas indexadas evitam reescrever indices).
--  - CREATE DOMAIN poderia substituir o CHECK repetido de 'situacao' caso o
--    mesmo dominio seja usado em outras tabelas do sistema.
-- ============================================================================
