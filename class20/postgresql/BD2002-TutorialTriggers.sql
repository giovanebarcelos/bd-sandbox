-- ============================================================================
-- BD2002-TutorialTriggers.sql
-- Aula 20 - Tutorial passo a passo: Triggers de auditoria e validacao
-- SGBD: PostgreSQL 17 (container "postgres" do ambiente Docker da disciplina)
--
-- Roteiro completo do tutorial Aula_20_..._Tutorial_PostgreSQL.md. Rode
-- conectado ao banco aula20 (CREATE DATABASE aula20; \c aula20). Os passos
-- 4, 5 e 9 tem erros PROPOSITAIS (o psql segue em frente).
-- ============================================================================


-- ----------------------------------------------------------------------------
-- PASSO 1. SCHEMA: Escola de Informatica (Aula 06) + produto e pedido
-- ----------------------------------------------------------------------------
SET client_min_messages = warning;
DROP VIEW  IF EXISTS vw_aluno_turma;
DROP TABLE IF EXISTS auditoria_aluno, auditoria_log, historico_preco, log_operacao,
                     matricula, turma, aluno, professor, curso, produto, pedido CASCADE;
RESET client_min_messages;

CREATE TABLE curso (
    curso_id   SERIAL PRIMARY KEY,
    nome       VARCHAR(100) NOT NULL
);

CREATE TABLE professor (
    professor_id    SERIAL PRIMARY KEY,
    cpf             VARCHAR(14)  NOT NULL UNIQUE,
    nome            VARCHAR(200) NOT NULL,
    titulacao       VARCHAR(100)
);

CREATE TABLE aluno (
    aluno_id        SERIAL PRIMARY KEY,
    data_matricula  DATE         NOT NULL DEFAULT CURRENT_DATE,
    nome            VARCHAR(200) NOT NULL
);

CREATE TABLE turma (
    turma_id        SERIAL PRIMARY KEY,
    qtd_alunos      INT          DEFAULT 0,
    horario         VARCHAR(5)   NOT NULL,
    duracao         INT          NOT NULL,
    data_inicial    DATE         NOT NULL,
    data_final      DATE         NOT NULL,
    professor_id    INT          NOT NULL REFERENCES professor (professor_id),
    curso_id        INT          NOT NULL REFERENCES curso (curso_id)
);

CREATE TABLE matricula (
    matricula_id SERIAL PRIMARY KEY,
    turma_id     INT NOT NULL REFERENCES turma (turma_id),
    aluno_id     INT NOT NULL REFERENCES aluno (aluno_id),
    CONSTRAINT uq_matricula_aluno_turma UNIQUE (turma_id, aluno_id)
);

CREATE TABLE produto (
    produto_id        SERIAL PRIMARY KEY,
    nome              VARCHAR(100)  NOT NULL,
    preco             NUMERIC(10,2) NOT NULL,
    data_atualizacao  TIMESTAMP
);

CREATE TABLE pedido (
    pedido_id  SERIAL PRIMARY KEY,
    cliente    VARCHAR(100) NOT NULL,
    status     VARCHAR(10)  NOT NULL DEFAULT 'ABERTO'
);

INSERT INTO curso (nome) VALUES ('Banco de Dados'), ('Programacao Python');
INSERT INTO professor (cpf, nome, titulacao) VALUES
    ('111.111.111-11', 'Marta Ribeiro', 'Mestre'),
    ('222.222.222-22', 'Paulo Nunes',   'Doutor');
INSERT INTO aluno (nome) VALUES ('Joao Pedro'), ('Luiza Martins'), ('Rafael Costa');
INSERT INTO turma (horario, duracao, data_inicial, data_final, professor_id, curso_id) VALUES
    ('19:00', 3, '2026-03-02', '2026-07-10', 1, 1),
    ('08:00', 4, '2026-03-03', '2026-07-11', 2, 2);
INSERT INTO produto (nome, preco) VALUES ('Apostila SQL', 45.00), ('Pen drive 64GB', 59.90);
INSERT INTO pedido (cliente, status) VALUES ('Ana', 'ABERTO'), ('Bruno', 'ENVIADO');

SELECT 'curso' AS tabela, COUNT(*) FROM curso UNION ALL
SELECT 'professor', COUNT(*) FROM professor UNION ALL
SELECT 'aluno', COUNT(*) FROM aluno UNION ALL
SELECT 'turma', COUNT(*) FROM turma UNION ALL
SELECT 'produto', COUNT(*) FROM produto UNION ALL
SELECT 'pedido', COUNT(*) FROM pedido;


