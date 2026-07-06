-- BD3201-ProjetoFinal.sql
-- PostgreSQL: Projeto Integrador Final - Sistema de Biblioteca
-- UA12 - Aula 32

-- ============================================================
-- DDL
-- ============================================================
CREATE TABLE editora (
    editora_id SERIAL PRIMARY KEY,
    nome       VARCHAR(200) NOT NULL
);

CREATE TABLE livro (
    livro_id   SERIAL PRIMARY KEY,
    isbn       VARCHAR(17) UNIQUE NOT NULL,
    titulo     VARCHAR(300) NOT NULL,
    editora_id INT NOT NULL,
    ano        INT,
    edicao     INT,
    CONSTRAINT fk_livro_editora FOREIGN KEY (editora_id)
        REFERENCES editora (editora_id)
);

CREATE TABLE autor (
    autor_id      SERIAL PRIMARY KEY,
    nome          VARCHAR(200) NOT NULL,
    nacionalidade VARCHAR(100)
);

CREATE TABLE livro_autor (
    livro_id INT NOT NULL,
    autor_id INT NOT NULL,
    PRIMARY KEY (livro_id, autor_id),
    CONSTRAINT fk_la_livro FOREIGN KEY (livro_id) REFERENCES livro (livro_id),
    CONSTRAINT fk_la_autor FOREIGN KEY (autor_id) REFERENCES autor (autor_id)
);

CREATE TABLE usuario (
    usuario_id SERIAL PRIMARY KEY,
    matricula  VARCHAR(20) UNIQUE NOT NULL,
    nome       VARCHAR(200) NOT NULL,
    email      VARCHAR(200) UNIQUE NOT NULL,
    tipo       VARCHAR(20) DEFAULT 'ALUNO' CHECK (tipo IN ('ALUNO', 'PROFESSOR'))
);

CREATE TABLE emprestimo (
    emprestimo_id  SERIAL PRIMARY KEY,
    usuario_id     INT NOT NULL,
    livro_id       INT NOT NULL,
    data_retirada  DATE DEFAULT CURRENT_DATE NOT NULL,
    data_prevista  DATE NOT NULL,
    data_devolucao DATE,
    multa          NUMERIC(10,2) DEFAULT 0,
    CONSTRAINT fk_emp_usuario FOREIGN KEY (usuario_id)
        REFERENCES usuario (usuario_id),
    CONSTRAINT fk_emp_livro FOREIGN KEY (livro_id)
        REFERENCES livro (livro_id)
);

-- Indices
CREATE INDEX idx_emp_usuario ON emprestimo(usuario_id);
CREATE INDEX idx_emp_livro ON emprestimo(livro_id);
CREATE INDEX idx_livro_titulo ON livro(titulo);

-- ============================================================
-- AUDITORIA
-- ============================================================
CREATE TABLE auditoria_emprestimo (
    id_auditoria  SERIAL PRIMARY KEY,
    operacao      VARCHAR(10),
    emprestimo_id INT,
    data_hora     TIMESTAMP DEFAULT NOW()
);

CREATE OR REPLACE FUNCTION fn_auditoria_emprestimo()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        INSERT INTO auditoria_emprestimo (operacao, emprestimo_id)
        VALUES ('INSERT', NEW.emprestimo_id);
    ELSIF TG_OP = 'UPDATE' THEN
        INSERT INTO auditoria_emprestimo (operacao, emprestimo_id)
        VALUES ('UPDATE', NEW.emprestimo_id);
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_auditoria_emprestimo
    AFTER INSERT OR UPDATE ON emprestimo
    FOR EACH ROW EXECUTE FUNCTION fn_auditoria_emprestimo();

-- ============================================================
-- PROCEDURES
-- ============================================================
CREATE OR REPLACE PROCEDURE realizar_emprestimo (
    p_usuario_id INT,
    p_livro_id   INT
) LANGUAGE plpgsql AS $$
BEGIN
    INSERT INTO emprestimo (usuario_id, livro_id, data_prevista)
    VALUES (p_usuario_id, p_livro_id, CURRENT_DATE + 14);
END;
$$;

CREATE OR REPLACE PROCEDURE devolver_livro (
    p_emprestimo_id INT
) LANGUAGE plpgsql AS $$
DECLARE
    v_data_prevista DATE;
    v_dias_atraso   INT;
BEGIN
    UPDATE emprestimo SET data_devolucao = CURRENT_DATE
     WHERE emprestimo_id = p_emprestimo_id
       AND data_devolucao IS NULL;

    SELECT data_prevista INTO v_data_prevista
      FROM emprestimo WHERE emprestimo_id = p_emprestimo_id;

    v_dias_atraso := CURRENT_DATE - v_data_prevista;
    IF v_dias_atraso > 0 THEN
        UPDATE emprestimo SET multa = v_dias_atraso * 2.00
         WHERE emprestimo_id = p_emprestimo_id;
    END IF;
END;
$$;
