# A3 — Projeto Integrador de Banco de Dados  

**Unidade Curricular:** Banco de Dados  
**Cursos:** C&TIC, Engenharias e Administração  
**Período:** 2026/2  
**Valor:** 40 pontos  
**Apresentação:** Aula 32 (10 min por grupo, mais as perguntas do professor)  
**Grupos:** duplas ou trios (individual só com autorização do professor)  
**Exemplo de referência:** [A3 — Projeto Exemplo: DespensaViva](A3_Exemplo_DespensaViva.md) (o exemplo usa PostgreSQL **e** Oracle, com aplicações em Python **e** em Java; vocês escolhem **um** SGBD e **uma** linguagem)  
**SGBD:** Oracle **ou** PostgreSQL (escolha do grupo)  
**Linguagem da aplicação:** Java ou Python, ou outra que o grupo achar melhor (veja "Escolha do SGBD e da linguagem")  

---  

## Visão Geral e Critérios de Avaliação  

A A3 é o trabalho integrador final da disciplina. Em grupo, vocês escolhem um problema com regras de negócio, **modelam, implementam, consultam, programam, otimizam e conectam** um banco de dados, aplicando as 12 unidades de aprendizagem. A solução roda em **um dos dois SGBDs do curso, Oracle ou PostgreSQL, à escolha do grupo**, com uma aplicação em **Java, Python ou outra linguagem** escolhida pelo grupo. O trabalho é feito **com um agente de IA** (obrigatório, seção "Uso do Agente de IA") e defendido oralmente: quem construiu sabe explicar.  

A nota total é de **40 pontos**:  

| Critério | Pontos | O que é avaliado |  
|---|---|---|  
| **1. DER** | 6 pts | Entidades, atributos, PKs, FKs e cardinalidades (mín., máx.) corretas; decisões de modelagem justificadas |  
| **2. DDL (Oracle ou PostgreSQL)** | 6 pts | Scripts que **rodam do zero** no SGBD escolhido, constraints nomeadas, tipos e `ON DELETE` corretos para o dialeto |  
| **3. 10 consultas SQL** | 10 pts | No mínimo 2 com JOIN, 2 com window function e 2 com agregação, no dialeto do SGBD escolhido, com resultado conferido |  
| **4. 2 procedures + 1 trigger** | 6 pts | Sintaxe correta (PL/SQL no Oracle ou PL/pgSQL no PostgreSQL), regras de negócio implementadas, tratamento de erros |  
| **5. 3 índices + EXPLAIN** | 4 pts | Índices nas FKs; plano **antes e depois** documentado, com tempos medidos |  
| **6. Conexão pela aplicação** | 4 pts | Aplicação em Java, Python ou outra linguagem: código funcional, conexão estabelecida, chamada de procedure, erro de negócio tratado |  
| **7. Organização e documentação** | 4 pts | Estrutura de diretórios, README completo, prints/tabelas (2 pts) + **registro de Uso de IA** (2 pts) |  
| **TOTAL** | **40 pts** | |  

> **O critério que atravessa todos: script que não roda = zero na etapa.** Vocês entregam um `docker-compose.yml` em que o banco escolhido já sobe com o esquema, os dados, as procedures e os índices, de modo que **quem avalia não instala nada além do Docker**.  
>  
> **Dica:** um modelo **pequeno, completo, testado e bem explicado** vale mais que um modelo grande e meio funcionando. Regra de negócio **dentro do banco, com teste**, é o que mais se destaca.  

---  

## Tema do Projeto  

O tema é **aberto**. O grupo escolhe um domínio com **regras de negócio de verdade**, em que a lógica no banco (procedure, trigger, constraint) faça diferença.  

### Critérios para um tema válido  

| Critério | O que verificar |  
|---|---|  
| **Problema identificável** | Existe alguém com um problema real e descritível (não "um banco de X" sem dono) |  
| **Regras de negócio com número** | Pelo menos **3 regras não triviais**, com valores-limite (prazos, faixas, limites, estados). Só cadastrar e listar **não** basta: não há o que programar no banco |  
| **Rende modelagem** | Pelo menos **6 entidades**, um relacionamento **N:M** resolvido por entidade associativa e uma entidade que carregue estado (lote, pedido, matrícula) |  
| **Rende procedure e trigger** | Pelo menos uma operação que muda **várias tabelas de uma vez** (por exemplo, "consumir e registrar a movimentação") e uma regra que valha mesmo para quem insere direto na tabela |  
| **Escopo viável** | Cabe em 26 horas de trabalho (Slide 25 da Aula 32) |  
| **Originalidade** | Não vale o domínio dos exemplos do curso: **biblioteca** (Aula 32), **escola de informática** (Aula 06) nem o do exemplo de referência (**estoque de cozinha comunitária com validade**) |  

