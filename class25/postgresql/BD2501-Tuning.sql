-- BD2501-Tuning.sql
-- PostgreSQL: Otimizacao e Tuning
-- UA9 - Aula 25 - Catalogo, Indices e Performance

-- ============================================================
-- PARTE 1: CONFIGURACAO (verificar)
-- ============================================================
SHOW shared_buffers;
SHOW work_mem;
SHOW effective_cache_size;
SHOW autovacuum;

-- ============================================================
-- PARTE 2: ESTATISTICAS E VACUUM
-- ============================================================
ANALYZE aluno;
ANALYZE matricula;
ANALYZE turma;

VACUUM ANALYZE aluno;

-- Verificar estatisticas
SELECT relname, last_analyze, last_vacuum,
       n_live_tup, n_dead_tup,
       ROUND(n_dead_tup * 100.0 / NULLIF(n_live_tup, 0), 1) AS dead_pct
  FROM pg_stat_user_tables
 WHERE relname IN ('aluno', 'matricula', 'turma');

-- ============================================================
-- PARTE 3: EXPLAIN ANALYZE
-- ============================================================
EXPLAIN ANALYZE
SELECT a.nome, COUNT(*)
  FROM aluno a
  JOIN matricula m ON m.aluno_id = a.aluno_id
  JOIN turma t    ON t.turma_id = m.turma_id
 GROUP BY a.nome;

EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM matricula WHERE aluno_id = 1;

-- ============================================================
-- PARTE 4: PG_STAT_STATEMENTS (top queries)
-- ============================================================
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;

SELECT query,
       calls,
       ROUND(mean_exec_time::NUMERIC, 2) AS avg_ms,
       ROUND(total_exec_time::NUMERIC, 2) AS total_ms,
       ROWS
  FROM pg_stat_statements
 ORDER BY total_exec_time DESC
 LIMIT 10;

-- Resetar estatisticas
-- SELECT pg_stat_statements_reset();

-- ============================================================
-- PARTE 5: INDICES E PERFORMANCE
-- ============================================================
-- Verificar indices existentes
SELECT indexname, indexdef
  FROM pg_indexes
 WHERE tablename = 'matricula';

-- Tamanho de tabelas e indices
SELECT relname,
       pg_size_pretty(pg_total_relation_size(oid)) AS tamanho_total,
       pg_size_pretty(pg_table_size(oid)) AS dados,
       pg_size_pretty(pg_indexes_size(oid)) AS indices
  FROM pg_class
 WHERE relname IN ('aluno', 'matricula', 'turma')
   AND relkind = 'r';

-- Criar indice e comparar
EXPLAIN ANALYZE SELECT * FROM matricula WHERE aluno_id = 1;

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_matricula_aluno
    ON matricula(aluno_id);

EXPLAIN ANALYZE SELECT * FROM matricula WHERE aluno_id = 1;

-- ============================================================
-- PARTE 6: AUTO_EXPLAIN (log de queries lentas)
-- ============================================================
-- Configurar no postgresql.conf ou via ALTER
-- ALTER SYSTEM SET auto_explain.log_min_duration = 1000;  -- 1 segundo
-- ALTER SYSTEM SET auto_explain.log_analyze = on;
-- SELECT pg_reload_conf();

-- ============================================================
-- PARTE 7: MONITORAMENTO DE LOCKS
-- ============================================================
SELECT blocked_locks.pid AS blocked_pid,
       blocking_locks.pid AS blocking_pid,
       blocked_activity.query AS blocked_query
  FROM pg_locks blocked_locks
  JOIN pg_stat_activity blocked_activity
    ON blocked_activity.pid = blocked_locks.pid
  JOIN pg_locks blocking_locks
    ON blocking_locks.locktype = blocked_locks.locktype
   AND blocking_locks.database IS NOT DISTINCT FROM blocked_locks.database
   AND blocking_locks.relation IS NOT DISTINCT FROM blocked_locks.relation
   AND blocking_locks.pid != blocked_locks.pid
  JOIN pg_stat_activity blocking_activity
    ON blocking_activity.pid = blocking_locks.pid
 WHERE NOT blocked_locks.granted;
