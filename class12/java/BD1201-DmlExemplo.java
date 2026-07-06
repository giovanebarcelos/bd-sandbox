/*
 * BD1201-DmlExemplo.java
 * Aula 12 - DML via JDBC: INSERT / UPDATE / DELETE / upsert (Oracle e PostgreSQL)
 * Estudo de caso: BookHub - livraria online
 * Prof. Giovane Barcelos
 *
 * Este exemplo mostra como executar as mesmas operacoes DML do BD1201-DML.sql
 * a partir de uma aplicacao Java, usando JDBC com PreparedStatement. O metodo
 * main() troca de banco apenas alterando a URL/driver de conexao — o restante
 * do codigo (SQL parametrizado) e praticamente identico para Oracle e Postgres,
 * exceto pelo comando de upsert (MERGE x INSERT ... ON CONFLICT).
 *
 * Dependencias (Maven):
 *   Oracle:      com.oracle.database.jdbc:ojdbc11
 *   PostgreSQL:  org.postgresql:postgresql
 */

import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.time.LocalDate;

public class BD1201DmlExemplo {

    // Ajuste a URL/usuario/senha conforme o ambiente local
    private static final String ORACLE_URL  = "jdbc:oracle:thin:@localhost:1521/XEPDB1";
    private static final String POSTGRES_URL = "jdbc:postgresql://localhost:5432/bookhub";
    private static final String USER = "bookhub_user";
    private static final String PASSWORD = "bookhub_pass";

    public static void main(String[] args) throws SQLException {
        System.out.println("=== Executando DML no Oracle ===");
        executarDemonstracao(ORACLE_URL, "oracle");

        System.out.println("\n=== Executando DML no PostgreSQL ===");
        executarDemonstracao(POSTGRES_URL, "postgresql");
    }

    private static void executarDemonstracao(String url, String dialeto) throws SQLException {
        try (Connection conn = DriverManager.getConnection(url, USER, PASSWORD)) {
            conn.setAutoCommit(false);

            int novoClienteId = inserirCliente(conn,
                    "Diego Ponteiro", "diego.ponteiro@email.com", "+55-31-95555-4444", LocalDate.now());
            System.out.println("Cliente inserido com id: " + novoClienteId);

            int linhasAtualizadas = reajustarPrecoLivrosFisicos(conn, 0.10);
            System.out.println("Livros fisicos reajustados: " + linhasAtualizadas);

            int linhasRemovidas = removerLivrosAntigos(conn, 1990);
            System.out.println("Livros antigos removidos: " + linhasRemovidas);

            if ("oracle".equals(dialeto)) {
                upsertEstoqueOracle(conn, 3, 25);
            } else {
                upsertEstoquePostgres(conn, 3, 25);
            }

            conn.commit();
            System.out.println("Transacao confirmada (COMMIT) em " + dialeto);
        } catch (SQLException e) {
            System.err.println("Erro na demonstracao DML (" + dialeto + "): " + e.getMessage());
        }
    }

    /** INSERT parametrizado — identico em Oracle e PostgreSQL. */
    private static int inserirCliente(Connection conn, String nome, String email,
                                       String telefone, LocalDate dataCadastro) throws SQLException {
        String sql = "INSERT INTO Cliente (nome, email, telefone, data_cadastro) VALUES (?, ?, ?, ?)";
        try (PreparedStatement stmt = conn.prepareStatement(sql, PreparedStatement.RETURN_GENERATED_KEYS)) {
            stmt.setString(1, nome);
            stmt.setString(2, email);
            stmt.setString(3, telefone);
            stmt.setObject(4, dataCadastro);
            stmt.executeUpdate();
            try (ResultSet rs = stmt.getGeneratedKeys()) {
                return rs.next() ? rs.getInt(1) : -1;
            }
        }
    }

    /** UPDATE parametrizado — identico em Oracle e PostgreSQL. */
    private static int reajustarPrecoLivrosFisicos(Connection conn, double percentual) throws SQLException {
        String sql = "UPDATE Livro SET preco = ROUND(preco * (1 + ?), 2) WHERE tipo = 'F'";
        try (PreparedStatement stmt = conn.prepareStatement(sql)) {
            stmt.setDouble(1, percentual);
            return stmt.executeUpdate();
        }
    }

    /** DELETE parametrizado — identico em Oracle e PostgreSQL. */
    private static int removerLivrosAntigos(Connection conn, int anoLimite) throws SQLException {
        String sql = "DELETE FROM Livro WHERE ano_publicacao < ?";
        try (PreparedStatement stmt = conn.prepareStatement(sql)) {
            stmt.setInt(1, anoLimite);
            return stmt.executeUpdate();
        }
    }

    /** Upsert usando MERGE (sintaxe Oracle). */
    private static void upsertEstoqueOracle(Connection conn, int livroId, int quantidade) throws SQLException {
        String sql = "MERGE INTO Estoque tgt " +
                "USING (SELECT ? AS livro_id, ? AS quantidade_nova FROM dual) src " +
                "ON (tgt.livro_id = src.livro_id) " +
                "WHEN MATCHED THEN UPDATE SET tgt.quantidade_disponivel = src.quantidade_nova, " +
                "                             tgt.ultima_atualizacao = SYSDATE " +
                "WHEN NOT MATCHED THEN INSERT (livro_id, quantidade_disponivel, ultima_atualizacao) " +
                "                      VALUES (src.livro_id, src.quantidade_nova, SYSDATE)";
        try (PreparedStatement stmt = conn.prepareStatement(sql)) {
            stmt.setInt(1, livroId);
            stmt.setInt(2, quantidade);
            stmt.executeUpdate();
        }
    }

    /** Upsert usando INSERT ... ON CONFLICT (sintaxe PostgreSQL). */
    private static void upsertEstoquePostgres(Connection conn, int livroId, int quantidade) throws SQLException {
        String sql = "INSERT INTO Estoque (livro_id, quantidade_disponivel, ultima_atualizacao) " +
                "VALUES (?, ?, CURRENT_DATE) " +
                "ON CONFLICT (livro_id) DO UPDATE " +
                "SET quantidade_disponivel = EXCLUDED.quantidade_disponivel, " +
                "    ultima_atualizacao = EXCLUDED.ultima_atualizacao";
        try (PreparedStatement stmt = conn.prepareStatement(sql)) {
            stmt.setInt(1, livroId);
            stmt.setInt(2, quantidade);
            stmt.executeUpdate();
        }
    }
}
