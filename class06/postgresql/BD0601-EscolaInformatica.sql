-- BD0601-EscolaInformatica.sql
-- PostgreSQL DDL: Estudo de Caso Escola de Informatica
-- UA2 - Aula 06 - Modelagem Conceitual (DER)

-- Curso
CREATE TABLE curso (
    curso_id   SERIAL PRIMARY KEY,
    nome       VARCHAR(100) NOT NULL
);

-- Professor
CREATE TABLE professor (
    professor_id    SERIAL PRIMARY KEY,
    cpf             VARCHAR(14)  NOT NULL UNIQUE,
    nome            VARCHAR(200) NOT NULL,
    data_nascimento DATE,
    titulacao       VARCHAR(100)
);

-- Telefone (atributo multivalorado)
CREATE TABLE telefone (
    telefone_id  SERIAL PRIMARY KEY,
    numero       VARCHAR(20) NOT NULL,
    professor_id INT NOT NULL,
    CONSTRAINT fk_telefone_professor FOREIGN KEY (professor_id)
        REFERENCES professor (professor_id)
);

-- Aluno
CREATE TABLE aluno (
    aluno_id        SERIAL PRIMARY KEY,
    data_matricula  DATE         NOT NULL,
    nome            VARCHAR(200) NOT NULL,
    endereco        VARCHAR(300),
    telefone        VARCHAR(20),
    data_nascimento DATE,
    altura          NUMERIC(3,2),
    peso            NUMERIC(5,2)
);

-- Turma
CREATE TABLE turma (
    turma_id        SERIAL PRIMARY KEY,
    qtd_alunos      INT          DEFAULT 0,
    horario         VARCHAR(5)   NOT NULL,
    duracao         INT          NOT NULL,
    data_inicial    DATE         NOT NULL,
    data_final      DATE         NOT NULL,
    professor_id    INT          NOT NULL,
    curso_id        INT          NOT NULL,
    alunomonitor_id INT,
    CONSTRAINT fk_turma_professor FOREIGN KEY (professor_id)
        REFERENCES professor (professor_id),
    CONSTRAINT fk_turma_curso FOREIGN KEY (curso_id)
        REFERENCES curso (curso_id),
    CONSTRAINT fk_turma_monitor FOREIGN KEY (alunomonitor_id)
        REFERENCES aluno (aluno_id)
);

-- Matricula (entidade associativa entre Aluno e Turma)
CREATE TABLE matricula (
    matricula_id SERIAL PRIMARY KEY,
    turma_id     INT NOT NULL,
    aluno_id     INT NOT NULL,
    CONSTRAINT fk_matricula_turma FOREIGN KEY (turma_id)
        REFERENCES turma (turma_id),
    CONSTRAINT fk_matricula_aluno FOREIGN KEY (aluno_id)
        REFERENCES aluno (aluno_id),
    CONSTRAINT uq_matricula_aluno_turma UNIQUE (turma_id, aluno_id)
);

-- Ausencia (entidade fraca dependente de Matricula)
CREATE TABLE ausencia (
    ausencia_id  INT NOT NULL,
    matricula_id INT NOT NULL,
    data         DATE NOT NULL,
    CONSTRAINT pk_ausencia PRIMARY KEY (matricula_id, ausencia_id),
    CONSTRAINT fk_ausencia_matricula FOREIGN KEY (matricula_id)
        REFERENCES matricula (matricula_id) ON DELETE CASCADE
);
