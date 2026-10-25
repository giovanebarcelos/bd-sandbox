-- DespensaViva · Oracle · 03_consultas.sql — 10 consultas analíticas.
-- Separador "-- @Qnn" é lido pelos testes (tests/test_consultas.py); cada consulta termina em ponto e vírgula.
-- Técnicas: JOIN (Q01,Q02,Q03,Q06,Q07,Q08,Q10) · window function (Q03,Q05,Q07,Q08) · agregação (Q01,Q03,Q06,Q07,Q10)
--           anti-join (Q04) · divisão relacional (Q09) · ROLLUP (Q10)

-- @Q01 Saldo atual de cada insumo (só lotes não vencidos). JOIN + LEFT JOIN + SUM + GROUP BY.
SELECT i.nome, i.unidade, COALESCE(SUM(l.quantidade_atual), 0) AS saldo
  FROM insumo i
  LEFT JOIN lote l ON l.insumo_id = i.insumo_id AND l.data_validade >= TRUNC(SYSDATE)
 GROUP BY i.insumo_id, i.nome, i.unidade
 ORDER BY i.nome;

-- @Q02 Lotes com saldo que vencem nos próximos 7 dias (RN-05: "prioritários"). JOIN + aritmética de datas.
SELECT i.nome, l.lote_id, l.quantidade_atual, (l.data_validade - TRUNC(SYSDATE)) AS dias_restantes
  FROM lote l
  JOIN insumo i ON i.insumo_id = l.insumo_id
 WHERE l.quantidade_atual > 0
   AND l.data_validade BETWEEN TRUNC(SYSDATE) AND TRUNC(SYSDATE) + 7
 ORDER BY dias_restantes, l.lote_id;

-- @Q03 Top 5 insumos mais consumidos. JOIN + SUM + RANK() OVER.
SELECT t.nome, t.total_consumido, t.ranking
  FROM (SELECT i.nome,
               SUM(m.quantidade) AS total_consumido,
               RANK() OVER (ORDER BY SUM(m.quantidade) DESC) AS ranking
          FROM movimentacao m
          JOIN lote l   ON l.lote_id = m.lote_id
          JOIN insumo i ON i.insumo_id = l.insumo_id
         WHERE m.tipo = 'CONSUMO'
         GROUP BY i.nome) t
 WHERE t.ranking <= 5
 ORDER BY t.ranking, t.nome;

-- @Q04 Insumos nunca consumidos. Anti-join com NOT EXISTS.
SELECT i.nome
  FROM insumo i
 WHERE NOT EXISTS (SELECT 1
                     FROM movimentacao m
                     JOIN lote l ON l.lote_id = m.lote_id
                    WHERE l.insumo_id = i.insumo_id AND m.tipo = 'CONSUMO')
 ORDER BY i.nome;

-- @Q05 Consumo acumulado de cada insumo ao longo do tempo. SUM() OVER (PARTITION BY ... ORDER BY ...).
SELECT i.nome, m.quantidade,
       SUM(m.quantidade) OVER (PARTITION BY i.insumo_id ORDER BY m.data_hora, m.mov_id) AS acumulado
  FROM movimentacao m
  JOIN lote l   ON l.lote_id = m.lote_id
  JOIN insumo i ON i.insumo_id = l.insumo_id
 WHERE m.tipo = 'CONSUMO'
 ORDER BY i.nome, m.data_hora, m.mov_id;

-- @Q06 Insumos abaixo do estoque mínimo (RN-04: alerta de reposição). JOIN + GROUP BY + HAVING.
SELECT i.nome, i.estoque_minimo, COALESCE(SUM(l.quantidade_atual), 0) AS saldo
  FROM insumo i
  LEFT JOIN lote l ON l.insumo_id = i.insumo_id AND l.data_validade >= TRUNC(SYSDATE)
 GROUP BY i.insumo_id, i.nome, i.estoque_minimo
HAVING COALESCE(SUM(l.quantidade_atual), 0) < i.estoque_minimo
 ORDER BY i.nome;

-- @Q07 Participação de cada fornecedor no total de lotes recebidos (%). Agregação dentro de window function.
SELECT f.nome, f.tipo, COUNT(*) AS lotes,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS percentual
  FROM lote l
  JOIN fornecedor f ON f.fornecedor_id = l.fornecedor_id
 GROUP BY f.fornecedor_id, f.nome, f.tipo
 ORDER BY lotes DESC, f.nome;

-- @Q08 Lote que o FEFO consumiria primeiro, por insumo. ROW_NUMBER() OVER (PARTITION BY ...).
SELECT t.nome, t.lote_id, t.dias_restantes
  FROM (SELECT i.nome, l.lote_id, (l.data_validade - TRUNC(SYSDATE)) AS dias_restantes,
               ROW_NUMBER() OVER (PARTITION BY l.insumo_id ORDER BY l.data_validade, l.lote_id) AS rn
          FROM lote l
          JOIN insumo i ON i.insumo_id = l.insumo_id
         WHERE l.quantidade_atual > 0 AND l.data_validade >= TRUNC(SYSDATE)) t
 WHERE t.rn = 1
 ORDER BY t.nome;

-- @Q09 Receitas que o estoque atual permite fazer para 50 porções. Divisão relacional: nenhum ingrediente em falta.
SELECT r.nome
  FROM receita r
 WHERE NOT EXISTS (SELECT 1
                     FROM receita_insumo ri
                    WHERE ri.receita_id = r.receita_id
                      AND ri.quantidade_por_porcao * 50 >
                          (SELECT COALESCE(SUM(l.quantidade_atual), 0)
                             FROM lote l
                            WHERE l.insumo_id = ri.insumo_id AND l.data_validade >= TRUNC(SYSDATE)))
 ORDER BY r.nome;

-- @Q10 Desperdício: saldo de lotes VENCIDOS por categoria, com total geral. JOIN + GROUP BY ROLLUP.
SELECT COALESCE(c.nome, 'TOTAL') AS categoria, SUM(l.quantidade_atual) AS saldo_vencido
  FROM lote l
  JOIN insumo i    ON i.insumo_id = l.insumo_id
  JOIN categoria c ON c.categoria_id = i.categoria_id
 WHERE l.data_validade < TRUNC(SYSDATE) AND l.quantidade_atual > 0
 GROUP BY ROLLUP (c.nome)
 ORDER BY c.nome NULLS LAST;
