# Repository — Banco de Dados

Código-fonte de apoio às 32 aulas do curso. Cada `classNN/` corresponde à aula de mesmo
número e contém um subconjunto das pastas abaixo, conforme a natureza do conteúdo:

```
classNN/
├── diagrams/    # Diagramas PlantUML (.puml) — ER, arquitetura, fluxos
├── oracle/      # Scripts SQL/PL-SQL para Oracle Database
├── postgresql/  # Scripts SQL/PL-pgSQL para PostgreSQL
├── java/        # Exemplos de acesso/uso via Java (JDBC)
└── python/      # Exemplos de acesso/uso via Python (oracledb/psycopg2)
```

## Nomenclatura

`BDNNYY-NomeDescritivo.ext`, onde `NN` é o número da aula (01-32) e `YY` um sequencial
(01-99) dentro da aula. Diagramas seguem `BD-NN-NomeDoDiagrama.puml`.

## Tecnologias Utilizadas

- **SGBDs:** Oracle Database XE, PostgreSQL
- **NoSQL (Aula 28):** MongoDB 7, Redis 7, Neo4j 5, Apache Cassandra 4.1
- **Linguagens de aplicação:** Java 17+ (JDBC, drivers Neo4j/Cassandra), Python 3.11+ (`oracledb`, `psycopg2`, `pymongo`, `redis`, `neo4j`, `cassandra-driver`), JavaScript/Node.js 18+ (`mongodb`, `redis`)
- **Diagramas:** PlantUML — visualizar em https://plantuml.com/
- **Infraestrutura:** Docker / Docker Compose

## Sumário por Aula

| Aula | UA | Tema | Diagramas | Oracle | PostgreSQL | Java | Python |
|---|---|---|---|---|---|---|---|
| 01 | UA1 | O que é um SBD | ✓ | — | — | — | — |
| 01B | UA1 | IA assistida: modelos do agente (complementar) | — | — | — | — | — |
| 02 | UA1 | Arquitetura de SGBD | ✓ | — | — | — | — |
| 03 | UA1 | Ferramentas | ✓ | ✓ | ✓ | — | — |
| 04 | UA2 | Entidades e relacionamentos | ✓ | — | — | — | — |
| 05 | UA2 | Cardinalidade e especialização | ✓ | — | — | — | — |
| 06 | UA2 | Estudo de caso: Escola de Informática | ✓ | ✓ | ✓ | — | — |
| 07 | UA3 | Do DER ao modelo relacional | ✓ | — | — | — | — |
| 08 | UA3 | Modelagem física e tipos de dados | — | ✓ | ✓ | — | — |
| 09 | UA3 | Chaves e UUID v7 | — | ✓ | ✓ | ✓ | ✓ |
| 10 | UA4 | DDL: CREATE/ALTER/DROP | — | ✓ | ✓ | — | — |
| 11 | UA4 | DDL avançado: views/particionamento | — | ✓ | ✓ | — | — |
| 12 | UA5 | DML: INSERT/UPDATE/DELETE/MERGE | — | ✓ | ✓ | ✓ | ✓ |
| 13 | UA5 | DQL básico | — | ✓ | ✓ | — | — |
| 14 | UA5 | Joins e subqueries | — | ✓ | ✓ | — | — |
| 15 | UA5 | Agregação e window functions | — | ✓ | ✓ | — | — |
| 16 | UA6 | Formas normais | ✓ | — | — | — | — |
| 17 | UA6 | Integridade referencial | — | ✓ | ✓ | — | — |
| 18 | UA7 | PL/SQL | — | ✓ | — | — | — |
| 19 | UA7 | PL/pgSQL | — | — | ✓ | — | — |
| 20 | UA7 | Triggers | — | ✓ | ✓ | — | — |
| 21 | UA8 | ACID e concorrência | ✓ | ✓ | ✓ | — | — |
| 22 | UA8 | Recuperação de falhas | ✓ | ✓ | ✓ | — | — |
| 23 | UA9 | Catálogo do banco de dados | — | ✓ | ✓ | — | — |
| 24 | UA9 | Índices e planos de execução | — | ✓ | ✓ | — | — |
| 25 | UA9 | Otimização e tuning | — | ✓ | ✓ | — | — |
| 26 | UA10 | Backup e recuperação | — | ✓ | ✓ | — | — |
| 27 | UA10 | Distribuição, replicação e sharding | ✓ | — | — | — | — |
| 28 | UA11 | NoSQL: documento/chave-valor/coluna/grafo + MongoDB, Redis, Neo4j e Cassandra em profundidade (28A-28D) | — | — | — | ✓ | ✓ |
| 29 | UA11 | Big Data e CAP theorem | ✓ | — | — | — | — |
| 30 | UA12 | Conexões: JDBC e DB-API | — | ✓ | ✓ | ✓ | ✓ |
| 31 | UA12 | Segurança: usuários, roles e grants | — | ✓ | ✓ | — | — |
| 32 | UA12 | Projeto integrador final | — | ✓ | ✓ | ✓ | ✓ |

## Tutoriais Passo a Passo (Aulas 18 a 27)

