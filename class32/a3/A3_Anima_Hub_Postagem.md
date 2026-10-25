# A3 — Texto de Postagem no Anima Hub  

> Material para o **professor**: o que colar e anexar ao criar a atividade A3 no Anima Hub. Não é distribuído aos alunos.  

---  

## Configuração sugerida da atividade  

| Campo | Sugestão |  
|---|---|  
| **Título** | A3 — Projeto Integrador: banco de dados em Oracle e PostgreSQL, com agente de IA |  
| **Valor** | 40 pontos |  
| **Modalidade** | Em grupo (2 a 3 integrantes); uma entrega por grupo |  
| **Tipo de envio** | Arquivo (`.pdf` da capa e `.zip` do repositório) e link (GitHub) |  
| **Tentativas** | 1 envio por grupo (reenvio só antes do prazo) |  
| **Prazo** | Definir a data no Hub (a Aula 32 é a apresentação) |  
| **Anexos do professor** | `A3_Projeto_BD` (enunciado), `A3_Exemplo_DespensaViva` (exemplo de referência) e o zip do repositório de referência: [`a3-despensaviva.zip`](https://raw.githubusercontent.com/giovanebarcelos/bd-sandbox/main/class32/a3/a3-despensaviva.zip) (Oracle + PostgreSQL, aplicações em **Python** e em **Java**, `docker-compose.yml`) |  

> Ajuste ao que o Anima Hub oferecer para a sua turma (nomes de campos, tentativas, grupos). Este roteiro foi escrito sem acesso à configuração da atividade no portal.  

---  

## Descrição (para colar no campo de texto da atividade)  

**A3 — Projeto Integrador (40 pontos)**  

Em grupo, vocês vão escolher um problema com regras de negócio de verdade e construir, do início ao fim, um banco de dados: **DER, DDL, 10 consultas, 2 procedures e um trigger, índices com EXPLAIN antes e depois, e aplicações que o usam (Java e Python)**, tudo **em Oracle e em PostgreSQL**. O trabalho é feito **com o agente de IA da disciplina** (Aula 01B), e o uso é **declarado** e **defendido oralmente** na Aula 32.  

**O tema é livre**, desde que tenha pelo menos 3 regras de negócio com número (só cadastrar e listar não basta) e 6 ou mais entidades. Biblioteca e escola de informática não valem (são casos das aulas). Mostrem o tema ao professor antes de se comprometerem (até a Aula 4).  

**Critérios (40 pts):** DER 6 · DDL Oracle + PostgreSQL 6 · 10 consultas SQL 10 · 2 procedures + 1 trigger 6 · 3 índices + EXPLAIN 4 · Conexão Java + Python 4 · Organização e documentação 4 (2 + 2 do registro de IA).  

**Uso do agente de IA (obrigatório):** configurem o OpenCode conforme a Aula 01B, usem as skills nas etapas indicadas no enunciado e registrem no README, em uma tabela, o que pediram, **o que o agente errou** e o que o grupo corrigiu (mínimo 5 registros e 2 erros reais). **SQL escrito por IA só vale depois de executado nos dois bancos.** Artefato que o grupo não sabe explicar é avaliado como Insuficiente, com ou sem IA.  

**Entrega com Docker Compose (obrigatório):** o repositório traz `docker-compose.yml` na raiz, de modo que `docker compose up -d --wait` suba **o PostgreSQL e o Oracle já com os seus scripts** e `docker compose run --rm testes` rode a verificação automatizada nos dois bancos, numa máquina que só tenha o Docker. **Script que não roda = zero na etapa.** O Oracle XE leva 1 a 2 minutos para subir e usa cerca de 2 GB de memória: avisem o professor **antes** se a máquina não aguenta.  

**Apresentação (Aula 32):** 10 minutos, com demonstração ao vivo nos dois bancos e a pergunta do professor.  

**Material de apoio (em anexo):**  
- Enunciado completo, com rubrica detalhada e checklist  
- Exemplo completo de referência: DespensaViva (use como guia, não copie)  
- Repositório de referência ([`a3-despensaviva`](https://github.com/giovanebarcelos/bd-sandbox/tree/main/class32/a3-despensaviva)): scripts dos dois bancos, 152 testes, teste de mutação, planos de execução reais, aplicações Python e Java e `docker-compose.yml`  

---  

## O que o grupo deve postar  

1. **Capa da entrega (PDF, 1 página):** nome do projeto, integrantes (nome e RA), link do repositório, tag da entrega e hash do commit  
2. **Repositório completo (`.zip`)**, incluindo a pasta `.git` e o `docker-compose.yml`, sem `target` nem `.venv`  
3. **Link do repositório no GitHub** (público, ou com o professor como colaborador), no campo de texto  

**Teste antes de postar:** descompacte o zip em outra pasta e rode `docker compose down -v`, `docker compose up -d --wait` e `docker compose run --rm testes`.  

Mudanças depois do prazo não são consideradas: vale o commit da tag.  

---  

## Mensagem de aviso à turma (opcional)  

> Pessoal, a A3 está publicada no Anima Hub. O tema é livre, mas precisa ter pelo menos 3 regras de negócio com número e 6 entidades: tragam o tema para eu aprovar até a Aula 4. Há um exemplo completo (DespensaViva) com os dois bancos, as procedures, os testes e as aplicações em Python e Java. A entrega precisa subir com `docker compose` (PostgreSQL **e** Oracle), então testem cedo, numa cópia limpa. Atenção a uma pegadinha que o exemplo mostra: o Oracle **não tem** `ON DELETE RESTRICT`. O uso do agente de IA é obrigatório e vale pontos, mas o que vale mesmo é saber explicar o que entregaram. Dúvidas no fórum da atividade.  
