"""Etapa 4 (procedures): regras RN-01 a RN-03, nos valores-limite, nos dois bancos.

Estado inicial (02_inserts.sql): tomate tem o lote 5 (saldo 4, vence em 2 dias) e o lote 6 (saldo 10, vence em 7 dias);
leite tem o lote 8 (6, vence em 5 dias), o lote 9 (12, vence em 10 dias) e o lote 13 (8, VENCIDO).
"""
from datetime import date, timedelta

import pytest

from conftest import DbError

TOMATE, LEITE, FARINHA, SAL = 3, 5, 8, 6


def saldos(db, insumo):
    return dict(db.consulta("SELECT lote_id, quantidade_atual FROM lote WHERE insumo_id = ? ORDER BY lote_id", insumo))


def novo_lote(db):
    """Id do lote recém-criado. Não use `14` fixo: identidade/sequence NÃO volta no rollback, o próximo id depende do histórico."""
    return int(db.um("SELECT MAX(lote_id) FROM lote"))


def movimentos_novos(db):
    return db.consulta("SELECT lote_id, tipo, quantidade FROM movimentacao WHERE mov_id > 23 ORDER BY mov_id")


# --- registrar_entrada_lote · RN-02: validade de pelo menos 3 dias ----------------------------------------------
@pytest.mark.parametrize("dias", [3, 4, 365])
def test_entrada_com_validade_de_3_dias_ou_mais_e_aceita(db, dias):
    db.chama("registrar_entrada_lote", SAL, 4, 5, date.today() + timedelta(days=dias))
    assert db.um("SELECT COUNT(*) FROM lote") == 14
    assert movimentos_novos(db) == [(novo_lote(db), "ENTRADA", 5.0)]


@pytest.mark.parametrize("dias", [2, 1, 0, -1])
def test_entrada_com_validade_abaixo_de_3_dias_e_recusada_e_nada_e_gravado(db, dias):
    with pytest.raises(DbError, match="DESPENSA-002"):
        db.chama("registrar_entrada_lote", SAL, 4, 5, date.today() + timedelta(days=dias))
    db.rollback()
    assert db.um("SELECT COUNT(*) FROM lote") == 13


@pytest.mark.parametrize("quantidade", [0, -1])
def test_entrada_de_quantidade_nao_positiva_e_recusada(db, quantidade):
    with pytest.raises(DbError, match="DESPENSA-001"):
        db.chama("registrar_entrada_lote", SAL, 4, quantidade, date.today() + timedelta(days=10))


@pytest.mark.parametrize("insumo, fornecedor", [(999, 1), (1, 999)])
def test_entrada_com_insumo_ou_fornecedor_inexistente_e_recusada(db, insumo, fornecedor):
    with pytest.raises(DbError, match="DESPENSA-004"):
        db.chama("registrar_entrada_lote", insumo, fornecedor, 5, date.today() + timedelta(days=10))


def test_entrada_grava_lote_com_saldo_igual_ao_inicial_e_a_movimentacao(db):
    db.chama("registrar_entrada_lote", SAL, 4, 7.5, date.today() + timedelta(days=30))
    lote = db.consulta("SELECT quantidade_inicial, quantidade_atual FROM lote WHERE lote_id = ?", novo_lote(db))[0]
    assert lote == (7.5, 7.5)
    assert movimentos_novos(db) == [(novo_lote(db), "ENTRADA", 7.5)]


# --- consumir_insumo · RN-01 (FEFO) e RN-03 (saldo não vencido) --------------------------------------------------
def test_consumo_dentro_do_primeiro_lote_nao_toca_nos_outros(db):
    db.chama("consumir_insumo", TOMATE, 3, "Teste")
    assert saldos(db, TOMATE) == {5: 1.0, 6: 10.0}
    assert movimentos_novos(db) == [(5, "CONSUMO", 3.0)]


def test_consumo_exatamente_igual_ao_primeiro_lote_zera_so_ele(db):
    db.chama("consumir_insumo", TOMATE, 4, "Teste")
    assert saldos(db, TOMATE) == {5: 0.0, 6: 10.0}
    assert movimentos_novos(db) == [(5, "CONSUMO", 4.0)]


def test_consumo_um_pouco_acima_do_primeiro_lote_passa_para_o_segundo(db):
    db.chama("consumir_insumo", TOMATE, 4.5, "Teste")
    assert saldos(db, TOMATE) == {5: 0.0, 6: 9.5}
    assert movimentos_novos(db) == [(5, "CONSUMO", 4.0), (6, "CONSUMO", 0.5)]