Cada aula de 18 a 27 tem tutoriais passo a passo, em PostgreSQL e/ou Oracle, publicados junto com as aulas. Os scripts usados por eles ficam aqui, com o sequencial seguinte ao do script da aula:

| Aula | Oracle | PostgreSQL |
|---|---|---|
| 18 | `class18/oracle/BD1802-TutorialPlSql.sql` | — |
| 19 | — | `class19/postgresql/BD1902-TutorialPlPgSql.sql` |
| 20 | `class20/oracle/BD2002-TutorialTriggers.sql` | `class20/postgresql/BD2002-TutorialTriggers.sql` |
| 21 | `class21/oracle/BD2102-TutorialTransacoes.sql` | `class21/postgresql/BD2102-TutorialTransacoes.sql` |
| 22 | `class22/oracle/BD2202-TutorialFlashback.sql` | `class22/postgresql/BD2202-TutorialWal.sql`, `BD2203-LabPitr.sh` |
| 23 | `class23/oracle/BD2302-TutorialCatalogo.sql` | `class23/postgresql/BD2302-TutorialCatalogo.sql` |
| 24 | `class24/oracle/BD2402-CargaBoaSaude.sql`, `BD2403-TutorialIndices.sql` | `class24/postgresql/BD2402-CargaBoaSaude.sql`, `BD2403-TutorialIndices.sql` |
| 25 | `class25/oracle/BD2502-TutorialTuning.sql` (usuario `aula25`) | `class25/postgresql/BD2502-TutorialTuning.sql` |
| 26 | `class26/oracle/BD2602-DockerComposeFull.yml` (imagem com RMAN), `BD2603-TutorialBackupDados.sql` | `class26/postgresql/BD2602-TutorialBackupDados.sql`, `BD2603-RotinaBackup.sh` |
| 27 | `class27/oracle/BD2701-TutorialParticionamento.sql` | `class27/postgresql/BD2702-DockerComposeReplicacao.yml`, `BD2702-init-primario.sh`, `BD2703-TutorialParticionamento.sql` |

O PostgreSQL dos tutoriais e o do ambiente Docker da disciplina (PostgreSQL 17); o Oracle e o XE 21c da Aula 03 (`class03/oracle/BD0301-DockerCompose.yml`). Todos os scripts foram executados de ponta a ponta nessas versoes.

## Como Executar

**SQL (Oracle/PostgreSQL):** os scripts em `oracle/` e `postgresql/` podem ser
executados via `sqlplus`/SQL Developer e `psql`/pgAdmin respectivamente, ou por
containers Docker configurados na aula 03.

**Java:** exemplos usam JDBC puro (sem framework); compile com `javac` e execute com
`java`, ajustando a URL de conexão (`jdbc:oracle:thin:...` ou `jdbc:postgresql://...`)
e as credenciais do seu ambiente.

**Python:** exemplos usam `oracledb` (Oracle) e `psycopg2` (PostgreSQL); instale as
dependências com `pip install oracledb psycopg2-binary` e ajuste as credenciais de
conexão no início de cada script.

**NoSQL (Aula 28 e 28A-28D):** a pasta `class28/` contém, além de `python/` e `java/`:

```
class28/
├── docker/docker-compose.yml   # MongoDB (replica set), Redis, Neo4j e Cassandra
├── python/requirements.txt     # pip install -r requirements.txt
├── javascript/package.json     # npm install (MongoDB e Redis em Node.js)
├── java/pom.xml                # mvn -q dependency:copy-dependencies (Neo4j e Cassandra)
├── mongodb/  redis/  neo4j/  cassandra/   # roteiros de shell (mongosh, redis-cli, Cypher, CQL)
```

| Script | Banco | Problema real |
|---|---|---|
| `BD2803-MongoLojaVirtual.py` / `BD2803-MongoApiLoja.js` | MongoDB | catálogo heterogêneo e checkout transacional |
| `BD2804-RedisBlackFriday.py` / `BD2804-RedisRateLimiterFila.js` | Redis | cache, sessão, rate limit, ranking, fila e lock |
| `BD2805-Neo4jFraudeRecomendacao.py` / `BD2805-Neo4jAntifraude.java` | Neo4j | anéis de fraude e recomendação |
| `BD2806-CassandraColdChain.py` / `BD2806-CassandraTelemetria.java` | Cassandra | telemetria de caminhões refrigerados |

## IA assistida (Aulas 01B e 32)

Modelos do agente de IA usados da Aula 02 à 32 (política na Aula 01B, Slide 32):

| Pasta | Arquivo | Descrição |
|---|---|---|
| `class01B/` | `opencode.json` | Modelo gratuito (`:free`) e permissões do OpenCode: comandos com `ask`, `git push` e `docker compose down -v` negados — a chave de API **não** vai aqui |
| `class01B/` | `AGENTS.md` | Memória do projeto para o agente, curta; cresce a cada unidade (Aula 01B, Slide 33) |
| `class32/` | `AGENTS.md`, `opencode.json` | Versão do projeto integrador (Biblioteca) |
| `class32/` | `USO_DE_IA_modelo.md` | Modelo da seção **Uso de IA** do README da A3, com a tabela de registros (2 pts do critério Organização e documentação) |

## Licença

Material didático de uso exclusivo do curso Banco de Dados (3N - ZS).
