/*
 * BD2806-CassandraTelemetria.java
 * Aula 28D - Banco de Dados - UA11 (NoSQL e Big Data) - Cassandra em Profundidade
 * Prof. Giovane Barcelos
 *
 * Versao Java do gateway de telemetria da ColdChain (par do script Python
 * BD2806-CassandraColdChain.py). Simula o servico que recebe as leituras dos
 * caminhoes e grava no Cassandra:
 *
 *   1. PreparedStatement: o CQL e analisado UMA vez pelo servidor
 *   2. Escrita assincrona (executeAsync + CompletableFuture) com limite de
 *      requisicoes em voo (Semaphore) - padrao de ingestao de alta vazao
 *   3. BATCH LOGGED: grava a leitura e a "ultima leitura" de forma atomica
 *      (tudo ou nada) mesmo em particoes diferentes - com custo extra
 *   4. Leitura com nivel de consistencia por consulta (LOCAL_QUORUM)
 *
 * Pre-requisito: rodar antes o BD2806 em Python (cria o keyspace coldchain) e
 *   docker run -d --name bd28-cassandra -p 9042:9042 cassandra:4.1
 *
 * Dependencia Maven (ver pom.xml desta pasta):
 *   org.apache.cassandra:java-driver-core:4.19.0
 *
 * Compilar/rodar:
 *   mvn -q dependency:copy-dependencies
 *   javac -cp "target/dependency/*" -d target BD2806-CassandraTelemetria.java
 *   java  -cp "target:target/dependency/*" BD2806CassandraTelemetria
 */

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.net.InetSocketAddress;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneOffset;
import java.util.ArrayList;
import java.util.List;
import java.util.Random;
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.Semaphore;
import java.util.concurrent.atomic.AtomicInteger;

import com.datastax.oss.driver.api.core.CqlSession;
import com.datastax.oss.driver.api.core.DefaultConsistencyLevel;
import com.datastax.oss.driver.api.core.cql.BatchStatement;
import com.datastax.oss.driver.api.core.cql.DefaultBatchType;
import com.datastax.oss.driver.api.core.cql.PreparedStatement;
import com.datastax.oss.driver.api.core.cql.Row;
import com.datastax.oss.driver.api.core.cql.SimpleStatement;

class BD2806CassandraTelemetria {

    private static final int EM_VOO_MAX = 128;   // requisicoes simultaneas
    private static final LocalDate DIA = LocalDate.of(2026, 10, 9);

    public static void main(String[] args) throws Exception {
        try (CqlSession sessao = CqlSession.builder()
                .addContactPoint(new InetSocketAddress("127.0.0.1", 9042))
                .withLocalDatacenter("datacenter1")      // obrigatorio no driver 4.x
                .withKeyspace("coldchain")
                .build()) {

            PreparedStatement insLeitura = sessao.prepare("""
                    INSERT INTO leituras_por_sensor_dia
                        (sensor_id, dia, ts, temperatura, umidade, lat, lon)
                    VALUES (?, ?, ?, ?, ?, ?, ?)""");
            PreparedStatement insUltima = sessao.prepare("""
                    INSERT INTO ultima_leitura (sensor_id, caminhao, ts, temperatura)
                    VALUES (?, ?, ?, ?)""");

            // ---------------------------------------------------------------
            // 2. Ingestao assincrona: 10.000 leituras de 5 sensores
            // ---------------------------------------------------------------
            System.out.println("=== Ingestao assincrona ===");
            Random rnd = new Random(2806);
            Semaphore emVoo = new Semaphore(EM_VOO_MAX);
            AtomicInteger erros = new AtomicInteger();
            List<CompletableFuture<?>> futuros = new ArrayList<>();
            Instant inicio = DIA.atStartOfDay().toInstant(ZoneOffset.UTC);
            long t0 = System.nanoTime();
            for (int i = 0; i < 2000; i++) {
                for (int s = 1; s <= 5; s++) {
                    emVoo.acquire();       // backpressure: nunca mais de 128 em voo
                    BigDecimal temp = BigDecimal.valueOf(4 + rnd.nextGaussian())
                            .setScale(2, RoundingMode.HALF_UP);
                    CompletableFuture<?> f = sessao.executeAsync(insLeitura.bind(
                                    "GW-SNS-" + s, DIA, inicio.plusSeconds(10L * i), temp,
                                    BigDecimal.valueOf(50), -30.0 + i * 1e-4, -51.0 + i * 1e-4))
                            .toCompletableFuture()
                            .whenComplete((r, e) -> {
                                if (e != null) erros.incrementAndGet();
                                emVoo.release();
                            });
                    futuros.add(f);
                }
            }
            CompletableFuture.allOf(futuros.toArray(new CompletableFuture[0])).join();
            double seg = (System.nanoTime() - t0) / 1e9;
            System.out.printf("%d escritas em %.2f s (%,.0f/s), erros: %d%n",
                    futuros.size(), seg, futuros.size() / seg, erros.get());

            // ---------------------------------------------------------------
            // 3. BATCH LOGGED: leitura critica + painel, atomicamente
            // ---------------------------------------------------------------
            System.out.println("\n=== BATCH LOGGED (atomicidade entre tabelas) ===");
            Instant agora = inicio.plusSeconds(20_000);
            BigDecimal critica = new BigDecimal("11.30");
            BatchStatement batch = BatchStatement.builder(DefaultBatchType.LOGGED)
                    .addStatement(insLeitura.bind("GW-SNS-1", DIA, agora, critica,
                            BigDecimal.valueOf(55), -30.2, -51.2))
                    .addStatement(insUltima.bind("GW-SNS-1", "CAM-GW-01", agora, critica))
                    .build();
            sessao.execute(batch);
            System.out.println("leitura critica gravada nas 2 tabelas (tudo ou nada)");

            // ---------------------------------------------------------------
            // 4. Leituras com consistencia escolhida por consulta
            // ---------------------------------------------------------------
            System.out.println("\n=== Consultas ===");
            SimpleStatement ultimas = SimpleStatement.builder("""
                            SELECT ts, temperatura FROM leituras_por_sensor_dia
                            WHERE sensor_id = ? AND dia = ? LIMIT 3""")
                    .addPositionalValues("GW-SNS-1", DIA)
                    .setConsistencyLevel(DefaultConsistencyLevel.LOCAL_QUORUM)
                    .build();
            for (Row r : sessao.execute(ultimas)) {
                System.out.printf("GW-SNS-1 %s -> %s C%n",
                        r.getInstant("ts"), r.getBigDecimal("temperatura"));
            }
            Row painel = sessao.execute(SimpleStatement.newInstance(
                    "SELECT caminhao, temperatura FROM ultima_leitura WHERE sensor_id = ?",
                    "GW-SNS-1")).one();
            System.out.printf("Painel: %s esta em %s C%n",
                    painel.getString("caminhao"), painel.getBigDecimal("temperatura"));
            long total = sessao.execute(SimpleStatement.newInstance(
                    "SELECT count(*) FROM leituras_por_sensor_dia WHERE sensor_id = ? AND dia = ?",
                    "GW-SNS-3", DIA)).one().getLong(0);
            System.out.println("Leituras de GW-SNS-3 no dia (count em 1 particao): " + total);
        }
    }
}
