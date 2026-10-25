"""Etapa 4 (triggers): auditoria de saldo e validação de validade — nos dois bancos."""
from datetime import date, timedelta

import pytest

from conftest import DbError

INSERT_LOTE = ("INSERT INTO lote (insumo_id, fornecedor_id, quantidade_inicial, quantidade_atual, data_entrada, data_validade) "
               "VALUES (6, 4, 5, 5, {h}, {h} + ?)")


def auditoria(db):
    return db.consulta("SELECT lote_id, operacao, qtd_antes, qtd_depois FROM auditoria_lote ORDER BY aud_id")


# --- trg_lote_validade (BEFORE INSERT): RN-02 mesmo para quem não usa a procedure --------------------------------
@pytest.mark.parametrize("dias", [3, 4, 100])
def test_insert_direto_com_validade_de_3_dias_ou_mais_passa(db, dias):
    db.executa(INSERT_LOTE.format(h=db.hoje), dias)
    assert db.um("SELECT COUNT(*) FROM lote") == 14


@pytest.mark.parametrize("dias", [2, 1, 0])
def test_insert_direto_com_validade_abaixo_de_3_dias_e_barrado(db, dias):
    with pytest.raises(DbError, match="DESPENSA-002"):
        db.executa(INSERT_LOTE.format(h=db.hoje), dias)


# --- trg_lote_auditoria (AFTER INSERT OR UPDATE OF quantidade_atual) ----------------------------------------------
def test_inserir_lote_gera_uma_linha_de_auditoria_sem_saldo_anterior(db):
    db.executa(INSERT_LOTE.format(h=db.hoje), 10)
    novo = int(db.um("SELECT MAX(lote_id) FROM lote"))        # a identidade não volta no rollback: não assuma o número 14
    assert auditoria(db) == [(novo, "INSERT", None, 5.0)]


def test_consumir_gera_uma_linha_de_auditoria_por_lote_alterado_com_antes_e_depois(db):
    db.chama("consumir_insumo", 3, 6, "Teste")           # 4 do lote 5 e 2 do lote 6
    assert auditoria(db) == [(5, "UPDATE", 4.0, 0.0), (6, "UPDATE", 10.0, 8.0)]


def test_mudar_outra_coluna_nao_gera_auditoria(db):
    """O trigger é `UPDATE OF quantidade_atual`: alterar a validade não registra nada."""
    db.executa("UPDATE lote SET data_validade = data_validade + 1 WHERE lote_id = 1")
    assert auditoria(db) == []


def test_a_auditoria_registra_o_usuario_do_banco(db):
    db.chama("consumir_insumo", 6, 1, "Teste")
    esperado = db.um("SELECT current_user" if db.nome == "postgresql" else "SELECT USER FROM dual")
    assert db.um("SELECT usuario_banco FROM auditoria_lote").lower() == esperado.lower()


def test_consumo_recusado_nao_deixa_rastro_na_auditoria(db):
    with pytest.raises(DbError):
        db.chama("consumir_insumo", 3, 999, "Teste")
    db.rollback()
    assert auditoria(db) == []