-- ----------------------------------------------------------------------------
-- PASSO 2. AUDITORIA (AFTER ... FOR EACH ROW) com TG_OP, NEW e OLD
-- ----------------------------------------------------------------------------
CREATE TABLE auditoria_aluno (
    id_auditoria  SERIAL PRIMARY KEY,
    operacao      VARCHAR(10),
    aluno_id      INT,
    nome_antigo   VARCHAR(200),
    nome_novo     VARCHAR(200),
    usuario_banco VARCHAR(100),
    data_hora     TIMESTAMP DEFAULT NOW()
);

CREATE OR REPLACE FUNCTION fn_auditoria_aluno()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        INSERT INTO auditoria_aluno (operacao, aluno_id, nome_novo, usuario_banco)
        VALUES ('INSERT', NEW.aluno_id, NEW.nome, current_user);
    ELSIF TG_OP = 'UPDATE' THEN
        INSERT INTO auditoria_aluno (operacao, aluno_id, nome_antigo, nome_novo, usuario_banco)
        VALUES ('UPDATE', NEW.aluno_id, OLD.nome, NEW.nome, current_user);
    ELSIF TG_OP = 'DELETE' THEN
        INSERT INTO auditoria_aluno (operacao, aluno_id, nome_antigo, usuario_banco)
        VALUES ('DELETE', OLD.aluno_id, OLD.nome, current_user);
    END IF;
    RETURN NULL;  -- o retorno de uma trigger AFTER e ignorado
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_auditoria_aluno
    AFTER INSERT OR UPDATE OR DELETE ON aluno
    FOR EACH ROW EXECUTE FUNCTION fn_auditoria_aluno();

INSERT INTO aluno (nome) VALUES ('Teste Trigger');
UPDATE aluno SET nome = 'Teste Trigger Atualizado' WHERE nome = 'Teste Trigger';
DELETE FROM aluno WHERE nome = 'Teste Trigger Atualizado';

SELECT id_auditoria, operacao, aluno_id, nome_antigo, nome_novo, usuario_banco
  FROM auditoria_aluno ORDER BY id_auditoria;


-- ----------------------------------------------------------------------------
-- PASSO 3. PREENCHIMENTO AUTOMATICO (BEFORE ... FOR EACH ROW, RETURN NEW)
-- ----------------------------------------------------------------------------
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

INSERT INTO produto (nome, preco) VALUES ('Mouse sem fio', 89.00);
-- tentar "forcar" outra data nao adianta: a trigger sobrescreve NEW
UPDATE produto SET preco = 49.00, data_atualizacao = '2000-01-01' WHERE nome = 'Apostila SQL';

SELECT produto_id, nome, preco,
       data_atualizacao IS NOT NULL AS preenchida,
       data_atualizacao::date = CURRENT_DATE AS hoje
  FROM produto ORDER BY produto_id;


-- ----------------------------------------------------------------------------
-- PASSO 4. A ARMADILHA DO RETURN NULL EM TRIGGER BEFORE
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_set_data_atualizacao()
RETURNS TRIGGER AS $$
BEGIN
    NEW.data_atualizacao := NOW();
    RETURN NULL;   -- ERRO PROPOSITAL: em BEFORE, NULL cancela a linha em silencio
END;
$$ LANGUAGE plpgsql;

INSERT INTO produto (nome, preco) VALUES ('Teclado', 120.00);
SELECT COUNT(*) AS teclados FROM produto WHERE nome = 'Teclado';

-- corrige de volta
CREATE OR REPLACE FUNCTION fn_set_data_atualizacao()
RETURNS TRIGGER AS $$
BEGIN
    NEW.data_atualizacao := NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;


-- ----------------------------------------------------------------------------
-- PASSO 5. VALIDACAO (BEFORE + RAISE EXCEPTION)  -- erros propositais
-- ----------------------------------------------------------------------------
-- 5a. Datas da turma
CREATE OR REPLACE FUNCTION fn_valida_turma_datas()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.data_final < NEW.data_inicial THEN
        RAISE EXCEPTION 'Data final (%) nao pode ser anterior a data inicial (%)',
              NEW.data_final, NEW.data_inicial;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_valida_turma_datas
    BEFORE INSERT OR UPDATE ON turma
    FOR EACH ROW EXECUTE FUNCTION fn_valida_turma_datas();