### Exemplos de temas  

- Academia: planos, descontos por fidelidade e inadimplência  
- Oficina mecânica: ordens de serviço, estoque de peças e garantia de 90 dias  
- Hotel: diárias, ocupação e política de cancelamento  
- Estacionamento: tarifa por faixa de tempo, tolerância e mensalistas  
- Transportadora: frete por faixa de peso e distância, com regras de gratuidade  
- Vacinação: intervalo mínimo entre doses e validade do lote  
- Torneio: pontuação, critérios de desempate e classificação  
- Loja de aluguel de equipamentos: multa por atraso e limite por perfil  

> **Teste rápido do tema:** consigam, em 2 minutos, listar 3 regras com um número ("a segunda dose só depois de 28 dias"). Se não conseguirem, o tema é só um cadastro. Mostrem o tema ao professor **antes** de se comprometerem (veja o checkpoint 1).  

---  

## Escolha do SGBD e da linguagem  

O grupo escolhe **um SGBD** e **uma linguagem** e informa a escolha no checkpoint 1, junto com o tema.  

| Escolha | Opções | Observações |  
|---|---|---|  
| **SGBD** | **Oracle** (XE 21, imagem `gvenzl/oracle-xe:21-slim`) **ou** **PostgreSQL** (17, imagem `postgres:17`) | DDL, consultas, procedures, trigger, índices e testes são feitos **no SGBD escolhido**. O Oracle XE pede cerca de 2 GB de memória e 1 a 2 minutos na primeira subida; se a máquina for modesta, prefiram o PostgreSQL |  
| **Linguagem** | **Java** (JDBC) ou **Python** (`psycopg` ou `python-oracledb`), que são as vistas na Aula 30, **ou outra que o grupo achar melhor** (C#, JavaScript/TypeScript, Go, PHP, Kotlin...) | A linguagem precisa ter driver para o SGBD escolhido, permitir **consulta com bind**, **chamada de procedure** e **controle de transação**, e rodar pelo `docker-compose.yml` |  

- Quem escolher uma linguagem **fora** de Java e Python justifica a escolha no README (por que ela, qual driver) e assume o suporte: o material das aulas e o exemplo de referência cobrem só Java e Python  
- Entregar nos **dois** SGBDs ou em **duas** linguagens é permitido, mas **não vale ponto extra**: a avaliação é sobre a qualidade, não a quantidade. Melhor um SGBD bem feito que dois pela metade  
- **Trocar** de SGBD ou de linguagem depois do checkpoint 3 (DDL rodando) só com aviso ao professor  

---  

## Metodologia e Roteiro ao Longo do Curso  

A A3 **não é feita na última semana**. Cada unidade produz um pedaço da entrega, e os slides 🤖 das aulas mostram como usar o agente em cada etapa.  

| Quando | Artefato da A3 | Aulas | Checkpoint com o professor |  
|---|---|---|---|  
| Aulas 1-4 | Tema, regras de negócio com número, entidades candidatas; **escolha do SGBD e da linguagem** | Fundamentos, arquitetura de um SGBD, ferramentas, entidades e atributos | **1.** Aprovação do tema (3 regras), SGBD e linguagem |  
| Aulas 5-6 | DER completo (cardinalidades), em PlantUML | Cardinalidade, especialização, estudo de caso | **2.** DER revisado (Aula 6) |  
| Aulas 7-9 | Modelo lógico e físico; tipos; chaves | Mapeamento, tipos de dados, UUID v7 | — |  
| Aulas 10-11 | **DDL no SGBD escolhido**, subindo do zero no `docker-compose.yml` | CREATE/ALTER/DROP, views, particionamento | **3.** DDL rodando no SGBD escolhido (Aula 11) |  
| Aulas 12-15 | Dados de exemplo e as **10 consultas** | DML, DQL, JOINs, subqueries, window functions | **4.** 5 consultas com resultado conferido (Aula 15) |  
| Aulas 16-17 | Normalização justificada; integridade referencial e `ON DELETE` | Formas normais, integridade | — |  
| Aulas 18-20 | **Procedures e triggers** em PL/SQL (Oracle) ou PL/pgSQL (PostgreSQL) | PL/SQL, PL/pgSQL, triggers | **5.** Procedures e trigger testados (Aula 20) |  
| Aulas 21-23 | Transações, concorrência; catálogo do banco | ACID, recuperação, catálogo | Teste com duas sessões |  
| Aulas 24-25 | **Índices e EXPLAIN antes/depois** | Índices, planos de execução, tuning | **6.** Tempos medidos (Aula 25) |  
| Aulas 26-29 | Backup, distribuição e NoSQL (conteúdo de apoio; opcional na A3) | Backup, replicação, NoSQL, Big Data | — |  
| Aulas 30-31 | **Aplicação** (Java, Python ou a linguagem escolhida); usuários, papéis e permissões | JDBC, DB-API, segurança | Aplicação rodando no compose |  
| Aula 32 | README, registro de IA, checklist e apresentação | Projeto final | Revisão final com o checklist |  

---  

## O Projeto  

A A3 é entregue como um **repositório Git único**, com os conjuntos de artefatos abaixo. Para cada um, a seção "No material" indica onde a técnica foi ensinada.  

### 1. DER  

**6 pontos | Local: `der/<tema>.puml` (e a imagem no README)**  

- **Pelo menos 6 entidades**, com **atributos, PK, UK e FK** em cada uma  
- **Cardinalidades (mín., máx.)** em todos os relacionamentos, em notação **Crow's Foot**  
- Pelo menos **um N:M resolvido** por entidade associativa (que pode carregar atributos)  
- **Decisões de modelagem justificadas** no README (por que PK artificial? por que esta entidade e não um atributo?)  
- Diagrama em **PlantUML** (versionado) ou Power Architect  

> **No material:** Aulas 04, 05 e 06 (entidades, cardinalidade, estudo de caso) e Aulas 07 a 09 (mapeamento lógico, físico, chaves).  

### 2. DDL: Oracle ou PostgreSQL  

**6 pontos | Local: `oracle/01_ddl.sql` ou `postgresql/01_ddl.sql` (a pasta do SGBD escolhido)**  

- Um script que **cria tudo do zero** (sem depender de nada feito à mão)  
- **Constraints nomeadas** (`pk_`, `uk_`, `fk_`, `ck_`), `CHECK` onde a regra é de domínio e `NOT NULL` onde cabe  
- **`ON DELETE` explícito em toda FK** (ou, no Oracle, a omissão justificada em comentário). Atenção: o Oracle **não tem `RESTRICT`**; omitir a cláusula já bloqueia  
- **Tipos do dialeto escolhido:** `VARCHAR2`/`NUMBER` no Oracle, `VARCHAR`/`NUMERIC` no PostgreSQL; `GENERATED BY DEFAULT AS IDENTITY` serve nos dois  
- **Dados de exemplo** (`02_inserts.sql`) com datas **relativas a hoje**, para as consultas darem o mesmo resultado em qualquer dia  

> **No material:** Aulas 08, 10, 11 e 17.  

### 3. Dez consultas SQL  

**10 pontos | Local: `oracle/03_consultas.sql` ou `postgresql/03_consultas.sql`**  

- **10 consultas analíticas**, cada uma com o objetivo em um comentário  
- **No mínimo:** 2 com **JOIN**, 2 com **window function** (`RANK`, `ROW_NUMBER`, `SUM() OVER`) e 2 com **agregação** (`GROUP BY`/`HAVING`)  
- Pelo menos uma com **anti-join** (`NOT EXISTS`), e vale mostrar `ROLLUP`, subconsulta correlacionada ou divisão relacional  
- **O resultado precisa ser conferido por um teste**, com o valor esperado calculado à mão a partir dos dados (não "parece certo")  
- Dados com **fronteiras** (empate no ranking, valor exatamente no limite, item que vence hoje): consulta sem dado de fronteira não prova nada  

> **No material:** Aulas 12, 13, 14 e 15.  

### 4. Procedures e triggers  

**6 pontos | Local: `procedures/oracle_procedures.sql` ou `procedures/postgresql_procedures.sql`**  

- **2 procedures** que implementam regra de negócio, **cada uma alterando mais de uma tabela**  
- **1 trigger** (o exemplo de referência tem dois: validação e auditoria); ao menos um deles garante uma regra mesmo para quem insere direto na tabela  
- **Tratamento de erro** com mensagens de negócio e **código estável** (`RAISE EXCEPTION` no PostgreSQL, `RAISE_APPLICATION_ERROR` no Oracle)  
- **Sem `COMMIT` dentro da procedure:** quem chama decide a transação  
- Comentário em cada procedure e trigger dizendo **qual regra** ela implementa  
- **Concorrência:** a procedure se comporta quando **duas sessões** a chamam ao mesmo tempo? (o exemplo de referência teve um defeito real aqui)  

> **No material:** Aulas 18, 19, 20 e 21.  

### 5. Índices e plano de execução  

**4 pontos | Local: `*/04_indices.sql` e `performance/explain_antes_depois.txt`**  

- **3 índices:** um em cada FK usada em JOIN e um de busca. **Nem o PostgreSQL nem o Oracle indexam a FK sozinhos**  
- **Plano antes e depois** (`EXPLAIN ANALYZE` no PostgreSQL; `EXPLAIN PLAN` + `DBMS_XPLAN`, ou `GATHER_PLAN_STATISTICS` + `DISPLAY_CURSOR`, no Oracle), colados como **texto**, com os **tempos medidos** por vocês  
- Massa de dados suficiente para o índice fazer diferença (dezenas de milhares de linhas, num esquema à parte)  
- **Nunca** afirmem "melhorou" sem o plano: o agente inventa números  

> **No material:** Aulas 23, 24 e 25.  

### 6. Conexão pela aplicação  

**4 pontos | Local: `app/` (ou `java/`, `python/`, conforme a linguagem)**  

- **Uma aplicação** na linguagem escolhida: **Java** (JDBC), **Python** (`psycopg` para PostgreSQL, `python-oracledb` para Oracle) ou outra (C# com Npgsql/ODP.NET, Node.js com `pg`/`oracledb`, Go, PHP com PDO...)  
- Ela deve: conectar, **consultar com bind** (nunca concatenando valores), **chamar uma procedure** e **tratar o erro de negócio** que o banco devolve  
- Transação controlada pela aplicação (`commit`/`rollback`)  
- **Roda pelo compose** (por exemplo, `docker compose --profile apps run --rm app`), sem instalar a linguagem na máquina de quem avalia  
- Armadilhas conhecidas: parâmetro `NUMERIC` no PostgreSQL deve ir como `Decimal` (Python) ou `BigDecimal` (Java), não `float`/`double`; no PostgreSQL um erro aborta a transação (use `SAVEPOINT`)  

> **No material:** Aula 30 (JDBC e DB-API) e Aula 31 (segurança). Para outra linguagem, os conceitos são os mesmos (driver, bind, chamada de procedure, transação); a sintaxe fica por conta do grupo.  

### 7. Organização e documentação  

**4 pontos | Local: `README.md` e a árvore do repositório**  

| Item | Pontos | O que entregar |  
|---|---|---|  
| **README e organização** | 2 | Resumo do domínio; DER; decisões de design; instruções de execução; resultados de performance (tabela antes/depois); dificuldades e aprendizados; estrutura de diretórios conforme a Aula 32 |  
| **Uso de IA** | 2 | Seção do README com o registro descrito na seção "Uso do Agente de IA" |  

> **No material:** Aula 32 (Slides 20, 21 e 27) e Aula 01B (política de IA).  

### Docker Compose (obrigatório)  

`docker-compose.yml` **na raiz**, com o banco escolhido (imagem com a versão fixada: `postgres:17` ou `gvenzl/oracle-xe:21-slim`), que sobe **já com os seus scripts executados**, e a aplicação. Quem avalia roda, sem instalar nada além do Docker:  

```bash  
docker compose up -d --wait        # banco pronto, com esquema, dados, procedures e índices  
docker compose run --rm testes     # a verificação automatizada  
```  

- **Verificação automatizada mínima:** 10 testes no banco escolhido: constraints barrando dado inválido, uma procedure no caminho feliz e **nos dois erros de negócio**, um trigger, e pelo menos 2 consultas com resultado esperado. O exemplo de referência tem 152 (76 cenários × 2 bancos). Os testes podem ser escritos na linguagem da aplicação ou em SQL  
- **Script que falha na carga aborta a subida** (`set -e`, `ON_ERROR_STOP`, `WHENEVER SQLERROR EXIT`): erro silencioso é a pior opção  
- **Nenhuma senha real, chave ou `.env` no repositório.** As do laboratório ficam no `docker-compose.yml` e **dizem que são de laboratório**  
- Quem escolher o Oracle: o **XE leva 1 a 2 minutos** na primeira subida e usa cerca de 2 GB de memória (veja as perguntas frequentes)  

> O repositório de referência implementa **os dois** SGBDs e **as duas** linguagens para servir de modelo a qualquer escolha. Usem a parte que corresponde à de vocês.  

🔗 [Repositório de referência (a3-despensaviva)](https://github.com/giovanebarcelos/bd-sandbox/tree/main/class32/a3-despensaviva)  
🔗 [Zip — com histórico Git e tag v1.0.0](https://raw.githubusercontent.com/giovanebarcelos/bd-sandbox/main/class32/a3/a3-despensaviva.zip)  

---  

## Uso do Agente de IA (obrigatório)  

A A3 **exige** o uso do agente de IA da disciplina e a **declaração** do que foi feito com ele. A razão: quem trabalha com dados hoje usa agentes, e o que se ensina aqui é **usar, conferir e corrigir**, não aceitar.  

### O que usar  

O setup é o da **Aula 01B** (IA Assistida: Skills, OpenCode e OpenRouter): OpenCode aberto **na raiz do repositório do projeto**, modelo gratuito via OpenRouter, skills em `.agents/skills/`, `opencode.json` com `push` negado e `ask` para comandos (Slide 31) e `AGENTS.md` mantido atualizado (Slide 33). Quem usa o Claude Code segue o Slide 29. A política completa é o **Slide 32 da Aula 01B**.  

### Onde o agente entra: mapa por etapa  

Cada aula de 02 a 32 tem um slide **🤖 Com o Agente**. Para a A3, estes são os pontos de entrada:  

| Etapa da A3 | Use o agente para | Material |  
|---|---|---|  
| 1. Modelagem (DER) | `grilling` sobre o enunciado; crítica do DER com o checklist (agente `plan`) | Aulas 04, 05 e 06 (🤖) |  
| 2. DDL | Rascunho no dialeto do SGBD escolhido (diga qual no `AGENTS.md`); revisão de constraints, `ON DELETE` e tipos | Aulas 08, 10, 11 e 17 (🤖) |  
| 3. DML e 10 consultas | Rascunho das consultas; revisão de JOIN, window function e dialeto | Aulas 12, 13, 14 e 15 (🤖) |  
| 4. Procedures e trigger | Rascunho em PL/SQL ou PL/pgSQL; revisão de tratamento de erro e **concorrência** | Aulas 18, 19, 20 e 21 (🤖) |  
| 5. Índices e EXPLAIN | Interpretar o plano **que você colou**; nunca inventar tempos | Aulas 24 e 25 (🤖) |  
| 6. Conexão pela aplicação | Bind, pool e tratamento de erro; revisão de segurança | Aula 30 (🤖) |  
| 7. Documentação | Conferir o README contra os blocos e o checklist | Aula 32 (🤖) |  

### Regras do jogo  

1. **Primeiro à mão, depois o agente** nas atividades de aula. **Na A3 o agente é parte do método**, mas a decisão e o entendimento são seus  
2. **SQL escrito pelo agente só vale depois de executado no SGBD escolhido.** O agente mistura dialetos: `VARCHAR` e `SERIAL` no Oracle, `ON DELETE RESTRICT` no Oracle, `MERGE`/`NVL`/`DUAL` no PostgreSQL. Registrem no `AGENTS.md` qual é o SGBD e a linguagem do projeto  
3. **O agente escreve o script; quem executa é o grupo**, no laboratório com Docker. Nunca `DROP`, `TRUNCATE` ou `DELETE`/`UPDATE` sem `WHERE` por sugestão do agente, e nunca contra um banco que não seja o do laboratório  
4. **Dados:** nenhum dado pessoal real (CPF, e-mail, telefone), credencial ou dado de cliente nos prompts nem nos dados de teste (LGPD, Aula 31)  
5. **O agente propõe, a equipe publica:** `git push` é de vocês (negado no `opencode.json`); senha de banco e chave de API fora do Git  
6. **A responsabilidade é do grupo:** "foi a IA" não é justificativa para erro, falha ou plágio. **A1 e A2 continuam sem agente** (Aula 01B, Slide 32)  

### O registro de uso (seção "Uso de IA" do README)  

O README tem uma seção **Uso de IA** com:  

- **Ferramenta e modelo** (ex.: OpenCode + Nemotron 3 Ultra `:free` via OpenRouter) e **skills** utilizadas  
- Uma **tabela de registros**, no mínimo **5 linhas**, cobrindo **pelo menos 4 tipos de artefato diferentes** (DER, DDL, consultas, procedure/trigger, índices/EXPLAIN, aplicação, README):  

| # | Artefato | Pedido (resumo) | O que o agente errou ou omitiu | O que o grupo fez |  
|---|---|---|---|---|  

- Em **pelo menos 2 linhas**, a coluna "o que o agente errou ou omitiu" deve ter um **erro real** encontrado e corrigido. Não encontrar nenhum erro ao longo do projeto inteiro é sinal de que a revisão não foi feita  
- Uma **reflexão curta**: onde a IA mais ajudou, onde mais errou, o que o grupo faria diferente  
- O `AGENTS.md` e o `opencode.json` **versionados** no repositório  

> **Pontuação do registro (2 pontos de Organização e documentação):** 2 pts = tabela completa, erros reais documentados e `AGENTS.md` coerente com o repositório; 1 pt = tabela presente, mas genérica ("a IA ajudou muito"), sem erros reais; 0 = seção ausente. O registro mede **transparência e senso crítico**, não a quantidade de uso.  

Modelos prontos: [`AGENTS.md`](https://github.com/giovanebarcelos/bd-sandbox/blob/main/class32/AGENTS.md) e [`USO_DE_IA_modelo.md`](https://github.com/giovanebarcelos/bd-sandbox/blob/main/class32/USO_DE_IA_modelo.md).  

### Defesa oral  

Na apresentação, o professor escolhe um trecho de qualquer artefato (uma constraint, uma consulta, uma procedure, um plano de execução) e pede ao grupo que o explique. **Artefato que o grupo não sabe explicar é avaliado como Insuficiente naquele critério, feito com ou sem IA** (Aula 01B, Slide 32). Usar IA e não declarar, sabendo explicar tudo, não reduz a nota do critério; não saber explicar, sim.  

---  

## Rubrica de Avaliação (40 pontos)  

**Níveis de desempenho aplicados ao peso de cada critério:**  

- **Excelente (90-100% do peso):** todos os itens presentes, completos, **executáveis no SGBD escolhido** e coerentes entre si  
- **Bom (60-89% do peso):** itens presentes, com lacunas pontuais  
- **Insuficiente (< 60% do peso):** item ausente, que não roda, incompleto ou incoerente, ou que o grupo não sabe explicar  

| Critério | Pts | Excelente | Insuficiente |  
|---|---:|---|---|  
| **DER** | 6 | 6+ entidades, atributos, PK/UK/FK, cardinalidades (mín., máx.), N:M resolvido e decisões justificadas | Cardinalidade ausente ou errada; N:M sem entidade associativa; sem justificativa |  
| **DDL (Oracle ou PostgreSQL)** | 6 | Roda do zero pelo compose; constraints nomeadas; `ON DELETE` explícito e correto no dialeto | Script que não roda; tipos ou sintaxe do outro dialeto (`SERIAL`, `VARCHAR` ou `ON DELETE RESTRICT` no Oracle; `VARCHAR2`/`NUMBER` no PostgreSQL); constraints sem nome |  
| **10 consultas** | 10 | 10 consultas com JOIN, window e agregação, resultado conferido por teste e dados de fronteira | Menos de 10; resultado nunca conferido; sem window function |  
| **Procedures + trigger** | 6 | 2 procedures e 1 trigger, com regra de negócio, erro tratado, sem `COMMIT`, e testados (inclusive o erro) | Procedure que só insere; sem tratamento de erro; nunca executada |  
| **Índices + EXPLAIN** | 4 | 3 índices; plano antes/depois como texto, com tempos medidos | "Melhorou" sem plano; tempos inventados; índice criado e nunca medido |  
| **Conexão pela aplicação** | 4 | Aplicação (Java, Python ou outra) roda pelo compose, com bind, procedure chamada, transação e erro de negócio tratado | Não roda; SQL por concatenação; não chama procedure; não trata o erro |  
| **Organização e docs** | 2 | README com os 7 blocos, estrutura da Aula 32, tabelas e prints | Falta "como rodar"; estrutura solta |  
| **Uso de IA** | 2 | Tabela completa (≥ 5 registros, ≥ 4 tipos), erros reais, reflexão, `AGENTS.md` coerente | Seção ausente ou genérica |  

---  

## Apresentação (Aula 32)  

**10 minutos por grupo.** Todos falam. Não é leitura de slides: é a **demonstração** do banco funcionando e a defesa das decisões.  

| Parte | Tempo | Conteúdo |  
|---|---|---|  
| **O problema e o DER** | 2 min | O domínio, as regras com número e o DER (uma decisão de modelagem justificada) |  
| **Do zero ao banco pronto** | 2 min | `docker compose up -d --wait` e `docker compose run --rm testes` |  
| **Uma regra de negócio ao vivo** | 3 min | Chamar a procedure no caminho feliz **e** no erro, também pela aplicação; mostrar o que o trigger registrou |  
| **Índice e plano** | 1 min | O plano antes e depois, com o tempo, e o que mudou no plano |  
| **Lições e IA** | 2 min | O que o agente errou, o que o grupo corrigiu e por que escolheram esse SGBD e essa linguagem |  
| **Pergunta do professor** | — | Explicar um trecho escolhido de um artefato |  

> **Preparem a demonstração para falhar com graça:** banco já iniciado (o Oracle demora), comandos já testados, uma gravação de reserva e as portas livres.  

---  

## Como Entregar no Anima Hub  

A entrega é **uma por grupo**, postada por **um integrante** na atividade "A3" do Anima Hub, dentro do prazo definido na própria atividade. Postem **todos** os itens abaixo:  

| # | O que postar | Formato |  
|---|---|---|  
| 1 | **Capa da entrega:** nome do projeto, integrantes (nome e RA), link do repositório, **tag da entrega** e o **hash do commit** | PDF de 1 página |  
| 2 | **Repositório completo**, incluindo a pasta `.git` (o histórico é avaliado) | `.zip` (sem `target`, `.venv` nem dados dos bancos) |  
| 3 | **Link do repositório no GitHub** (público, ou com o professor convidado como colaborador), no campo de texto da atividade | Link |  

**Antes de postar, confiram:**  

- [ ] O `zip` abre e o `README` ensina a rodar com Docker  
- [ ] Numa **cópia limpa** (zip descompactado em outra pasta, `docker compose down -v` antes), `docker compose up -d --wait` sobe o banco e `docker compose run --rm testes` passa  
- [ ] Os scripts rodam do zero, sem erro (o exemplo aborta a subida no primeiro erro)  
- [ ] O EXPLAIN do README é **texto colado** de uma execução de vocês  
- [ ] A tag da entrega aponta para o commit que está no zip  
- [ ] Nenhuma senha real, chave de API ou `.env` no repositório  
- [ ] Todos os integrantes têm commits no histórico  

> Mudanças **depois** da data de entrega não são consideradas: o commit da tag vale.  

---  

## Checklist Completo da A3  

Mesmo checklist da Aula 32 (Slides 21 a 24), com os itens do enunciado:  

- [ ] `README.md` com os 7 blocos: domínio, DER, decisões de design, como rodar, performance, dificuldades, **Uso de IA**  
- [ ] SGBD (Oracle ou PostgreSQL) e linguagem declarados no README e no `AGENTS.md` (outra linguagem que não Java/Python: justificada)  
- [ ] DER em PlantUML (versionado), 6+ entidades, cardinalidades (mín., máx.) e N:M resolvido  
- [ ] `01_ddl.sql` e `02_inserts.sql` rodando do zero; constraints nomeadas e `ON DELETE` explícito  
- [ ] 10 consultas (2+ JOIN, 2+ window, 2+ agregação), com resultado conferido  
- [ ] 2 procedures e 1 trigger, com tratamento de erro e sem `COMMIT`  
- [ ] 3 índices e `explain_antes_depois.txt` com os planos e os tempos reais  
- [ ] Aplicação (Java, Python ou outra): bind, procedure, erro de negócio, transação  
- [ ] `docker-compose.yml` na raiz: `up -d --wait` e `run --rm testes` funcionam numa cópia limpa  
- [ ] Verificação automatizada (10+ testes)  
- [ ] Commits ao longo das semanas, de todos, em Conventional Commits; `.gitignore`; tag da entrega  
- [ ] `AGENTS.md` e `opencode.json` versionados e coerentes com o repositório  
- [ ] Seção **Uso de IA** (ferramenta, modelo, skills, ≥ 5 registros, ≥ 2 erros reais, reflexão)  
- [ ] Todo SQL escrito pelo agente foi **executado no banco**  
- [ ] Todos os integrantes sabem explicar qualquer artefato  

---  

## Estrutura de Diretórios Esperada  

```  
meu-projeto/  
├── README.md                     # com a seção "Uso de IA"  
├── AGENTS.md                     # memória do projeto para o agente  
├── opencode.json                 # modelo e permissões do agente  
├── docker-compose.yml            # o banco escolhido (+ testes e aplicação)  
├── der/  
│   └── meu-tema.puml             # DER em PlantUML  
├── postgresql/                   # ou oracle/, conforme o SGBD escolhido  
│   ├── 01_ddl.sql                # Criação das tabelas  
│   ├── 02_inserts.sql            # Dados de exemplo  
│   ├── 03_consultas.sql          # 10 consultas analíticas  
│   └── 04_indices.sql  
├── procedures/  
│   └── postgresql_procedures.sql # 2 procedures + trigger (PL/pgSQL), ou oracle_procedures.sql (PL/SQL)  
├── performance/  
│   └── explain_antes_depois.txt  # planos e tempos antes e depois dos índices  
├── app/                          # aplicação: Java (JDBC), Python ou a linguagem escolhida  
├── tests/                        # verificação automatizada  
└── docker/                       # scripts de inicialização do banco  
```  

A estrutura é uma sugestão (a da Aula 32, mais `docker-compose.yml` e `tests/`); adaptem ao projeto. O repositório de referência ([`a3-despensaviva`](https://github.com/giovanebarcelos/bd-sandbox/tree/main/class32/a3-despensaviva)) segue esta organização, com as pastas dos dois SGBDs e das duas linguagens (`java/` e `python/`).  

---  

## Perguntas Frequentes  

**Oracle ou PostgreSQL: qual escolher?**  
Os dois valem a mesma nota. O PostgreSQL é mais leve e sobe em segundos; o Oracle é muito usado em empresas e tem algumas pegadinhas a mais (sem `ON DELETE RESTRICT`, `VARCHAR2`, PL/SQL). Escolham o que o grupo quer dominar.  

**Posso entregar nos dois SGBDs?**  
Pode, mas não vale ponto extra, e o que estiver no repositório também é avaliado (inclusive na pergunta do professor). Um SGBD bem feito vale mais que dois pela metade.  

**Posso usar MySQL, SQL Server ou outro SGBD?**  
Não nesta A3: o SGBD é Oracle **ou** PostgreSQL, os dois do curso. Se o seu caso for diferente, falem com o professor **antes**.  

**Posso usar outra linguagem além de Java e Python?**  
Pode: C#, JavaScript/TypeScript, Go, PHP, Kotlin ou outra que o grupo achar melhor, desde que tenha driver para o SGBD escolhido, faça bind, chame procedure, controle a transação e rode pelo compose. Justifiquem a escolha no README. O material e o exemplo cobrem Java e Python; para outra linguagem, a adaptação é do grupo.  

**Meu computador não aguenta o Oracle XE (2 GB de memória, 1 a 2 min de subida).**  
Escolham o PostgreSQL. Se o grupo quer mesmo o Oracle, avisem **com antecedência**: as alternativas são rodar no laboratório ou num servidor indicado pelo professor, mas o `docker-compose.yml` continua sendo a forma oficial de entrega.  

**Preciso saber Docker a fundo?**  
Não. Um compose com 2 a 4 serviços e um script de inicialização por banco bastam; o repositório de referência tem um que funciona e pode servir de base. O que se avalia é que **outra pessoa rode o projeto sem configurar nada**.  

**Por que as procedures não fazem `COMMIT`?**  
Para quem chama poder desfazer tudo (os testes e a demonstração usam `ROLLBACK`) e para uma chamada composta valer por inteiro ou nada.  

**Posso usar um modelo de IA diferente do da Aula 01B?**  
Pode, desde que declarado no README (ferramenta, modelo e versão) e respeitadas as regras de dados e de chave de API.  

**A IA escreveu a maior parte do SQL. Isso é um problema?**  
Não por si só, **se vocês entendem, executaram no banco e sabem defender**. O problema é um trecho que o grupo não consegue explicar: a pergunta do professor vai a um trecho escolhido dele, e a resposta define o nível do critério.  

**E se o agente errar e eu não notar?**  
O erro é de vocês; é por isso que o registro de uso pede erros reais encontrados. Executar do zero, testar o erro e rodar um teste de mutação (ou ao menos quebrar o SQL de propósito) são as defesas.  

**Quantas linhas de SQL o projeto precisa ter?**  
Não há mínimo. O exemplo de referência tem cerca de 250 linhas de SQL por banco, mais 120 de procedures (e ele implementa os dois bancos).    

---  

## Ferramentas Recomendadas  

| Categoria | Ferramenta | Acesso |  
|---|---|---|  
| Agente de IA | OpenCode + OpenRouter (modelo `:free`) | Gratuito (Aula 01B) |  
| Agente alternativo | Claude Code | Conforme sua conta (Aula 01B, Slide 29) |  
| Bancos de dados | PostgreSQL 17 **ou** Oracle XE 21 (imagem `gvenzl/oracle-xe`) | Gratuito |  
| Contêineres | Docker e Docker Compose | Gratuito (Docker Engine, ou Docker Desktop conforme a licença) |  
| Clientes SQL | DBeaver, SQL Developer, `psql`, `sqlplus` | Gratuito |  
| Modelagem | PlantUML, Mermaid, Power Architect | Gratuito |  
| Aplicação | Python 3.12 (`psycopg`, `python-oracledb`), Java 21 (JDBC, Maven) ou outra linguagem à escolha do grupo | Gratuito |  
| Testes | pytest, JUnit ou o framework da linguagem escolhida (ou testes em SQL) | Gratuito |  
| Versionamento | Git + GitHub | Gratuito |  

---  

## Referências  

- DATE, C. J. *Introdução a sistemas de bancos de dados*. 8. ed. Elsevier, 2004.  
- ELMASRI, Ramez; NAVATHE, Shamkant B. *Sistemas de banco de dados*. 7. ed. Pearson, 2018.  
- SILBERSCHATZ, Abraham; KORTH, Henry F.; SUDARSHAN, S. *Sistema de banco de dados*. 6. ed. Elsevier, 2012.  
- PostgreSQL Documentation, versão 17: postgresql.org/docs.  
- Oracle Database SQL Language Reference e PL/SQL Language Reference, versão 21c: docs.oracle.com.  
- Conventional Commits 1.0.0. conventionalcommits.org.  
- Material da disciplina: Aulas 1-32, Aula 01B (IA assistida) e o exemplo de referência *DespensaViva*.  
