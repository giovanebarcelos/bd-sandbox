-- ============================================================================
-- BD2502-TutorialTuning.sql
-- Aula 25 - Tutorial passo a passo: otimizacao e tuning
-- SGBD: PostgreSQL 17 (container "postgres" do ambiente Docker da disciplina)
--
-- Roteiro do tutorial Aula_25_..._Tutorial_PostgreSQL.md, banco aula25.
-- Usa a Escola de Informatica (Aula 06) com volume: 50 mil alunos e 200 mil
-- matriculas. O autovacuum fica DESLIGADO nessas tabelas durante o tutorial,
-- para que voce veja o efeito de estatisticas desatualizadas; o passo 10
-- religa. O passo 9 (pg_stat_statements) exige reiniciar o servidor e esta
-- descrito no tutorial.
-- ============================================================================


-- ----------------------------------------------------------------------------
-- PASSO 1. SCHEMA COM POUCOS DADOS E ESTATISTICAS COLETADAS
-- ----------------------------------------------------------------------------
SET client_min_messages = warning;
DROP TABLE IF EXISTS matricula, turma, aluno, curso CASCADE;
RESET client_min_messages;

CREATE TABLE curso (
    curso_id  INT PRIMARY KEY,
    nome      VARCHAR(100) NOT NULL
);

CREATE TABLE turma (
    turma_id  INT PRIMARY KEY,
    curso_id  INT NOT NULL REFERENCES curso (curso_id),
    horario   VARCHAR(5) NOT NULL
);

CREATE TABLE aluno (
    aluno_id        INT PRIMARY KEY,
    nome            VARCHAR(200) NOT NULL,
    cidade          VARCHAR(60)  NOT NULL
);

CREATE TABLE matricula (
    matricula_id    INT PRIMARY KEY,
    aluno_id        INT  NOT NULL REFERENCES aluno (aluno_id),
    turma_id        INT  NOT NULL REFERENCES turma (turma_id),
    data_matricula  DATE NOT NULL,
    situacao        VARCHAR(10) NOT NULL
) WITH (autovacuum_enabled = false);

ALTER TABLE aluno SET (autovacuum_enabled = false);

INSERT INTO curso SELECT g, 'Curso ' || g FROM generate_series(1, 20) AS g;
INSERT INTO turma SELECT g, (g % 20) + 1, LPAD(((g % 14) + 8)::text, 2, '0') || ':00'
  FROM generate_series(1, 2000) AS g;

-- so 10 alunos e 10 matriculas por enquanto...
INSERT INTO aluno SELECT g, 'Aluno ' || g, 'Cidade ' || (g % 50) FROM generate_series(1, 10) AS g;
INSERT INTO matricula SELECT g, g, g, DATE '2024-01-01' + g, 'ATIVA' FROM generate_series(1, 10) AS g;

-- ...e as estatisticas sao coletadas AGORA, com a tabela pequena
ANALYZE curso, turma, aluno, matricula;


-- ----------------------------------------------------------------------------
-- PASSO 2. A CARGA DE VERDADE (sem atualizar as estatisticas)
-- ----------------------------------------------------------------------------
INSERT INTO aluno
SELECT g, 'Aluno ' || g, 'Cidade ' || (g % 50) FROM generate_series(11, 50000) AS g;

INSERT INTO matricula
SELECT g,
       (g % 50000) + 1,
       (g % 2000) + 1,
       DATE '2023-01-01' + (g % 1000),
       CASE WHEN g % 10 = 0 THEN 'TRANCADA' ELSE 'ATIVA' END
  FROM generate_series(11, 200000) AS g;

-- o que o catalogo "acha" que a tabela tem x o que ela tem de fato
SELECT relname, reltuples::bigint AS linhas_estimadas
  FROM pg_class WHERE relname IN ('aluno', 'matricula');

SELECT relname, n_live_tup, n_mod_since_analyze, last_analyze
  FROM pg_stat_user_tables WHERE relname IN ('aluno', 'matricula');


-- ----------------------------------------------------------------------------
-- PASSO 3. PLANO COM ESTATISTICAS VELHAS x NOVAS
-- ----------------------------------------------------------------------------
-- consulta: quantas matriculas ativas cada cidade tem
EXPLAIN (ANALYZE, BUFFERS)
SELECT a.cidade, COUNT(*)
  FROM aluno a
  JOIN matricula m ON m.aluno_id = a.aluno_id
 WHERE m.situacao = 'ATIVA'
 GROUP BY a.cidade;

ANALYZE aluno, matricula;

EXPLAIN (ANALYZE, BUFFERS)
SELECT a.cidade, COUNT(*)
  FROM aluno a
  JOIN matricula m ON m.aluno_id = a.aluno_id
 WHERE m.situacao = 'ATIVA'
 GROUP BY a.cidade;


