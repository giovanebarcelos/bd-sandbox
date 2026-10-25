# AGENTS.md
<Nome do sistema> — Oracle XE e PostgreSQL (Docker), <Java 17 e/ou Python 3.12>.

## Onde está cada coisa
- DER: der/<sistema>.puml · Scripts: oracle/ e postgresql/ (01_ddl, 02_inserts, 03_consultas)
- Procedures e trigger: procedures/ · Performance: performance/explain_antes_depois.txt
- Aplicação: java/ e python/

## Regras
- Todo script roda nos DOIS SGBDs; dialeto nunca misturado (VARCHAR2/NUMBER no Oracle; VARCHAR/IDENTITY no PostgreSQL)
- Constraints nomeadas (pk_, fk_, ck_, uk_) e ON DELETE sempre explícito; toda FK com índice
- Nunca execute DROP, TRUNCATE ou DELETE/UPDATE sem WHERE; o agente escreve o script, quem executa é a dupla
- Consultas na aplicação só com parâmetros bind; senha fora do repositório
- Commits em Conventional Commits; nunca faça push

## Agent skills
(bloco escrito pela skill setup-matt-pocock-skills)