INSERT INTO turma (horario, duracao, data_inicial, data_final, professor_id, curso_id)
VALUES ('19:00', 3, '2026-12-01', '2026-01-01', 1, 1);

-- 5b. Pedido ja enviado nao pode mudar
CREATE OR REPLACE FUNCTION fn_bloqueia_update_pedido()
RETURNS TRIGGER AS $$
BEGIN
    IF OLD.status = 'ENVIADO' THEN
        RAISE EXCEPTION 'Nao e permitido alterar pedido com status ENVIADO (pedido %)', OLD.pedido_id;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_bloqueia_update_pedido
    BEFORE UPDATE ON pedido
    FOR EACH ROW EXECUTE FUNCTION fn_bloqueia_update_pedido();

UPDATE pedido SET status = 'ENVIADO' WHERE cliente = 'Ana';    -- ABERTO -> ENVIADO: permitido
UPDATE pedido SET cliente = 'Bruno S.' WHERE cliente = 'Bruno'; -- ja ENVIADO: bloqueado

SELECT pedido_id, cliente, status FROM pedido ORDER BY pedido_id;


-- ----------------------------------------------------------------------------
-- PASSO 6. UPDATE OF coluna + WHEN: so dispara quando o preco muda
-- ----------------------------------------------------------------------------
CREATE TABLE historico_preco (
    id            SERIAL PRIMARY KEY,
    produto_id    INT,
    preco_antigo  NUMERIC(10,2),
    preco_novo    NUMERIC(10,2),
    data_hora     TIMESTAMP DEFAULT NOW()
);

CREATE OR REPLACE FUNCTION fn_historico_preco()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO historico_preco (produto_id, preco_antigo, preco_novo)
    VALUES (NEW.produto_id, OLD.preco, NEW.preco);
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_historico_preco
    AFTER UPDATE OF preco ON produto
    FOR EACH ROW
    WHEN (OLD.preco IS DISTINCT FROM NEW.preco)
    EXECUTE FUNCTION fn_historico_preco();

UPDATE produto SET nome = 'Pen drive 64 GB' WHERE produto_id = 2;  -- nao mexe no preco
UPDATE produto SET preco = 59.90 WHERE produto_id = 2;            -- mesmo preco
UPDATE produto SET preco = 54.90 WHERE produto_id = 2;            -- preco mudou

SELECT produto_id, preco_antigo, preco_novo FROM historico_preco ORDER BY id;


-- ----------------------------------------------------------------------------
-- PASSO 7. FOR EACH ROW x FOR EACH STATEMENT
-- ----------------------------------------------------------------------------
CREATE TABLE log_operacao (
    id         SERIAL PRIMARY KEY,
    nivel      VARCHAR(10),
    operacao   VARCHAR(10),
    tabela     VARCHAR(50),
    data_hora  TIMESTAMP DEFAULT clock_timestamp()
);

CREATE OR REPLACE FUNCTION fn_log_operacao()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO log_operacao (nivel, operacao, tabela)
    VALUES (TG_LEVEL, TG_OP, TG_TABLE_NAME);
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_log_linha
    AFTER INSERT ON produto
    FOR EACH ROW EXECUTE FUNCTION fn_log_operacao();

CREATE TRIGGER trg_log_comando
    AFTER INSERT ON produto
    FOR EACH STATEMENT EXECUTE FUNCTION fn_log_operacao();

-- um unico INSERT que grava 1000 linhas
INSERT INTO produto (nome, preco)
SELECT 'Produto em lote ' || g, 10 + g FROM generate_series(1, 1000) AS g;

SELECT nivel, COUNT(*) AS execucoes FROM log_operacao GROUP BY nivel ORDER BY nivel;

DROP TRIGGER trg_log_linha ON produto;
DROP TRIGGER trg_log_comando ON produto;
DELETE FROM produto WHERE nome LIKE 'Produto em lote %';


-- ----------------------------------------------------------------------------
-- PASSO 8. INSTEAD OF: tornando uma view com JOIN "atualizavel"
-- ----------------------------------------------------------------------------
CREATE VIEW vw_aluno_turma AS
SELECT a.aluno_id, a.nome, m.turma_id, m.matricula_id
  FROM aluno a
  JOIN matricula m ON m.aluno_id = a.aluno_id;

