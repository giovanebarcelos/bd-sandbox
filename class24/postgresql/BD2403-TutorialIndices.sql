-- ============================================================================
-- BD2403-TutorialIndices.sql
-- Aula 24 - Tutorial passo a passo: indices e planos de execucao
-- SGBD: PostgreSQL 17 (container "postgres" do ambiente Docker da disciplina)
--
-- Passos 2 a 11 do tutorial Aula_24_..._Tutorial_PostgreSQL.md, banco aula24.
-- Rode antes a carga: BD2402-CargaBoaSaude.sql. Os tempos dos planos variam
-- de maquina para maquina; o que importa e o TIPO de operacao.
-- ============================================================================


-- ----------------------------------------------------------------------------
-- PASSO 2. EXPLAIN x EXPLAIN ANALYZE
-- ----------------------------------------------------------------------------
-- EXPLAIN: so o plano ESTIMADO (nao executa)
EXPLAIN
SELECT consulta_id, paciente_id, status, valor
FROM   consulta
WHERE  data_hora BETWEEN '2025-06-01' AND '2025-06-07 23:59:59';

-- EXPLAIN ANALYZE: executa e mostra o REAL ao lado do estimado
EXPLAIN ANALYZE
SELECT consulta_id, paciente_id, status, valor
FROM   consulta
WHERE  data_hora BETWEEN '2025-06-01' AND '2025-06-07 23:59:59';


-- ----------------------------------------------------------------------------
-- PASSO 3. B-TREE COMPOSTO: a ORDEM das colunas importa
-- ----------------------------------------------------------------------------
CREATE INDEX idx_consulta_medico_data ON consulta (medico_id, data_hora);

-- 3a. Filtra pela 1a coluna (medico_id) + 2a (data_hora): usa o indice
EXPLAIN ANALYZE
SELECT consulta_id, data_hora, status
FROM   consulta
WHERE  medico_id = 42
AND    data_hora BETWEEN '2025-06-01' AND '2025-06-07 23:59:59';

-- 3b. Filtra so pela 2a coluna (data_hora): o indice composto NAO ajuda
EXPLAIN ANALYZE
SELECT consulta_id, paciente_id, status, valor
FROM   consulta
WHERE  data_hora BETWEEN '2025-06-01' AND '2025-06-07 23:59:59';

-- 3c. Indice proprio para data_hora
CREATE INDEX idx_consulta_data ON consulta (data_hora);

EXPLAIN ANALYZE
SELECT consulta_id, paciente_id, status, valor
FROM   consulta
WHERE  data_hora BETWEEN '2025-06-01' AND '2025-06-07 23:59:59';


-- ----------------------------------------------------------------------------
-- PASSO 4. INDEX ONLY SCAN: a consulta resolvida so pelo indice
-- ----------------------------------------------------------------------------
EXPLAIN ANALYZE
SELECT COUNT(*) FROM consulta WHERE medico_id = 42;

-- Agora pedindo uma coluna que NAO esta no indice (valor): precisa ir a tabela
EXPLAIN ANALYZE
SELECT SUM(valor) FROM consulta WHERE medico_id = 42;


-- ----------------------------------------------------------------------------
-- PASSO 5. INDICE DE EXPRESSAO (funcional): busca sem diferenciar maiusculas
-- ----------------------------------------------------------------------------
EXPLAIN ANALYZE
SELECT paciente_id, nome FROM paciente WHERE UPPER(nome) = 'PACIENTE 12345';

CREATE INDEX idx_paciente_nome_upper ON paciente (UPPER(nome));

EXPLAIN ANALYZE
SELECT paciente_id, nome FROM paciente WHERE UPPER(nome) = 'PACIENTE 12345';

-- sem o UPPER na consulta, o indice de expressao nao serve
EXPLAIN
SELECT paciente_id, nome FROM paciente WHERE nome = 'Paciente 12345';


-- ----------------------------------------------------------------------------
-- PASSO 6. SELETIVIDADE: quando o otimizador PREFERE nao usar o indice
-- ----------------------------------------------------------------------------
CREATE INDEX idx_consulta_status ON consulta (status);

-- CANCELADA = 5% das linhas: usa o indice
EXPLAIN ANALYZE SELECT * FROM consulta WHERE status = 'CANCELADA';

-- REALIZADA = 90% das linhas: ler a tabela inteira sai mais barato
EXPLAIN ANALYZE SELECT * FROM consulta WHERE status = 'REALIZADA';

-- as estatisticas que o otimizador usou para decidir
SELECT most_common_vals, most_common_freqs
  FROM pg_stats
 WHERE tablename = 'consulta' AND attname = 'status';


-- ----------------------------------------------------------------------------
-- PASSO 7. INDICE PARCIAL: indexar so as linhas que interessam
-- ----------------------------------------------------------------------------
CREATE INDEX idx_consulta_agendada ON consulta (data_hora) WHERE status = 'AGENDADA';

