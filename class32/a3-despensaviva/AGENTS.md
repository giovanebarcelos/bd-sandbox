# AGENTS.md
DespensaViva (A3 de Banco de Dados) — cozinha comunitária: estoque de insumos em lotes, consumo FEFO. PostgreSQL 17 e Oracle XE 21; Python 3.12 (psycopg, oracledb) e Java 21 (JDBC).

## Onde está cada coisa
- DER: der/despensa.puml (e .mmd) · Regras e decisões: README.md
- SQL por banco: postgresql/ e oracle/ (01_ddl, 02_inserts, 03_consultas, 04_indices) · procedures e triggers: procedures/
- Testes (pytest, rodam nos DOIS bancos): tests/ · Aplicações: python/ e java/ · Desempenho: performance/ · Mutação: scripts/mutacao.py

## Regras
- Todo SQL escrito vale **depois de executado nos dois bancos**: `docker compose run --rm testes` (152 testes) deve passar
- Dialetos: PostgreSQL usa VARCHAR, CURRENT_DATE, `$$`; Oracle usa VARCHAR2, TRUNC(SYSDATE), `/` ao fim de bloco PL/SQL. **Oracle não tem ON DELETE RESTRICT**: omita a cláusula
- Em arquivo Oracle, nunca ponha comentário `--` na mesma linha depois do `;`
- Constraints sempre nomeadas (pk_, uk_, fk_, ck_) e ON DELETE explícito (CASCADE só em receita_insumo -> receita)
- Procedures NÃO fazem COMMIT; mensagens de erro começam em DESPENSA-00x (iguais nos dois bancos)
- Da aplicação, parâmetro NUMERIC no PostgreSQL vai como Decimal, nunca float
- Nunca DROP, TRUNCATE nem DELETE/UPDATE sem WHERE por sugestão do agente, e nunca contra banco que não seja o do laboratório
- Dados de exemplo são fictícios; nenhum dado pessoal real. Senha só de laboratório; chave de API fora do Git
- Commits em Conventional Commits; nunca faça push

## Agent skills
(bloco escrito pela skill setup-matt-pocock-skills)
