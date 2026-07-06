// BD3201-BibliotecaApp.java
// Java: Conexao JDBC com procedures da Biblioteca
// UA12 - Aula 32 - Projeto Integrador Final

import java.sql.*;
import java.util.Scanner;

public class BibliotecaApp {

    private static final String URL = "jdbc:postgresql://localhost:5432/biblioteca";
    private static final String USER = "postgres";
    private static final String PASSWORD = "postgres";

    public static void main(String[] args) {
        try (Connection conn = DriverManager.getConnection(URL, USER, PASSWORD)) {
            System.out.println("Conectado ao PostgreSQL - Sistema de Biblioteca\n");

            // Inserir dados de exemplo
            inserirDadosExemplo(conn);

            // Chamar procedure realizar_emprestimo
            realizarEmprestimo(conn, 1, 1);  // usuario_id=1, livro_id=1

            // Chamar procedure devolver_livro
            devolverLivro(conn, 1);  // emprestimo_id=1

            // Consultar emprestimos
            listarEmprestimos(conn);

            System.out.println("\nOperacoes concluidas com sucesso!");
        } catch (SQLException e) {
            System.err.println("Erro de banco de dados: " + e.getMessage());
            e.printStackTrace();
        }
    }

    private static void realizarEmprestimo(Connection conn, int usuarioId, int livroId)
            throws SQLException {
        String sql = "{ call realizar_emprestimo(?, ?) }";
        try (CallableStatement cstmt = conn.prepareCall(sql)) {
            cstmt.setInt(1, usuarioId);
            cstmt.setInt(2, livroId);
            cstmt.execute();
            System.out.println("Emprestimo registrado: usuario=" + usuarioId
                             + ", livro=" + livroId);
        }
    }

    private static void devolverLivro(Connection conn, int emprestimoId)
            throws SQLException {
        String sql = "{ call devolver_livro(?) }";
        try (CallableStatement cstmt = conn.prepareCall(sql)) {
            cstmt.setInt(1, emprestimoId);
            cstmt.execute();
            System.out.println("Livro devolvido: emprestimo_id=" + emprestimoId);
        }
    }

    private static void listarEmprestimos(Connection conn) throws SQLException {
        String sql = """
            SELECT e.emprestimo_id, u.nome AS usuario, l.titulo AS livro,
                   e.data_retirada, e.data_prevista, e.data_devolucao,
                   e.multa
              FROM emprestimo e
              JOIN usuario u ON u.usuario_id = e.usuario_id
              JOIN livro l ON l.livro_id = e.livro_id
             ORDER BY e.data_retirada DESC
             LIMIT 10
            """;
        try (Statement stmt = conn.createStatement();
             ResultSet rs = stmt.executeQuery(sql)) {
            System.out.println("\n--- Ultimos emprestimos ---");
            while (rs.next()) {
                System.out.printf("#%d | %s | %s | Retirada: %s | Multa: R$ %.2f%n",
                    rs.getInt("emprestimo_id"),
                    rs.getString("usuario"),
                    rs.getString("livro"),
                    rs.getDate("data_retirada"),
                    rs.getDouble("multa"));
            }
        }
    }

    private static void inserirDadosExemplo(Connection conn) throws SQLException {
        try (Statement stmt = conn.createStatement()) {
            stmt.executeUpdate(
                "INSERT INTO editora (nome) VALUES ('Editora Tech'), ('Editora Ciencia') "
                + "ON CONFLICT DO NOTHING");
            stmt.executeUpdate(
                "INSERT INTO livro (isbn, titulo, editora_id, ano) VALUES "
                + "('978-85-365-0001-0', 'Banco de Dados: Fundamentos', 1, 2024), "
                + "('978-85-365-0002-7', 'SQL Avancado', 1, 2025) "
                + "ON CONFLICT DO NOTHING");
            stmt.executeUpdate(
                "INSERT INTO usuario (matricula, nome, email, tipo) VALUES "
                + "('2026001', 'Aluno Teste', 'aluno@email.com', 'ALUNO') "
                + "ON CONFLICT DO NOTHING");
        }
    }
}
