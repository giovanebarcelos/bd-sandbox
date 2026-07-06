// BD0901-UuidV7.java
// Geracao de UUID v7 conforme RFC 9562
// UA3 - Aula 09 - Modelagem Logica/Fisica e Tipos de Chave

import java.security.SecureRandom;
import java.util.UUID;

/**
 * Gerador de UUID v7 conforme RFC 9562.
 *
 * Estrutura (128 bits):
 *   [timestamp Unix ms: 48 bits][version: 4 bits][rand_a: 12 bits]
 *   [variant: 2 bits][rand_b: 62 bits]
 */
public class UuidV7Generator {

    private static final SecureRandom random = new SecureRandom();

    /**
     * Gera um UUID v7.
     */
    public static UUID generateV7() {
        long timestamp = System.currentTimeMillis();

        // 64 bits superiores
        long msb = (timestamp << 16)               // timestamp nos 48 MSBs
                 | 0x7000                           // version = 7 (4 bits)
                 | (random.nextLong() & 0xFFFL);    // rand_a = 12 bits

        // 64 bits inferiores
        long lsb = (random.nextLong() & 0x3FFFFFFFFFFFFFFFL)  // rand_b = 62 bits
                 | 0x8000000000000000L;                       // variant = 10xx

        return new UUID(msb, lsb);
    }

    /**
     * Extrai o timestamp Unix em milissegundos de um UUID v7.
     */
    public static long extractTimestamp(UUID uuid) {
        return uuid.getMostSignificantBits() >>> 16;
    }

    /**
     * Converte UUID para array de bytes (para inserir como RAW(16) no Oracle).
     */
    public static byte[] toByteArray(UUID uuid) {
        long msb = uuid.getMostSignificantBits();
        long lsb = uuid.getLeastSignificantBits();
        byte[] bytes = new byte[16];
        for (int i = 15; i >= 8; i--) {
            bytes[i] = (byte) (lsb & 0xFF);
            lsb >>>= 8;
        }
        for (int i = 7; i >= 0; i--) {
            bytes[i] = (byte) (msb & 0xFF);
            msb >>>= 8;
        }
        return bytes;
    }

    // ============================================================
    // DEMONSTRACAO
    // ============================================================
    public static void main(String[] args) throws InterruptedException {
        System.out.println("=== UUID v7 Generator (RFC 9562) ===\n");

        // Gerar 5 UUIDs v7
        UUID[] ids = new UUID[5];
        for (int i = 0; i < 5; i++) {
            ids[i] = generateV7();
            System.out.printf("UUID v7 [%d]: %s%n", i + 1, ids[i]);

            long ts = extractTimestamp(ids[i]);
            System.out.printf("  Timestamp: %d (%s)%n", ts, new java.util.Date(ts));
        }

        // Verificar ordenacao
        System.out.println("\n--- Verificacao de Ordenacao ---");
        java.util.Arrays.sort(ids, (a, b) -> {
            long ta = extractTimestamp(a);
            long tb = extractTimestamp(b);
            return Long.compare(ta, tb);
        });
        System.out.println("Ordenados por timestamp:");
        for (UUID id : ids) {
            System.out.printf("  %s (ts: %d)%n", id, extractTimestamp(id));
        }

        // Performance: gerar 100.000 UUIDs v7
        System.out.println("\n--- Benchmark: 100.000 UUIDs v7 ---");
        long start = System.nanoTime();
        for (int i = 0; i < 100_000; i++) {
            generateV7();
        }
        long elapsed = System.nanoTime() - start;
        System.out.printf("Tempo total: %.2f ms%n", elapsed / 1_000_000.0);
        System.out.printf("UUIDs/ms: %.1f%n", 100_000.0 / (elapsed / 1_000_000.0));

        // Exemplo de bytes para Oracle RAW(16)
        System.out.println("\n--- Bytes para Oracle RAW(16) ---");
        UUID sample = generateV7();
        byte[] bytes = toByteArray(sample);
        System.out.printf("UUID: %s%n", sample);
        System.out.print("Bytes: ");
        for (byte b : bytes) {
            System.out.printf("%02x ", b);
        }
        System.out.println();
    }
}
