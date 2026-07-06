-- BD1401-Joins.sql
-- Oracle: Joins e Subqueries
-- UA5 - Aula 14 - Linguagem SQL: DML e DQL

-- ============================================================
-- PARTE 1: INNER JOIN (ANSI)
-- ============================================================
SELECT a.nome AS aluno, c.nome AS curso, t.horario
  FROM aluno a
 INNER JOIN matricula m ON m.aluno_id = a.aluno_id
 INNER JOIN turma t    ON t.turma_id = m.turma_id
 INNER JOIN curso c    ON c.curso_id = t.curso_id
 ORDER BY a.nome;

-- ============================================================
-- PARTE 2: LEFT JOIN
-- ============================================================
-- Todos os professores, mesmo sem turma
SELECT p.nome AS professor, t.turma_id, t.horario
  FROM professor p
  LEFT JOIN turma t ON t.professor_id = p.professor_id
 ORDER BY p.nome;

-- Professores SEM turma (anti-join)
SELECT p.nome
  FROM professor p
  LEFT JOIN turma t ON t.professor_id = p.professor_id
 WHERE t.turma_id IS NULL;

-- ============================================================
-- PARTE 3: RIGHT JOIN e FULL OUTER JOIN
-- ============================================================
-- RIGHT JOIN: todas as turmas + professores (equivale a LEFT JOIN invertido)
SELECT p.nome AS professor, t.turma_id
  FROM professor p
 RIGHT JOIN turma t ON t.professor_id = p.professor_id;

-- FULL OUTER JOIN: tudo de ambos os lados
SELECT p.nome AS professor, t.turma_id
  FROM professor p
  FULL OUTER JOIN turma t ON t.professor_id = p.professor_id;

-- ============================================================
-- PARTE 4: Oracle (+) - Sintaxe legada (apenas para conhecimento)
-- ============================================================
-- LEFT JOIN com (+)
SELECT p.nome, t.turma_id
  FROM professor p, turma t
 WHERE t.professor_id(+) = p.professor_id;
-- O (+) vai do lado que pode ser NULL (lado opcional)

-- RIGHT JOIN com (+)
SELECT p.nome, t.turma_id
  FROM professor p, turma t
 WHERE p.professor_id(+) = t.professor_id;

-- ============================================================
-- PARTE 5: CROSS JOIN
-- ============================================================
SELECT c.nome AS curso, p.nome AS professor
  FROM curso c
 CROSS JOIN professor p
 ORDER BY c.nome, p.nome;

-- ============================================================
-- PARTE 6: SUBQUERIES
-- ============================================================

-- Subquery escalar no SELECT
SELECT a.nome,
       (SELECT COUNT(*)
          FROM ausencia au
          JOIN matricula m ON m.matricula_id = au.matricula_id
         WHERE m.aluno_id = a.aluno_id) AS total_faltas
  FROM aluno a
 ORDER BY total_faltas DESC;

-- Subquery no WHERE com IN
SELECT nome FROM aluno
 WHERE aluno_id IN (SELECT aluno_id FROM matricula WHERE turma_id = 1);

-- Subquery no WHERE com EXISTS
SELECT nome FROM aluno a
 WHERE EXISTS (SELECT 1 FROM matricula m
                WHERE m.aluno_id = a.aluno_id
                  AND m.turma_id = 1);

-- NOT EXISTS (alunos sem faltas)
SELECT nome FROM aluno a
 WHERE NOT EXISTS (SELECT 1 FROM ausencia au
                    JOIN matricula m ON m.matricula_id = au.matricula_id
                   WHERE m.aluno_id = a.aluno_id);

-- ANY e ALL
-- Funcionarios que ganham mais que PELO MENOS 1 pessoa de TI
SELECT nome, salario FROM funcionario
 WHERE salario > ANY (SELECT salario FROM funcionario WHERE depto = 'TI');

-- Funcionario que ganha mais que TODOS de TI
SELECT nome, salario FROM funcionario
 WHERE salario > ALL (SELECT salario FROM funcionario WHERE depto = 'TI');

-- ============================================================
-- PARTE 7: Subquery no FROM (tabela derivada / inline view)
-- ============================================================
SELECT sub.curso_nome, ROUND(AVG(sub.total_alunos), 1) AS media_alunos
  FROM (SELECT c.nome AS curso_nome, COUNT(m.matricula_id) AS total_alunos
          FROM curso c
          JOIN turma t ON t.curso_id = c.curso_id
          JOIN matricula m ON m.turma_id = t.turma_id
         GROUP BY c.nome) sub
 GROUP BY sub.curso_nome;

-- ============================================================
-- PARTE 8: WITH (CTE - Common Table Expression)
-- ============================================================
WITH faltas_aluno AS (
    SELECT a.nome, COUNT(au.ausencia_id) AS total_faltas
      FROM aluno a
      JOIN matricula m ON m.aluno_id = a.aluno_id
      LEFT JOIN ausencia au ON au.matricula_id = m.matricula_id
     GROUP BY a.nome
)
SELECT nome, total_faltas
  FROM faltas_aluno
 WHERE total_faltas > 0
 ORDER BY total_faltas DESC;
