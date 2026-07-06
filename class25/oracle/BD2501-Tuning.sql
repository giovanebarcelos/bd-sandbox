-- BD2501-Tuning.sql
-- Oracle: Otimizacao e Tuning
-- UA9 - Aula 25 - Catalogo, Indices e Performance

-- ============================================================
-- PARTE 1: ESTATISTICAS
-- ============================================================
-- Coletar estatisticas
EXEC DBMS_STATS.GATHER_TABLE_STATS(USER, 'ALUNO');
EXEC DBMS_STATS.GATHER_TABLE_STATS(USER, 'MATRICULA');
EXEC DBMS_STATS.GATHER_TABLE_STATS(USER, 'TURMA');

-- Verificar quando foram coletadas
SELECT table_name, last_analyzed, num_rows
  FROM user_tables
 WHERE table_name IN ('ALUNO', 'MATRICULA', 'TURMA');

-- ============================================================
-- PARTE 2: EXPLAIN PLAN
-- ============================================================
EXPLAIN PLAN FOR
SELECT a.nome, COUNT(*)
  FROM aluno a
  JOIN matricula m ON m.aluno_id = a.aluno_id
  JOIN turma t    ON t.turma_id = m.turma_id
 GROUP BY a.nome;

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY());

-- ============================================================
-- PARTE 3: AUTOTRACE (SQL*Plus)
-- ============================================================
-- SET AUTOTRACE ON;
-- SET AUTOTRACE TRACEONLY;
SELECT a.nome, t.horario
  FROM aluno a
  JOIN matricula m ON m.aluno_id = a.aluno_id
  JOIN turma t    ON t.turma_id = m.turma_id;

-- ============================================================
-- PARTE 4: HINTS (Oracle especifico)
-- ============================================================
-- Forcar uso de indice
SELECT /*+ INDEX(a idx_aluno_nome) */ nome
  FROM aluno a
 WHERE nome LIKE 'A%';

-- Forcar HASH JOIN
SELECT /*+ USE_HASH(a m) */ a.nome
  FROM aluno a
  JOIN matricula m ON m.aluno_id = a.aluno_id;

-- ============================================================
-- PARTE 5: MONITORAMENTO
-- ============================================================
-- Top SQL por elapsed time
SELECT sql_id, executions,
       ROUND(elapsed_time/1000000, 2) AS elapsed_sec,
       SUBSTR(sql_text, 1, 100) AS sql_text
  FROM v$sql
 WHERE executions > 0
 ORDER BY elapsed_time DESC
 FETCH FIRST 5 ROWS ONLY;

-- Tamanho de tabelas e indices
SELECT segment_name, segment_type,
       ROUND(bytes/1024/1024, 2) AS tamanho_mb
  FROM user_segments
 WHERE segment_name IN ('ALUNO', 'MATRICULA', 'TURMA')
 ORDER BY bytes DESC;

-- ============================================================
-- PARTE 6: CRIAR INDICE PARA MELHORAR PERFORMANCE
-- ============================================================
-- Antes: verificar plano sem indice
EXPLAIN PLAN FOR
SELECT * FROM matricula WHERE aluno_id = 1;
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY());

-- Criar indice
CREATE INDEX idx_matricula_aluno ON matricula(aluno_id);

-- Depois: plano com indice
EXPLAIN PLAN FOR
SELECT * FROM matricula WHERE aluno_id = 1;
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY());
