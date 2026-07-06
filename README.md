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
- **Linguagens de aplicação:** Java 17+ (JDBC), Python 3.11+ (`oracledb`, `psycopg2`)
- **Diagramas:** PlantUML — visualizar em https://plantuml.com/
- **Infraestrutura:** Docker / Docker Compose

## Sumário por Aula

| Aula | UA | Tema | Diagramas | Oracle | PostgreSQL | Java | Python |
|---|---|---|---|---|---|---|---|
| 01 | UA1 | O que é um SBD | ✓ | — | — | — | — |
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
| 22 | UA8 | Recuperação de falhas | ✓ | — | — | — | — |
| 23 | UA9 | Catálogo do banco de dados | — | ✓ | ✓ | — | — |
| 24 | UA9 | Índices e planos de execução | — | ✓ | ✓ | — | — |
| 25 | UA9 | Otimização e tuning | — | ✓ | ✓ | — | — |
| 26 | UA10 | Backup e recuperação | — | ✓ | ✓ | — | — |
| 27 | UA10 | Distribuição, replicação e sharding | ✓ | — | — | — | — |
| 28 | UA11 | NoSQL: documento/chave-valor/coluna/grafo | — | — | — | — | ✓ |
| 29 | UA11 | Big Data e CAP theorem | ✓ | — | — | — | — |
| 30 | UA12 | Conexões: JDBC e DB-API | — | ✓ | ✓ | ✓ | ✓ |
| 31 | UA12 | Segurança: usuários, roles e grants | — | ✓ | ✓ | — | — |
| 32 | UA12 | Projeto integrador final | — | ✓ | ✓ | ✓ | ✓ |

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

## Licença

Material didático de uso exclusivo do curso Banco de Dados (3N - ZS).
