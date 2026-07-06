-- BD1501-WindowFunctions.sql
-- Oracle: Agregacao, GROUP BY, HAVING e Window Functions
-- UA5 - Aula 15 - Linguagem SQL: DML e DQL

-- ============================================================
-- PARTE 1: FUNCOES DE AGREGACAO
-- ============================================================
SELECT COUNT(*)        AS total_alunos,
       COUNT(DISTINCT curso_id) AS cursos_ativos
  FROM matricula m
  JOIN turma t ON t.turma_id = m.turma_id;

-- ============================================================
-- PARTE 2: GROUP BY
-- ============================================================
-- Alunos por curso
SELECT c.nome AS curso, COUNT(m.matricula_id) AS total_matriculas
  FROM curso c
  JOIN turma t    ON t.curso_id = c.curso_id
  JOIN matricula m ON m.turma_id = t.turma_id
 GROUP BY c.nome
 ORDER BY total_matriculas DESC;

-- Faltas por aluno
SELECT a.nome, COUNT(au.ausencia_id) AS faltas
  FROM aluno a
  JOIN matricula m ON m.aluno_id = a.aluno_id
  LEFT JOIN ausencia au ON au.matricula_id = m.matricula_id
 GROUP BY a.nome
 ORDER BY faltas DESC;

-- ============================================================
-- PARTE 3: HAVING
-- ============================================================
SELECT c.nome, COUNT(m.matricula_id) AS total
  FROM curso c
  JOIN turma t    ON t.curso_id = c.curso_id
  JOIN matricula m ON m.turma_id = t.turma_id
 GROUP BY c.nome
HAVING COUNT(m.matricula_id) >= 2;

-- WHERE + HAVING juntos
SELECT c.nome, COUNT(*) AS total
  FROM curso c
  JOIN turma t ON t.curso_id = c.curso_id
 WHERE t.data_inicial >= DATE '2025-01-01'
 GROUP BY c.nome
HAVING COUNT(*) >= 1;

-- ============================================================
-- PARTE 4: ROW_NUMBER, RANK, DENSE_RANK
-- ============================================================
SELECT nome, salario, depto,
       ROW_NUMBER() OVER (ORDER BY salario DESC) AS row_num,
       RANK()       OVER (ORDER BY salario DESC) AS rank_num,
       DENSE_RANK() OVER (ORDER BY salario DESC) AS dense_num
  FROM funcionario;

-- Top 3 salarios por departamento
SELECT nome, depto, salario, posicao
  FROM (SELECT nome, depto, salario,
               RANK() OVER (PARTITION BY depto ORDER BY salario DESC) AS posicao
          FROM funcionario)
 WHERE posicao <= 3;

-- ============================================================
-- PARTE 5: LAG e LEAD
-- ============================================================
SELECT cliente_id, data_pedido, valor_total,
       LAG(valor_total)  OVER (PARTITION BY cliente_id ORDER BY data_pedido) AS anterior,
       LEAD(valor_total) OVER (PARTITION BY cliente_id ORDER BY data_pedido) AS proximo,
       ROUND(valor_total - LAG(valor_total) OVER (
           PARTITION BY cliente_id ORDER BY data_pedido), 2) AS variacao
  FROM pedido
 ORDER BY cliente_id, data_pedido;

-- ============================================================
-- PARTE 6: FIRST_VALUE, LAST_VALUE
-- ============================================================
SELECT DISTINCT cliente_id,
       FIRST_VALUE(valor_total) OVER (
           PARTITION BY cliente_id ORDER BY data_pedido
           ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
       ) AS primeiro_pedido,
       LAST_VALUE(valor_total) OVER (
           PARTITION BY cliente_id ORDER BY data_pedido
           ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
       ) AS ultimo_pedido
  FROM pedido;

-- ============================================================
-- PARTE 7: MEDIA MOVEL
-- ============================================================
SELECT cliente_id, data_pedido, valor_total,
       ROUND(AVG(valor_total) OVER (
           PARTITION BY cliente_id
           ORDER BY data_pedido
           ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
       ), 2) AS media_movel_3
  FROM pedido
 ORDER BY cliente_id, data_pedido;

-- ============================================================
-- PARTE 8: SUM ACUMULADO (RUNNING TOTAL)
-- ============================================================
SELECT cliente_id, data_pedido, valor_total,
       SUM(valor_total) OVER (
           PARTITION BY cliente_id
           ORDER BY data_pedido
           ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
       ) AS total_acumulado
  FROM pedido
 ORDER BY cliente_id, data_pedido;

-- ============================================================
-- PARTE 9: LISTAGG (Oracle) - agregacao de string
-- ============================================================
SELECT c.nome AS curso,
       LISTAGG(a.nome, ', ') WITHIN GROUP (ORDER BY a.nome) AS alunos
  FROM curso c
  JOIN turma t    ON t.curso_id = c.curso_id
  JOIN matricula m ON m.turma_id = t.turma_id
  JOIN aluno a    ON a.aluno_id = m.aluno_id
 GROUP BY c.nome;
