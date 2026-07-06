-- BD1701-Integridade.sql
-- PostgreSQL: Integridade Referencial e Boas Praticas
-- UA6 - Aula 17 - Normalizacao e Integridade Referencial

-- ============================================================
-- PARTE 1: CASCADE (entidade fraca)
-- ============================================================
DROP TABLE IF EXISTS ausencia CASCADE;
CREATE TABLE ausencia (
    ausencia_id  INT NOT NULL,
    matricula_id INT NOT NULL,
    data         DATE NOT NULL,
    CONSTRAINT pk_ausencia PRIMARY KEY (matricula_id, ausencia_id),
    CONSTRAINT fk_ausencia_matricula FOREIGN KEY (matricula_id)
        REFERENCES matricula (matricula_id) ON DELETE CASCADE
);

-- ============================================================
-- PARTE 2: CHECK constraints
-- ============================================================
ALTER TABLE aluno ADD CONSTRAINT ck_aluno_altura CHECK (altura > 0 AND altura < 3.0);
ALTER TABLE aluno ADD CONSTRAINT ck_aluno_peso CHECK (peso > 0 AND peso < 500);
ALTER TABLE turma ADD CONSTRAINT ck_turma_datas CHECK (data_final >= data_inicial);

ALTER TABLE professor ADD CONSTRAINT ck_titulacao CHECK (
    titulacao IN ('Graduacao', 'Especializacao', 'Mestrado', 'Doutorado'));

-- ============================================================
-- PARTE 3: FK + indices (PostgreSQL nao cria automaticamente)
-- ============================================================
ALTER TABLE turma ADD CONSTRAINT fk_turma_professor
    FOREIGN KEY (professor_id) REFERENCES professor (professor_id)
    ON DELETE RESTRICT;

CREATE INDEX idx_turma_professor ON turma(professor_id);
CREATE INDEX idx_turma_curso ON turma(curso_id);
CREATE INDEX idx_matricula_turma ON matricula(turma_id);
CREATE INDEX idx_matricula_aluno ON matricula(aluno_id);
CREATE INDEX idx_telefone_professor ON telefone(professor_id);

-- ============================================================
-- PARTE 4: DEFERRABLE constraint (PostgreSQL)
-- ============================================================
ALTER TABLE turma DROP CONSTRAINT IF EXISTS fk_turma_professor;
ALTER TABLE turma ADD CONSTRAINT fk_turma_professor
    FOREIGN KEY (professor_id) REFERENCES professor (professor_id)
    DEFERRABLE INITIALLY IMMEDIATE;

-- Agora pode ser deferido em transacao
BEGIN;
  SET CONSTRAINTS fk_turma_professor DEFERRED;
  INSERT INTO turma (turma_id, horario, duracao, data_inicial, data_final,
                      professor_id, curso_id)
       VALUES (99, '19:00', 3, '2026-01-01', '2026-06-30', 999, 1);
  -- professor 999 ainda nao existe!
  INSERT INTO professor (professor_id, cpf, nome)
       VALUES (999, '999.999.999-99', 'Professor Novo');
COMMIT;  -- OK!

-- ============================================================
-- PARTE 5: EXCLUDE constraint (PostgreSQL exclusivo)
-- ============================================================
-- Exemplo: evitar que duas turmas ocupem a mesma sala no mesmo horario
CREATE EXTENSION IF NOT EXISTS btree_gist;

CREATE TABLE reserva_sala (
    sala_id    INT,
    data       DATE,
    hora_inicio TIME,
    hora_fim   TIME,
    EXCLUDE USING gist (
        sala_id WITH =,
        daterange(data, data, '[]') WITH &&,
        tsrange(hora_inicio::TEXT::TIMESTAMP, hora_fim::TEXT::TIMESTAMP) WITH &&
    )
);

-- ============================================================
-- PARTE 6: Exemplo completo
-- ============================================================
CREATE TABLE pedido (
    pedido_id   SERIAL PRIMARY KEY,
    cliente_id  INT NOT NULL,
    data_pedido DATE DEFAULT CURRENT_DATE NOT NULL,
    valor_total NUMERIC(10,2) NOT NULL,
    status      VARCHAR(20) DEFAULT 'PENDENTE' NOT NULL,
    CONSTRAINT fk_pedido_cliente FOREIGN KEY (cliente_id)
        REFERENCES cliente (cliente_id) ON DELETE RESTRICT,
    CONSTRAINT ck_pedido_valor CHECK (valor_total > 0),
    CONSTRAINT ck_pedido_status CHECK (status IN (
        'PENDENTE', 'CONFIRMADO', 'ENVIADO', 'ENTREGUE', 'CANCELADO'))
);

CREATE INDEX idx_pedido_cliente ON pedido(cliente_id);