-- sem trigger, o INSERT na view falha (erro proposital)
INSERT INTO vw_aluno_turma (nome, turma_id) VALUES ('Beatriz Lopes', 1);

CREATE OR REPLACE FUNCTION fn_insert_vw_aluno_turma()
RETURNS TRIGGER AS $$
DECLARE
    v_aluno_id INT;
BEGIN
    INSERT INTO aluno (nome) VALUES (NEW.nome) RETURNING aluno_id INTO v_aluno_id;
    INSERT INTO matricula (aluno_id, turma_id) VALUES (v_aluno_id, NEW.turma_id);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_insert_vw_aluno_turma
    INSTEAD OF INSERT ON vw_aluno_turma
    FOR EACH ROW EXECUTE FUNCTION fn_insert_vw_aluno_turma();

INSERT INTO vw_aluno_turma (nome, turma_id) VALUES ('Beatriz Lopes', 1);

SELECT * FROM vw_aluno_turma;
SELECT operacao, nome_novo FROM auditoria_aluno WHERE nome_novo = 'Beatriz Lopes';


-- ----------------------------------------------------------------------------
-- PASSO 9. RECURSAO INFINITA E pg_trigger_depth()
-- ----------------------------------------------------------------------------
-- 9a. Trigger AFTER UPDATE em turma que faz UPDATE na propria turma (erro proposital)
CREATE OR REPLACE FUNCTION fn_turma_recalcula()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE turma
       SET qtd_alunos = (SELECT COUNT(*) FROM matricula WHERE turma_id = NEW.turma_id)
     WHERE turma_id = NEW.turma_id;   -- dispara a propria trigger de novo...
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_turma_recalcula
    AFTER UPDATE ON turma
    FOR EACH ROW EXECUTE FUNCTION fn_turma_recalcula();

\set VERBOSITY terse
UPDATE turma SET horario = '19:30' WHERE turma_id = 1;
\set VERBOSITY default

-- 9b. Correcao: ignorar as chamadas aninhadas
CREATE OR REPLACE FUNCTION fn_turma_recalcula()
RETURNS TRIGGER AS $$
BEGIN
    IF pg_trigger_depth() > 1 THEN
        RETURN NULL;  -- chamada disparada pela propria trigger: nao faz nada
    END IF;
    UPDATE turma
       SET qtd_alunos = (SELECT COUNT(*) FROM matricula WHERE turma_id = NEW.turma_id)
     WHERE turma_id = NEW.turma_id;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

UPDATE turma SET horario = '19:30' WHERE turma_id = 1;
SELECT turma_id, horario, qtd_alunos FROM turma ORDER BY turma_id;

DROP TRIGGER trg_turma_recalcula ON turma;


-- ----------------------------------------------------------------------------
-- PASSO 10. CONTADOR AUTOMATICO: matricula atualiza turma.qtd_alunos
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_atualiza_qtd_alunos()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP IN ('INSERT', 'UPDATE') THEN
        UPDATE turma SET qtd_alunos = qtd_alunos + 1 WHERE turma_id = NEW.turma_id;
    END IF;
    IF TG_OP IN ('DELETE', 'UPDATE') THEN
        UPDATE turma SET qtd_alunos = qtd_alunos - 1 WHERE turma_id = OLD.turma_id;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_atualiza_qtd_alunos
    AFTER INSERT OR DELETE OR UPDATE OF turma_id ON matricula
    FOR EACH ROW EXECUTE FUNCTION fn_atualiza_qtd_alunos();

INSERT INTO matricula (aluno_id, turma_id) VALUES (1, 1), (2, 1), (3, 2);
UPDATE matricula SET turma_id = 2 WHERE aluno_id = 2;
DELETE FROM matricula WHERE aluno_id = 3;

SELECT t.turma_id, t.qtd_alunos,
       (SELECT COUNT(*) FROM matricula m WHERE m.turma_id = t.turma_id) AS contagem_real
  FROM turma t ORDER BY t.turma_id;


-- ----------------------------------------------------------------------------
-- PASSO 11. MULTIPLAS TRIGGERS NO MESMO EVENTO: ordem alfabetica
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_avisa()
RETURNS TRIGGER AS $$
BEGIN
    RAISE NOTICE 'disparou: %', TG_NAME;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- criadas fora de ordem de proposito