EXPLAIN ANALYZE
SELECT consulta_id, data_hora FROM consulta
WHERE  status = 'AGENDADA' AND data_hora >= '2025-12-01'
ORDER  BY data_hora;

SELECT indexrelname AS indice, pg_size_pretty(pg_relation_size(indexrelid)) AS tamanho
  FROM pg_stat_user_indexes
 WHERE indexrelname IN ('idx_consulta_data', 'idx_consulta_agendada');


-- ----------------------------------------------------------------------------
-- PASSO 8. HASH: so igualdade
-- ----------------------------------------------------------------------------
CREATE INDEX idx_paciente_email_hash ON paciente USING HASH (email);

-- igualdade: usa o hash
EXPLAIN SELECT * FROM paciente WHERE email = 'paciente777@boasaude.com.br';

-- intervalo / prefixo: o hash nao serve (Seq Scan)
EXPLAIN SELECT * FROM paciente WHERE email > 'paciente999';


-- ----------------------------------------------------------------------------
-- PASSO 9. GIN: busca de texto completo
-- ----------------------------------------------------------------------------
EXPLAIN ANALYZE
SELECT COUNT(*) FROM prontuario
WHERE  to_tsvector('portuguese', descricao) @@ to_tsquery('portuguese', 'dor & cabeca');

CREATE INDEX idx_prontuario_descricao_gin
    ON prontuario USING GIN (to_tsvector('portuguese', descricao));

EXPLAIN ANALYZE
SELECT COUNT(*) FROM prontuario
WHERE  to_tsvector('portuguese', descricao) @@ to_tsquery('portuguese', 'dor & cabeca');

-- o que o GIN guarda: palavras normalizadas (lexemas)
SELECT to_tsvector('portuguese', 'Paciente relata dor de cabeca recorrente e cansaco.');


-- ----------------------------------------------------------------------------
-- PASSO 10. GiST + EXCLUDE: proibir horarios sobrepostos
-- ----------------------------------------------------------------------------
CREATE EXTENSION IF NOT EXISTS btree_gist;

CREATE TABLE agenda_sala (
    agenda_id  INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    medico_id  INTEGER NOT NULL REFERENCES medico (medico_id),
    periodo    TSRANGE NOT NULL,
    CONSTRAINT excl_agenda_sem_conflito
        EXCLUDE USING GIST (medico_id WITH =, periodo WITH &&)
);

INSERT INTO agenda_sala (medico_id, periodo) VALUES
    (42, '[2026-11-03 09:00, 2026-11-03 09:30)'),
    (42, '[2026-11-03 09:30, 2026-11-03 10:00)'),
    (7,  '[2026-11-03 09:00, 2026-11-03 09:30)');

-- sobrepoe 09:15-09:45 do medico 42: rejeitado (erro proposital)
INSERT INTO agenda_sala (medico_id, periodo) VALUES (42, '[2026-11-03 09:15, 2026-11-03 09:45)');

SELECT medico_id, periodo FROM agenda_sala ORDER BY medico_id, periodo;


-- ----------------------------------------------------------------------------
-- PASSO 11. O CUSTO DOS INDICES: espaco e escrita
-- ----------------------------------------------------------------------------
SELECT pg_size_pretty(pg_table_size('consulta'))   AS dados,
       pg_size_pretty(pg_indexes_size('consulta')) AS indices;

-- grava ja as estatisticas desta sessao (senao saem com atraso de ~1 s)
SELECT pg_stat_force_next_flush();

SELECT indexrelname AS indice,
       pg_size_pretty(pg_relation_size(indexrelid)) AS tamanho,
       idx_scan AS vezes_usado
  FROM pg_stat_user_indexes
 WHERE relname = 'consulta'
 ORDER BY pg_relation_size(indexrelid) DESC;

-- Quanto custa gravar 50 mil consultas COM e SEM indices. Duas copias da
-- tabela, nenhuma com chave estrangeira, para comparar so o efeito dos indices:
--   INCLUDING ALL copia os 6 indices; a outra copia nao tem nenhum.
CREATE TABLE consulta_com_indices (LIKE consulta INCLUDING ALL);
CREATE TABLE consulta_sem_indices (LIKE consulta INCLUDING DEFAULTS INCLUDING IDENTITY);

\timing on
INSERT INTO consulta_com_indices (paciente_id, medico_id, convenio_id, data_hora, status, valor)
SELECT (g % 50000) + 1, (g % 200) + 1, 1, TIMESTAMP '2026-01-01' + (g || ' minutes')::interval,
       'AGENDADA', 100
FROM   generate_series(1, 50000) AS g;

INSERT INTO consulta_sem_indices (paciente_id, medico_id, convenio_id, data_hora, status, valor)
SELECT (g % 50000) + 1, (g % 200) + 1, 1, TIMESTAMP '2026-01-01' + (g || ' minutes')::interval,
       'AGENDADA', 100
FROM   generate_series(1, 50000) AS g;
\timing off

DROP TABLE consulta_com_indices, consulta_sem_indices;
