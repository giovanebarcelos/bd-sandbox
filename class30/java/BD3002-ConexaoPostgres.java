/*
 * BD3002-ConexaoPostgres.java
 * Aula 30 - Banco de Dados - UA12 (Conectividade)
 *
 * Demonstra a conexao com PostgreSQL via JDBC (driver "thin", pgJDBC),
 * execucao de uma consulta parametrizada e fechamento correto dos recursos
 * usando try-with-resources. Estrutura identica ao exemplo Oracle
 * (BD3001-ConexaoOracle.java) - apenas a URL/driver mudam, pois ambos
 * implementam as mesmas interfaces java.sql.*.
 *
 * Tabela de apoio usada nos exemplos (criar previamente no banco de teste):
 *
 *   CREATE TABLE funcionarios (
 *       id       SERIAL PRIMARY KEY,
 *       nome     VARCHAR(100) NOT NULL,
 *       cargo    VARCHAR(50)  NOT NULL,
 *       salario  NUMERIC(10,2)
 *   );
 *
 *   INSERT INTO funcionarios (nome, cargo, salario) VALUES ('Ana Souza', 'Veterinario', 6500.00);
 *   INSERT INTO funcionarios (nome, cargo, salario) VALUES ('Bruno Lima', 'Recepcionista', 2800.00);
 *
 * Dependencia Maven:
 *   <dependency>
 *       <groupId>org.postgresql</groupId>
 *       <artifactId>postgresql</artifactId>
 *       <version>42.7.3</version>
 *   </dependency>
 *
 * Compilar/rodar (fora de um projeto Maven, com o .jar do driver no classpath):
 *   javac -cp postgresql.jar BD3002-ConexaoPostgres.java
 *   java  -cp .:postgresql.jar BD3002ConexaoPostgres
 */

import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;

public class BD3002ConexaoPostgres {

    // Ajuste host/porta/banco conforme o ambiente de laboratorio.
    private static final String URL = "jdbc:postgresql://localhost:5432/vetcare";
    private static final String USUARIO = "app_user";
    private static final String SENHA = "senha_segura";

    public static void main(String[] args) {
        // org.postgresql.Driver tambem e descoberto automaticamente pelo DriverManager
        // (JDBC 4.0+), sem necessidade de Class.forName().

        String cargoBuscado = "Veterinario";
        buscarFuncionariosPorCargo(cargoBuscado);
    }

    private static void buscarFuncionariosPorCargo(String cargo) {
        String sql = "SELECT id, nome, cargo, salario FROM funcionarios WHERE cargo = ?";

        try (Connection conexao = DriverManager.getConnection(URL, USUARIO, SENHA);
             PreparedStatement comando = conexao.prepareStatement(sql)) {

            comando.setString(1, cargo);

            try (ResultSet resultado = comando.executeQuery()) {
                System.out.println("Funcionarios com cargo = " + cargo + ":");
                System.out.println("----------------------------------------");

                int total = 0;
                while (resultado.next()) {
                    int id = resultado.getInt("id");
                    String nome = resultado.getString("nome");
                    String cargoBd = resultado.getString("cargo");
                    double salario = resultado.getDouble("salario");

                    System.out.printf("%d | %s | %s | R$ %.2f%n", id, nome, cargoBd, salario);
                    total++;
                }

                if (total == 0) {
                    System.out.println("Nenhum funcionario encontrado para o cargo informado.");
                }
            }

        } catch (SQLException e) {
            System.err.println("Erro ao conectar/consultar o PostgreSQL.");
            System.err.println("SQLState: " + e.getSQLState());
            System.err.println("Mensagem: " + e.getMessage());
        }
    }
}