def test_consumo_do_saldo_inteiro_zera_todos_os_lotes_validos(db):
    db.chama("consumir_insumo", TOMATE, 14, "Teste")
    assert saldos(db, TOMATE) == {5: 0.0, 6: 0.0}


def test_consumo_acima_do_saldo_e_recusado_e_nada_e_consumido(db):
    """Atomicidade (RN-03): 14,001 kg quando há 14 kg não consome nem os 14."""
    with pytest.raises(DbError, match="DESPENSA-003"):
        db.chama("consumir_insumo", TOMATE, 14.001, "Teste")
    db.rollback()
    assert saldos(db, TOMATE) == {5: 4.0, 6: 10.0}
    assert movimentos_novos(db) == []


def test_fefo_usa_o_lote_que_vence_primeiro_e_ignora_o_vencido(db):
    """Leite: o lote 13 está vencido (e é o mais antigo) e jamais é usado; o 8 (vence em 5 dias) vem antes do 9 (10 dias)."""
    db.chama("consumir_insumo", LEITE, 10, "Teste")
    assert saldos(db, LEITE) == {8: 0.0, 9: 8.0, 13: 8.0}
    assert movimentos_novos(db) == [(8, "CONSUMO", 6.0), (9, "CONSUMO", 4.0)]


def test_lote_vencido_nao_conta_para_o_saldo(db):
    """Farinha só tem o lote 12, vencido (saldo 10): não há estoque utilizável."""
    with pytest.raises(DbError, match="DESPENSA-003"):
        db.chama("consumir_insumo", FARINHA, 1, "Teste")


@pytest.mark.parametrize("quantidade", [0, -2])
def test_consumo_de_quantidade_nao_positiva_e_recusado(db, quantidade):
    with pytest.raises(DbError, match="DESPENSA-001"):
        db.chama("consumir_insumo", TOMATE, quantidade, "Teste")


def test_consumo_de_insumo_inexistente_e_recusado(db):
    with pytest.raises(DbError, match="DESPENSA-004"):
        db.chama("consumir_insumo", 999, 1, "Teste")


def test_consumo_registra_o_motivo_na_movimentacao(db):
    db.chama("consumir_insumo", SAL, 1, "Pão do café")
    assert db.consulta("SELECT motivo FROM movimentacao WHERE mov_id > 23") == [("Pão do café",)]


def test_as_procedures_nao_fazem_commit(db):
    """Quem chama decide a transação: depois do rollback o consumo desaparece."""
    db.chama("consumir_insumo", TOMATE, 3, "Teste")
    db.rollback()
    assert saldos(db, TOMATE) == {5: 4.0, 6: 10.0}


def test_lote_que_vence_hoje_ainda_pode_ser_consumido(db):
    """Valor-limite da validade: `data_validade >= hoje` (o dia do vencimento ainda vale); ontem já não vale."""
    ins = ("INSERT INTO lote (insumo_id, fornecedor_id, quantidade_inicial, quantidade_atual, data_entrada, data_validade) "
           f"VALUES (?, 4, 5, 5, {db.hoje} - 10, {db.hoje} + ?)")
    db.executa(ins, FARINHA, 0)           # vence HOJE
    db.executa(ins, FARINHA, -1)          # venceu ONTEM (a CHECK aceita: entrada foi há 10 dias)
    hoje_id = int(db.um("SELECT MIN(lote_id) FROM lote WHERE lote_id > 13"))
    db.chama("consumir_insumo", FARINHA, 5, "Teste")
    assert saldos(db, FARINHA)[hoje_id] == 0.0
    assert saldos(db, FARINHA)[hoje_id + 1] == 5.0           # o vencido ontem ficou intacto
    with pytest.raises(DbError, match="DESPENSA-003"):
        db.chama("consumir_insumo", FARINHA, 1, "Teste")


def test_segundo_consumo_depois_de_zerar_um_lote_pula_o_lote_vazio(db):
    """Sem o filtro `quantidade_atual > 0`, o lote 5 (zerado) entraria no laço e geraria uma movimentação de quantidade 0."""
    db.chama("consumir_insumo", TOMATE, 4, "Teste")
    db.chama("consumir_insumo", TOMATE, 1, "Teste")
    assert movimentos_novos(db) == [(5, "CONSUMO", 4.0), (6, "CONSUMO", 1.0)]
