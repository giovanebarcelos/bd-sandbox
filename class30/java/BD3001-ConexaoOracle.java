/*
 * BD3001-ConexaoOracle.java
 * Aula 30 - Banco de Dados - UA12 (Conectividade)
 *
 * Demonstra a conexao com Oracle Database via JDBC (driver "thin", Tipo 4),
 * execucao de uma consulta parametrizada e fechamento correto dos recursos
 * usando try-with-resources.
 *
 * Ambiente da disciplina (A1/DBTools/Docker, profile "oracle"): o script
 * class30/oracle/BD3003-TutorialVetcare.sql cria a tabela e o usuario app_user.
 *
 * Credenciais por variavel de ambiente (nunca no codigo que vai para o Git):
 *   ORACLE_URL      (padrao jdbc:oracle:thin:@//localhost:1521/FREEPDB1)
 *   ORACLE_USER     (padrao app_user)
 *   ORACLE_PASSWORD (padrao senha_segura - senha do laboratorio)
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
 *       <version>23.26.0.0.0</version>
 *   </dependency>
 *
 * Rodar (Java 11+ executa o .java direto; o pom.xml desta pasta baixa o driver):
 *   mvn -q dependency:copy-dependencies
 *   java -cp "target/dependency/*" BD3001-ConexaoOracle.java
 * Ou compilar (no Windows troque ":" por ";" no classpath):
 *   javac -cp ojdbc11.jar BD3001-ConexaoOracle.java
 *   java  -cp .:ojdbc11.jar BD3001ConexaoOracle
 */

import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.util.Properties;

public class BD3001ConexaoOracle {

    // Service name FREEPDB1 (Oracle Free do DBTools). Formato: @//host:porta/service
    private static final String URL = env("ORACLE_URL", "jdbc:oracle:thin:@//localhost:1521/FREEPDB1");
    private static final String USUARIO = env("ORACLE_USER", "app_user");
    private static final String SENHA = env("ORACLE_PASSWORD", "senha_segura");

    private static String env(String nome, String padrao) {
        String valor = System.getenv(nome);
        return valor == null ? padrao : valor;
    }

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
        Properties propriedades = new Properties();
        propriedades.setProperty("user", USUARIO);
        propriedades.setProperty("password", SENHA);
        // nome que aparece na coluna PROGRAM de V$SESSION (facilita achar a sessao)
        propriedades.setProperty("v$session.program", "BD3001-java");
        // timeout de conexao (ms): sem ele, um host inacessivel trava o programa
        propriedades.setProperty("oracle.net.CONNECT_TIMEOUT", "5000");

        try (Connection conexao = DriverManager.getConnection(URL, propriedades);
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
