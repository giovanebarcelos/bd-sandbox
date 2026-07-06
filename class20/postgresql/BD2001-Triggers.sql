-- BD2001-Triggers.sql
-- PostgreSQL: Triggers de Auditoria e Validacao (PL/pgSQL)
-- UA7 - Aula 20 - Programacao no Banco de Dados

-- ============================================================
-- TABELA DE AUDITORIA
-- ============================================================
CREATE TABLE auditoria_professor (
    id_auditoria  SERIAL PRIMARY KEY,
    operacao      VARCHAR(10),
    professor_id  INT,
    nome_antigo   VARCHAR(200),
    nome_novo     VARCHAR(200),
    usuario_banco VARCHAR(100),
    data_hora     TIMESTAMP DEFAULT NOW()
);

-- ============================================================
-- TRIGGER 1: Auditoria de Professor
-- ============================================================
CREATE OR REPLACE FUNCTION fn_auditoria_professor()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        INSERT INTO auditoria_professor (operacao, professor_id, nome_novo, usuario_banco)
        VALUES ('INSERT', NEW.professor_id, NEW.nome, current_user);
    ELSIF TG_OP = 'UPDATE' THEN
        INSERT INTO auditoria_professor (operacao, professor_id, nome_antigo, nome_novo, usuario_banco)
        VALUES ('UPDATE', NEW.professor_id, OLD.nome, NEW.nome, current_user);
    ELSIF TG_OP = 'DELETE' THEN
        INSERT INTO auditoria_professor (operacao, professor_id, nome_antigo, usuario_banco)
        VALUES ('DELETE', OLD.professor_id, OLD.nome, current_user);
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_auditoria_professor
    AFTER INSERT OR UPDATE OR DELETE ON professor
    FOR EACH ROW EXECUTE FUNCTION fn_auditoria_professor();

-- ============================================================
-- TRIGGER 2: Preenchimento automatico de data
-- ============================================================
ALTER TABLE produto ADD COLUMN IF NOT EXISTS data_atualizacao TIMESTAMP;

CREATE OR REPLACE FUNCTION fn_set_data_atualizacao()
RETURNS TRIGGER AS $$
BEGIN
    NEW.data_atualizacao := NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_set_data_atualizacao
    BEFORE INSERT OR UPDATE ON produto
    FOR EACH ROW EXECUTE FUNCTION fn_set_data_atualizacao();

-- ============================================================
-- TRIGGER 3: Validacao de regra de negocio
-- ============================================================
CREATE OR REPLACE FUNCTION fn_valida_turma_datas()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.data_final < NEW.data_inicial THEN
        RAISE EXCEPTION 'Data final nao pode ser anterior a data inicial';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_valida_turma_datas
    BEFORE INSERT OR UPDATE ON turma
    FOR EACH ROW EXECUTE FUNCTION fn_valida_turma_datas();

-- ============================================================
-- TRIGGER 4: Controle de recursao (flag)
-- ============================================================
CREATE OR REPLACE FUNCTION fn_evita_recursao()
RETURNS TRIGGER AS $$
BEGIN
    IF pg_trigger_depth() > 1 THEN
        RETURN NEW;  -- Ignora chamadas recursivas
    END IF;
    -- Logica da trigger aqui
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- TESTES
-- ============================================================
INSERT INTO professor (nome, cpf) VALUES ('Teste Trigger', '111.111.111-11');
UPDATE professor SET nome = 'Teste Trigger Atualizado' WHERE cpf = '111.111.111-11';
DELETE FROM professor WHERE cpf = '111.111.111-11';
SELECT * FROM auditoria_professor ORDER BY id_auditoria;

-- Teste validacao (deve falhar)
INSERT INTO turma (horario, duracao, data_inicial, data_final, professor_id, curso_id)
VALUES ('19:00', 3, '2026-12-01', '2026-01-01', 1, 1);
-- ERROR: Data final nao pode ser anterior a data inicial