-- ----------------------------------------------------------------------------
-- PASSO 4. O EXERCICIO DO SLIDE 23: Seq Scan + Sort em disco
-- ----------------------------------------------------------------------------
SET work_mem = '64kB';

EXPLAIN (ANALYZE, BUFFERS)
SELECT a.nome, m.data_matricula
  FROM matricula m
  JOIN aluno a ON a.aluno_id = m.aluno_id
 WHERE m.data_matricula > '2025-09-01'
 ORDER BY a.nome;


-- ----------------------------------------------------------------------------
-- PASSO 5. CORRECAO 1: indice no filtro
-- ----------------------------------------------------------------------------
CREATE INDEX idx_matricula_data ON matricula (data_matricula);

EXPLAIN (ANALYZE, BUFFERS)
SELECT a.nome, m.data_matricula
  FROM matricula m
  JOIN aluno a ON a.aluno_id = m.aluno_id
 WHERE m.data_matricula > '2025-09-01'
 ORDER BY a.nome;


-- ----------------------------------------------------------------------------
-- PASSO 6. CORRECAO 2: work_mem para o Sort caber em memoria
-- ----------------------------------------------------------------------------
SHOW work_mem;
SET work_mem = '16MB';

EXPLAIN (ANALYZE, BUFFERS)
SELECT a.nome, m.data_matricula
  FROM matricula m
  JOIN aluno a ON a.aluno_id = m.aluno_id
 WHERE m.data_matricula > '2025-09-01'
 ORDER BY a.nome;

RESET work_mem;


-- ----------------------------------------------------------------------------
-- PASSO 7. CHAVE ESTRANGEIRA SEM INDICE (o PostgreSQL nao cria sozinho)
-- ----------------------------------------------------------------------------
EXPLAIN ANALYZE
SELECT m.matricula_id, m.data_matricula FROM matricula m WHERE m.aluno_id = 4242;

CREATE INDEX idx_matricula_aluno ON matricula (aluno_id);

EXPLAIN ANALYZE
SELECT m.matricula_id, m.data_matricula FROM matricula m WHERE m.aluno_id = 4242;

-- as FKs sem indice no banco inteiro
SELECT c.conrelid::regclass AS tabela, a.attname AS coluna_fk
  FROM pg_constraint c
  JOIN pg_attribute a ON a.attrelid = c.conrelid AND a.attnum = c.conkey[1]
 WHERE c.contype = 'f'
   AND NOT EXISTS (SELECT 1 FROM pg_index i
                    WHERE i.indrelid = c.conrelid AND i.indkey[0] = c.conkey[1]);


-- ----------------------------------------------------------------------------
-- PASSO 8. BLOAT E VACUUM
-- ----------------------------------------------------------------------------
SELECT pg_size_pretty(pg_table_size('matricula')) AS tamanho_antes;

-- metade das matriculas muda de situacao: cada UPDATE cria uma versao nova
UPDATE matricula SET situacao = 'CONCLUIDA' WHERE matricula_id % 2 = 0;

-- grava as estatisticas desta sessao ja (senao saem com ~1 s de atraso)
SELECT pg_stat_force_next_flush();

SELECT relname, n_live_tup, n_dead_tup,
       ROUND(n_dead_tup * 100.0 / NULLIF(n_live_tup + n_dead_tup, 0), 1) AS dead_pct,
       pg_size_pretty(pg_table_size(relid)) AS tamanho
  FROM pg_stat_user_tables WHERE relname = 'matricula';

VACUUM matricula;
SELECT pg_stat_force_next_flush();

SELECT relname, n_live_tup, n_dead_tup, pg_size_pretty(pg_table_size(relid)) AS tamanho
  FROM pg_stat_user_tables WHERE relname = 'matricula';

VACUUM FULL matricula;

SELECT pg_size_pretty(pg_table_size('matricula')) AS tamanho_depois_do_full;


-- ----------------------------------------------------------------------------
-- PASSO 10. PARAMETROS E RELIGAR O AUTOVACUUM
-- ----------------------------------------------------------------------------
SELECT name, setting, unit, context
  FROM pg_settings
 WHERE name IN ('shared_buffers', 'work_mem', 'maintenance_work_mem',
                'effective_cache_size', 'random_page_cost', 'max_connections', 'autovacuum')
 ORDER BY name;

-- taxa de acerto do cache (blocos achados na memoria / total)
SELECT datname,
       ROUND(blks_hit * 100.0 / NULLIF(blks_hit + blks_read, 0), 2) AS cache_hit_pct
  FROM pg_stat_database WHERE datname = current_database();

ALTER TABLE aluno     RESET (autovacuum_enabled);
ALTER TABLE matricula RESET (autovacuum_enabled);
