#!/usr/bin/env python3
# BD0901-UuidV7.py
# Geracao de UUID v7 conforme RFC 9562
# UA3 - Aula 09 - Modelagem Logica/Fisica e Tipos de Chave

import uuid
import time
import os


def uuid_v7() -> uuid.UUID:
    """Gera um UUID v7 conforme RFC 9562.

    Estrutura (128 bits):
      [timestamp Unix ms: 48 bits][version: 4 bits][rand_a: 12 bits]
      [variant: 2 bits][rand_b: 62 bits]
    """
    timestamp_ms = int(time.time() * 1000) & ((1 << 48) - 1)

    # 12 bits aleatorios para rand_a
    rand_a = int.from_bytes(os.urandom(2), 'big') & 0x0FFF

    # 62 bits aleatorios para rand_b + variant 10xx nos 2 MSBs
    rand_b = int.from_bytes(os.urandom(8), 'big') & 0x3FFFFFFFFFFFFFFF

    # Monta MSB: [timestamp 48 bits][version=7 4 bits][rand_a 12 bits]
    msb = (timestamp_ms << 16) | (0x7 << 12) | rand_a

    # Monta LSB: [variant=10 2 bits][rand_b 62 bits]
    lsb = (0x8 << 60) | rand_b

    return uuid.UUID(int=(msb << 64) | lsb)


def extract_timestamp(uid: uuid.UUID) -> int:
    """Extrai o timestamp Unix em ms de um UUID v7."""
    return (uid.int >> 80) & ((1 << 48) - 1)


# ============================================================
# DEMONSTRACAO
# ============================================================
if __name__ == "__main__":
    print("=== UUID v7 Generator (RFC 9562) ===\n")

    # Gerar 5 UUIDs v7
    ids = [uuid_v7() for _ in range(5)]
    for i, uid in enumerate(ids, 1):
        ts = extract_timestamp(uid)
        ts_str = time.strftime('%Y-%m-%d %H:%M:%S', time.localtime(ts / 1000))
        print(f"UUID v7 [{i}]: {uid}")
        print(f"  Timestamp: {ts} ({ts_str})")

    # Verificar ordenacao
    print("\n--- Verificacao de Ordenacao ---")
    print("Ordenados por timestamp:")
    for uid in sorted(ids, key=lambda u: u.int):
        print(f"  {uid} (ts: {extract_timestamp(uid)})")

    # Demonstrar insercao no banco (exemplo conceitual)
    print("\n--- Exemplo de Insercao no Banco ---")
    uid = uuid_v7()
    print("# PostgreSQL (tipo UUID nativo):")
    print(f"INSERT INTO cliente_uuid_v7 VALUES ('{uid}', 'Nome', 'email@ex.com', CURRENT_DATE);")
    print("# Oracle (RAW(16)):")
    hex_str = uid.bytes.hex()
    print(f"INSERT INTO cliente_uuid_v7 VALUES (HEXTORAW('{hex_str}'), 'Nome', 'email@ex.com', SYSDATE);")

    # Benchmark: 100.000 UUIDs v7
    print("\n--- Benchmark: 100.000 UUIDs v7 ---")
    start = time.perf_counter()
    for _ in range(100_000):
        uuid_v7()
    elapsed = time.perf_counter() - start
    print(f"Tempo total: {elapsed * 1000:.2f} ms")
    print(f"UUIDs/ms: {100_000 / (elapsed * 1000):.1f}")

    # Demonstracao de ordenacao com sleep
    print("\n--- Demonstracao de Ordenacao Temporal ---")
    batch1 = [uuid_v7() for _ in range(3)]
    time.sleep(0.01)  # 10ms de pausa
    batch2 = [uuid_v7() for _ in range(3)]
    print("Batch 1 (antes do sleep):")
    for uid in batch1:
        print(f"  {uid}")
    print("Batch 2 (depois do sleep):")
    for uid in batch2:
        print(f"  {uid}")
    print("Todos ordenados:")
    for uid in sorted(batch1 + batch2, key=lambda u: u.int):
        print(f"  {uid}")