CREATE TRIGGER trg_c_cache       AFTER INSERT ON curso FOR EACH ROW EXECUTE FUNCTION fn_avisa();
CREATE TRIGGER trg_a_auditoria   AFTER INSERT ON curso FOR EACH ROW EXECUTE FUNCTION fn_avisa();
CREATE TRIGGER trg_b_notificacao AFTER INSERT ON curso FOR EACH ROW EXECUTE FUNCTION fn_avisa();

INSERT INTO curso (nome) VALUES ('Redes de Computadores');

DROP TRIGGER trg_a_auditoria ON curso;
DROP TRIGGER trg_b_notificacao ON curso;
DROP TRIGGER trg_c_cache ON curso;


-- ----------------------------------------------------------------------------
-- PASSO 12. AUDITORIA GENERICA EM JSON (uma funcao para varias tabelas)
-- ----------------------------------------------------------------------------
CREATE TABLE auditoria_log (
    id             SERIAL PRIMARY KEY,
    tabela         VARCHAR(50),
    operacao       VARCHAR(10),
    dados_antigos  JSONB,
    dados_novos    JSONB,
    usuario_banco  VARCHAR(100) DEFAULT current_user,
    data_hora      TIMESTAMP DEFAULT NOW()
);

CREATE OR REPLACE FUNCTION fn_auditoria_json()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        INSERT INTO auditoria_log (tabela, operacao, dados_novos)
        VALUES (TG_TABLE_NAME, 'INSERT', to_jsonb(NEW));
    ELSIF TG_OP = 'UPDATE' THEN
        INSERT INTO auditoria_log (tabela, operacao, dados_antigos, dados_novos)
        VALUES (TG_TABLE_NAME, 'UPDATE', to_jsonb(OLD), to_jsonb(NEW));
    ELSIF TG_OP = 'DELETE' THEN
        INSERT INTO auditoria_log (tabela, operacao, dados_antigos)
        VALUES (TG_TABLE_NAME, 'DELETE', to_jsonb(OLD));
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- a MESMA funcao em duas tabelas diferentes
CREATE TRIGGER trg_auditoria_json_professor
    AFTER INSERT OR UPDATE OR DELETE ON professor
    FOR EACH ROW EXECUTE FUNCTION fn_auditoria_json();

CREATE TRIGGER trg_auditoria_json_curso
    AFTER INSERT OR UPDATE OR DELETE ON curso
    FOR EACH ROW EXECUTE FUNCTION fn_auditoria_json();

UPDATE professor SET titulacao = 'Doutora' WHERE nome = 'Marta Ribeiro';
DELETE FROM curso WHERE nome = 'Redes de Computadores';

SELECT tabela, operacao,
       dados_antigos ->> 'titulacao' AS titulacao_antes,
       dados_novos   ->> 'titulacao' AS titulacao_depois,
       dados_antigos ->> 'nome'      AS nome_antigo
  FROM auditoria_log ORDER BY id;

-- descobrindo QUAIS colunas mudaram num UPDATE
SELECT n.key AS coluna, o.value AS antes, n.value AS depois
  FROM auditoria_log l,
       jsonb_each(l.dados_novos)   n,
       jsonb_each(l.dados_antigos) o
 WHERE l.operacao = 'UPDATE' AND n.key = o.key AND n.value IS DISTINCT FROM o.value;


-- ----------------------------------------------------------------------------
-- PASSO 13. DESABILITAR, HABILITAR E LISTAR TRIGGERS
-- ----------------------------------------------------------------------------
ALTER TABLE aluno DISABLE TRIGGER trg_auditoria_aluno;
INSERT INTO aluno (nome) VALUES ('Carga em massa');           -- nao audita
ALTER TABLE aluno ENABLE TRIGGER trg_auditoria_aluno;
INSERT INTO aluno (nome) VALUES ('Depois de reabilitar');     -- audita

SELECT operacao, nome_novo FROM auditoria_aluno
 WHERE nome_novo IN ('Carga em massa', 'Depois de reabilitar');

-- triggers do banco, com tabela, momento e eventos
SELECT event_object_table AS tabela, trigger_name, action_timing AS momento,
       string_agg(event_manipulation, ', ' ORDER BY event_manipulation) AS eventos
  FROM information_schema.triggers
 GROUP BY event_object_table, trigger_name, action_timing
 ORDER BY tabela, trigger_name;
