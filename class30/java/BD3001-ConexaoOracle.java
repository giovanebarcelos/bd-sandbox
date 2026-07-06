/*
 * BD3001-ConexaoOracle.java
 * Aula 30 - Banco de Dados - UA12 (Conectividade)
 *
 * Demonstra a conexao com Oracle Database via JDBC (driver "thin", Tipo 4),
 * execucao de uma consulta parametrizada e fechamento correto dos recursos
 * usando try-with-resources.
 *
 * Tabela de apoio usada nos exemplos (criar previamente no schema de teste):
 *
 *   CREATE TABLE funcionarios (
 *       id       NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 *       nome     VARCHAR2(100) NOT NULL,
 *       cargo    VARCHAR2(50)  NOT NULL,
 *       salario  NUMBER(10,2)
 *   );
 *
 *   INSERT INTO funcionarios (nome, cargo, salario) VALUES ('Ana Souza', 'Veterinario', 6500.00);
 *   INSERT INTO funcionarios (nome, cargo, salario) VALUES ('Bruno Lima', 'Recepcionista', 2800.00);
 *   COMMIT;
 *
 * Dependencia Maven:
 *   <dependency>
 *       <groupId>com.oracle.database.jdbc</groupId>
 *       <artifactId>ojdbc11</artifactId>
 *       <version>23.4.0.24.05</version>
 *   </dependency>
 *
 * Compilar/rodar (fora de um projeto Maven, com o .jar do driver no classpath):
 *   javac -cp ojdbc11.jar BD3001-ConexaoOracle.java
 *   java  -cp .:ojdbc11.jar BD3001ConexaoOracle
 */

import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;

public class BD3001ConexaoOracle {

    // Ajuste host/porta/service name conforme o ambiente de laboratorio.
    private static final String URL = "jdbc:oracle:thin:@localhost:1521/XEPDB1";
    private static final String USUARIO = "app_user";
    private static final String SENHA = "senha_segura";

    public static void main(String[] args) {
        // Desde JDBC 4.0 (Java 6+) o registro do driver via Class.forName() e opcional:
        // o DriverManager descobre "oracle.jdbc.OracleDriver" automaticamente via
        // Service Provider Interface (META-INF/services/java.sql.Driver dentro do jar).
        // A linha abaixo e mantida comentada apenas por clareza/compatibilidade legada:
        // Class.forName("oracle.jdbc.OracleDriver");

        String cargoBuscado = "Veterinario";
        buscarFuncionariosPorCargo(cargoBuscado);
    }

    private static void buscarFuncionariosPorCargo(String cargo) {
        String sql = "SELECT id, nome, cargo, salario FROM funcionarios WHERE cargo = ?";

        // try-with-resources: Connection, PreparedStatement e ResultSet sao fechados
        // automaticamente ao final do bloco, mesmo se ocorrer excecao.
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
            // SQLException e sempre "checked" em JDBC - erros de conexao, SQL invalido,
            // violacao de constraint etc. chegam por aqui.
            System.err.println("Erro ao conectar/consultar o Oracle Database.");
            System.err.println("SQLState: " + e.getSQLState() + " | Codigo: " + e.getErrorCode());
            System.err.println("Mensagem: " + e.getMessage());
        }
    }
}
