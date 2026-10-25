package br.edu.despensa;

import java.math.BigDecimal;
import java.sql.CallableStatement;
import java.sql.Connection;
import java.sql.Date;
import java.sql.DriverManager;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Savepoint;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;

/**
 * DespensaViva — aplicação Java que usa os dois bancos por JDBC (PostgreSQL e Oracle).
 *
 * Mostra o essencial: conectar, consultar com PreparedStatement (bind), chamar procedure com CallableStatement,
 * tratar o erro de negócio (DESPENSA-00x) e controlar a transação. Por padrão tudo é DESFEITO no final;
 * com o argumento {@code --efetivar} as alterações são gravadas. Termina com código 1 se algo não bater com o esperado.
 */
public final class DespensaApp {
    private static final int TOMATE = 3;
    private static final int FORNECEDOR = 2;

    private final Connection con;
    private final String dialeto;
    private final List<String> saida = new ArrayList<>();

    DespensaApp(Connection con, String dialeto) {
        this.con = con;
        this.dialeto = dialeto;
    }

    /** Erro de negócio devolvido pelas procedures e triggers (mensagem começa em DESPENSA-00x). */
    static final class ErroDeNegocio extends Exception {
        ErroDeNegocio(String mensagem) { super(mensagem); }
    }

    private void dizer(String texto) {
        saida.add(texto);
        System.out.println("[" + dialeto + "] " + texto);
    }

    private static ErroDeNegocio traduz(SQLException e) {
        String m = e.getMessage() == null ? "" : e.getMessage();
        int i = m.indexOf("DESPENSA-");
        return i >= 0 ? new ErroDeNegocio(m.substring(i).split("\n")[0].trim()) : null;
    }

    /**
     * Chama uma procedure dentro de um SAVEPOINT. No PostgreSQL um erro "aborta" a transação inteira; o savepoint
     * faz o erro desfazer só esta chamada, igual ao Oracle, e a transação continua.
     */
    private void chama(String sql, Object... args) throws ErroDeNegocio, SQLException {
        Savepoint sp = con.setSavepoint();
        try (CallableStatement cs = con.prepareCall(sql)) {
            for (int i = 0; i < args.length; i++) {
                switch (args[i]) {
                    case Integer v -> cs.setInt(i + 1, v);
                    case BigDecimal v -> cs.setBigDecimal(i + 1, v);
                    case String v -> cs.setString(i + 1, v);
                    case Date v -> cs.setDate(i + 1, v);
                    default -> throw new IllegalArgumentException("tipo não previsto: " + args[i]);
                }
            }
            cs.execute();
        } catch (SQLException e) {
            con.rollback(sp);
            ErroDeNegocio negocio = traduz(e);
            if (negocio != null) {
                throw negocio;
            }
            throw e;
        }
    }

    void consumir(int insumo, BigDecimal quantidade, String motivo) throws ErroDeNegocio, SQLException {
        chama("{ call consumir_insumo(?, ?, ?) }", insumo, quantidade, motivo);
    }

    void registrarEntrada(int insumo, int fornecedor, BigDecimal quantidade, LocalDate validade) throws ErroDeNegocio, SQLException {
        chama("{ call registrar_entrada_lote(?, ?, ?, ?) }", insumo, fornecedor, quantidade, Date.valueOf(validade));
    }

    /** Saldo de lotes não vencidos. Sempre bind (?), nunca concatenação: evita SQL injection. */
    BigDecimal saldo(int insumo) throws SQLException {
        String hoje = dialeto.equals("postgresql") ? "CURRENT_DATE" : "TRUNC(SYSDATE)";
        try (PreparedStatement ps = con.prepareStatement(
                "SELECT COALESCE(SUM(quantidade_atual), 0) FROM lote WHERE insumo_id = ? AND data_validade >= " + hoje)) {
            ps.setInt(1, insumo);
            try (ResultSet rs = ps.executeQuery()) {
                rs.next();
                return rs.getBigDecimal(1);
            }
        }
    }

