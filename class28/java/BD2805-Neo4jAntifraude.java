/*
 * BD2805-Neo4jAntifraude.java
 * Aula 28C - Banco de Dados - UA11 (NoSQL e Big Data) - Neo4j em Profundidade
 * Prof. Giovane Barcelos
 *
 * Versao Java do servico antifraude da TechStore (par do script Python
 * BD2805-Neo4jFraudeRecomendacao.py). Simula o fluxo de uma aplicacao real:
 * a cada NOVO CADASTRO, antes de aprovar a conta, o servico consulta o grafo
 * e calcula um "score de risco" com base em quantas contas ja existentes
 * compartilham telefone, dispositivo ou endereco com o novo cliente.
 *
 *   score 0      -> APROVADO
 *   score 1..2   -> REVISAO MANUAL
 *   score >= 3   -> BLOQUEADO
 *
 * Pre-requisito: rodar antes o BD2805 em Python (popula o grafo) e
 *   docker run -d --name bd28-neo4j -p 7474:7474 -p 7687:7687 \
 *       -e NEO4J_AUTH=neo4j/bd28senha123 neo4j:5
 *
 * Dependencia Maven (ver pom.xml desta pasta):
 *   org.neo4j.driver:neo4j-java-driver:5.28.5
 *
 * Compilar/rodar:
 *   mvn -q dependency:copy-dependencies          (baixa os .jar em target/dependency)
 *   javac -cp "target/dependency/*" -d target BD2805-Neo4jAntifraude.java
 *   java  -cp "target:target/dependency/*" BD2805Neo4jAntifraude
 */

import java.util.List;
import java.util.Map;

import org.neo4j.driver.AuthTokens;
import org.neo4j.driver.Config;
import org.neo4j.driver.Driver;
import org.neo4j.driver.GraphDatabase;
import org.neo4j.driver.NotificationConfig;
import org.neo4j.driver.Record;
import org.neo4j.driver.Session;
import org.neo4j.driver.SessionConfig;
import org.neo4j.driver.exceptions.Neo4jException;

class BD2805Neo4jAntifraude {

    private static final String URI = "neo4j://localhost:7687";
    private static final String USUARIO = "neo4j";
    private static final String SENHA = "bd28senha123";

    /** Novo cadastro recebido pela API (Java 16+ record). */
    record NovoCadastro(String id, String nome, String telefone, String dispositivo, String cep) {}

    /** Resultado da analise de risco. */
    record Analise(String decisao, long score, List<String> contasRelacionadas) {}

    private final Driver driver;

    BD2805Neo4jAntifraude(Driver driver) {
        this.driver = driver;
    }

    /**
     * Passo 1 - LEITURA: quantas contas ja usam algum identificador do novo
     * cadastro, e quantas dessas ja estao bloqueadas (peso dobrado).
     * Parametros ($tel, $disp...) evitam injecao de Cypher e permitem que o
     * Neo4j reaproveite o plano de execucao em cache.
     */
    Analise analisar(NovoCadastro c) {
        try (Session sessao = driver.session(SessionConfig.forDatabase("neo4j"))) {
            return sessao.executeRead(tx -> {
                Record r = tx.run("""
                        OPTIONAL MATCH (outro:Cliente)-->(id)
                        WHERE (id:Telefone AND id.numero = $tel)
                           OR (id:Dispositivo AND id.id = $disp)
                           OR (id:Endereco AND id.cep = $cep)
                        WITH collect(DISTINCT outro) AS contas
                        RETURN [x IN contas | x.nome] AS nomes,
                               size(contas) + size([x IN contas WHERE x.bloqueado]) AS score
                        """,
                        Map.of("tel", c.telefone(), "disp", c.dispositivo(), "cep", c.cep()))
                        .single();
                long score = r.get("score").asLong();
                List<String> nomes = r.get("nomes").asList(v -> v.asString());
                String decisao = score == 0 ? "APROVADO" : score <= 2 ? "REVISAO MANUAL" : "BLOQUEADO";
                return new Analise(decisao, score, nomes);
            });
        }
    }

    /**
     * Passo 2 - ESCRITA: grava o cliente e suas ligacoes no grafo, ja com a
     * decisao. executeWrite repete a transacao automaticamente em caso de
     * erro transitorio (ex.: deadlock, troca de lider no cluster).
     */
    void registrar(NovoCadastro c, Analise a) {
        try (Session sessao = driver.session(SessionConfig.forDatabase("neo4j"))) {
            sessao.executeWrite(tx -> tx.run("""
                    MERGE (cl:Cliente {id: $id})
                      SET cl.nome = $nome, cl.bloqueado = $bloq, cl.status = $status
                    MERGE (t:Telefone {numero: $tel})
                    MERGE (d:Dispositivo {id: $disp})
                    MERGE (e:Endereco {cep: $cep})
                    MERGE (cl)-[:USA_TELEFONE]->(t)
                    MERGE (cl)-[:USA_DISPOSITIVO]->(d)
                    MERGE (cl)-[:ENTREGA_EM]->(e)
                    """,
                    Map.of("id", c.id(), "nome", c.nome(), "tel", c.telefone(),
                           "disp", c.dispositivo(), "cep", c.cep(),
                           "bloq", a.decisao().equals("BLOQUEADO"), "status", a.decisao()))
                    .consume());
        }
    }

    /** Relatorio final: contas por status, usando agregacao em Cypher. */
    void relatorio() {
        List<Record> linhas = driver.executableQuery("""
                MATCH (c:Cliente) WHERE c.status IS NOT NULL
                RETURN c.status AS status, collect(c.nome) AS clientes ORDER BY status
                """).execute().records();
        for (Record r : linhas) {
            System.out.printf("  %-15s %s%n", r.get("status").asString(), r.get("clientes").asList());
        }
    }

    public static void main(String[] args) {
        Config config = Config.builder()
                .withNotificationConfig(NotificationConfig.disableAllConfig())
                .build();
        try (Driver driver = GraphDatabase.driver(URI, AuthTokens.basic(USUARIO, SENHA), config)) {
            driver.verifyConnectivity();
            BD2805Neo4jAntifraude servico = new BD2805Neo4jAntifraude(driver);

            List<NovoCadastro> fila = List.of(
                    new NovoCadastro("c30", "Paula Nunes", "51-99555-1234", "dev-NEW1", "90420-000"),
                    new NovoCadastro("c31", "Ana R. Souza", "51-99001-0001", "dev-NEW2", "90010-000"),
                    new NovoCadastro("c32", "Joao S. Junior", "11-98888-7777", "dev-QQQ", "01310-100"));

            System.out.println("=== Analise de risco de novos cadastros ===");
            for (NovoCadastro c : fila) {
                Analise a = servico.analisar(c);
                servico.registrar(c, a);
                System.out.printf("%-15s score=%d -> %-15s relacionados=%s%n",
                        c.nome(), a.score(), a.decisao(), a.contasRelacionadas());
            }
            System.out.println("\n=== Contas analisadas por status ===");
            servico.relatorio();
        } catch (Neo4jException e) {
            System.err.println("Erro Neo4j: " + e.code() + " - " + e.getMessage());
        }
    }
}
