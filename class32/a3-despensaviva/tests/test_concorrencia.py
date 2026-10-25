"""Etapa 4 (procedures), concorrência: dois operadores pedem o mesmo insumo ao mesmo tempo (RN-03: nunca vender o que não há).

Estes testes usam DUAS conexões e gravam de verdade (COMMIT), por isso criam um insumo próprio e o apagam no final.
"""
import threading
import time
from datetime import date, timedelta

import pytest

from conftest import DbError, nova_conexao


@pytest.fixture
def insumo_de_teste(conexao):
    """Insumo 'Concorrência' com um único lote de 10 kg, gravado de verdade; apagado depois."""
    c = nova_conexao(conexao.nome)
    c.executa("INSERT INTO insumo (nome, unidade, estoque_minimo, categoria_id) VALUES ('Concorrência', 'KG', 0, 1)")
    insumo = int(c.um("SELECT insumo_id FROM insumo WHERE nome = 'Concorrência'"))
    c.chama("registrar_entrada_lote", insumo, 1, 10, date.today() + timedelta(days=30))
    c.con.commit()
    lote = int(c.um("SELECT lote_id FROM lote WHERE insumo_id = ?", insumo))
    yield c, insumo, lote
    c.rollback()
    c.executa("DELETE FROM auditoria_lote WHERE lote_id = ?", lote)
    c.executa("DELETE FROM movimentacao WHERE lote_id = ?", lote)
    c.executa("DELETE FROM lote WHERE lote_id = ?", lote)
    c.executa("DELETE FROM insumo WHERE insumo_id = ?", insumo)
    c.con.commit()
    c.con.close()


def test_dois_pedidos_de_8_kg_para_10_kg_so_um_e_atendido(conexao, insumo_de_teste):
    """A pede 8 kg e AINDA NÃO grava; B pede 8 kg na outra sessão e fica esperando o lock do lote (FOR UPDATE).

    Quando A grava, B acorda e enxerga só 2 kg. A procedure precisa RECUSAR o pedido inteiro (DESPENSA-003), em vez
    de entregar os 2 kg e dizer que deu certo.
    """
    a, insumo, lote = insumo_de_teste
    b = nova_conexao(conexao.nome)
    resultado: dict = {}

    a.chama("consumir_insumo", insumo, 8, "Operador A")            # A segura o lock do lote, sem COMMIT

    def pedido_de_b():
        try:
            b.chama("consumir_insumo", insumo, 8, "Operador B")
            b.con.commit()
            resultado["b"] = "atendido"
        except DbError as e:
            b.rollback()
            resultado["b"] = str(e)

    fio = threading.Thread(target=pedido_de_b)
    fio.start()
    time.sleep(1.0)                                                 # B já está bloqueado esperando A
    assert "b" not in resultado, "B deveria estar esperando o lock de A"
    a.con.commit()
    fio.join(timeout=20)
    b.con.close()

    assert "DESPENSA-003" in resultado["b"], resultado
    assert a.um("SELECT quantidade_atual FROM lote WHERE lote_id = ?", lote) == 2.0
    assert a.um("SELECT COALESCE(SUM(quantidade), 0) FROM movimentacao WHERE lote_id = ? AND tipo = 'CONSUMO'", lote) == 8.0
