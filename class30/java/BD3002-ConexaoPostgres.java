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
 * Ambiente da disciplina (A1/DBTools/Docker): o script
 * class30/postgresql/BD3003-TutorialVetcare.sql cria o banco vetcare, a tabela
 * e o role app_user.
 *
 * Credenciais por variavel de ambiente (nunca no codigo que vai para o Git):
 *   PG_URL      (padrao jdbc:postgresql://localhost:5432/vetcare)
 *   PG_USER     (padrao app_user)
 *   PG_PASSWORD (padrao senha_segura - senha do laboratorio)
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
 *       <version>42.7.8</version>
 *   </dependency>
 *
 * Rodar (Java 11+ executa o .java direto; o pom.xml desta pasta baixa o driver):
 *   mvn -q dependency:copy-dependencies
 *   java -cp "target/dependency/*" BD3002-ConexaoPostgres.java
 * Ou compilar (no Windows troque ":" por ";" no classpath):
 *   javac -cp postgresql.jar BD3002-ConexaoPostgres.java
 *   java  -cp .:postgresql.jar BD3002ConexaoPostgres
 */

import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.util.Properties;

public class BD3002ConexaoPostgres {

    private static final String URL = env("PG_URL", "jdbc:postgresql://localhost:5432/vetcare");
    private static final String USUARIO = env("PG_USER", "app_user");
    private static final String SENHA = env("PG_PASSWORD", "senha_segura");

    private static String env(String nome, String padrao) {
        String valor = System.getenv(nome);
        return valor == null ? padrao : valor;
    }

    public static void main(String[] args) {
        // org.postgresql.Driver tambem e descoberto automaticamente pelo DriverManager
        // (JDBC 4.0+), sem necessidade de Class.forName().

        String cargoBuscado = "Veterinario";
        buscarFuncionariosPorCargo(cargoBuscado);
    }

    private static void buscarFuncionariosPorCargo(String cargo) {
        String sql = "SELECT id, nome, cargo, salario FROM funcionarios WHERE cargo = ?";

        Properties propriedades = new Properties();
        propriedades.setProperty("user", USUARIO);
        propriedades.setProperty("password", SENHA);
        // nome que aparece em pg_stat_activity.application_name
        propriedades.setProperty("ApplicationName", "BD3002-java");
        // timeout de conexao (s): sem ele, um host inacessivel trava o programa
        propriedades.setProperty("connectTimeout", "5");

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
            System.err.println("Erro ao conectar/consultar o PostgreSQL.");
            System.err.println("SQLState: " + e.getSQLState());
            System.err.println("Mensagem: " + e.getMessage());
        }
    }
}