    /** Roteiro único, igual nos dois bancos; devolve true se tudo bateu com o esperado. */
    boolean demonstracao(boolean efetivar) throws SQLException {
        boolean ok = true;
        BigDecimal antes = saldo(TOMATE);
        dizer("saldo de tomate antes: " + antes.stripTrailingZeros().toPlainString() + " kg");
        try {
            consumir(TOMATE, new BigDecimal("6"), "Sopa do almoço");
            BigDecimal depois = saldo(TOMATE);
            dizer("depois de consumir 6 kg (FEFO): saldo " + depois.stripTrailingZeros().toPlainString() + " kg");
            ok &= depois.compareTo(antes.subtract(new BigDecimal("6"))) == 0;
        } catch (ErroDeNegocio e) {
            dizer("consumo recusado inesperadamente: " + e.getMessage());
            ok = false;
        }
        try {
            consumir(TOMATE, new BigDecimal("100"), "Pedido grande");
            dizer("ERRO: o pedido de 100 kg deveria ter sido recusado");
            ok = false;
        } catch (ErroDeNegocio e) {
            dizer("pedido de 100 kg recusado: " + e.getMessage());
            ok &= e.getMessage().startsWith("DESPENSA-003");
        }
        try {
            registrarEntrada(TOMATE, FORNECEDOR, new BigDecimal("5"), LocalDate.now().plusDays(2));
            dizer("ERRO: a entrada com validade em 2 dias deveria ter sido recusada");
            ok = false;
        } catch (ErroDeNegocio e) {
            dizer("entrada com validade em 2 dias recusada: " + e.getMessage());
            ok &= e.getMessage().startsWith("DESPENSA-002");
        }
        try {
            registrarEntrada(TOMATE, FORNECEDOR, new BigDecimal("5"), LocalDate.now().plusDays(3));
            dizer("entrada com validade em 3 dias aceita: saldo " + saldo(TOMATE).stripTrailingZeros().toPlainString() + " kg");
        } catch (ErroDeNegocio e) {
            dizer("entrada recusada inesperadamente: " + e.getMessage());
            ok = false;
        }
        if (efetivar) {
            con.commit();
            dizer("alterações GRAVADAS (commit)");
        } else {
            con.rollback();
            dizer("modo demonstração: tudo DESFEITO (rollback); saldo volta a " + saldo(TOMATE).stripTrailingZeros().toPlainString() + " kg");
            ok &= saldo(TOMATE).compareTo(antes) == 0;
        }
        return ok;
    }

    private static String env(String chave, String padrao) {
        String v = System.getenv(chave);
        return v == null || v.isBlank() ? padrao : v;
    }

    public static void main(String[] args) throws Exception {
        boolean efetivar = List.of(args).contains("--efetivar");
        String pg = env("PG_URL", "jdbc:postgresql://localhost:5432/despensa?escapeSyntaxCallMode=callIfNoReturn");
        String ora = env("ORACLE_URL", "jdbc:oracle:thin:@//localhost:1521/XEPDB1");
        boolean ok = true;
        try (Connection con = DriverManager.getConnection(pg, env("PG_USER", "despensa"), env("PG_PASSWORD", "despensa_pwd"))) {
            con.setAutoCommit(false);
            ok &= new DespensaApp(con, "postgresql").demonstracao(efetivar);
        }
        try (Connection con = DriverManager.getConnection(ora, env("ORACLE_USER", "despensa"), env("ORACLE_PASSWORD", "despensa_pwd"))) {
            con.setAutoCommit(false);
            ok &= new DespensaApp(con, "oracle").demonstracao(efetivar);
        }
        System.out.println(ok ? "OK: tudo conforme o esperado nos dois bancos" : "FALHA: algum passo não bateu com o esperado");
        System.exit(ok ? 0 : 1);
    }
}
