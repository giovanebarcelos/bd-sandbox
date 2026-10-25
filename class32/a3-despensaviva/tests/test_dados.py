"""Etapa 3 (DML): os dados de exemplo existem e são coerentes."""

CONTAGENS = {"categoria": 4, "fornecedor": 4, "insumo": 8, "lote": 13, "movimentacao": 23, "receita": 3, "receita_insumo": 10,
             "auditoria_lote": 0}


def test_contagem_de_linhas_de_cada_tabela(db):
    for tabela, esperado in CONTAGENS.items():
        assert db.um(f"SELECT COUNT(*) FROM {tabela}") == esperado, tabela


def test_saldo_de_cada_lote_bate_com_entrada_menos_consumos(db):
    """quantidade_atual = quantidade_inicial - soma dos CONSUMOS. Nenhum lote pode violar."""
    divergentes = db.consulta(
        "SELECT l.lote_id FROM lote l "
        "LEFT JOIN (SELECT lote_id, SUM(quantidade) c FROM movimentacao WHERE tipo = 'CONSUMO' GROUP BY lote_id) m ON m.lote_id = l.lote_id "
        "WHERE l.quantidade_atual <> l.quantidade_inicial - COALESCE(m.c, 0)")
    assert divergentes == []


def test_cada_lote_tem_exatamente_uma_entrada_igual_a_quantidade_inicial(db):
    ruins = db.consulta(
        "SELECT l.lote_id FROM lote l LEFT JOIN movimentacao m ON m.lote_id = l.lote_id AND m.tipo = 'ENTRADA' "
        "GROUP BY l.lote_id, l.quantidade_inicial HAVING COUNT(m.mov_id) <> 1 OR SUM(m.quantidade) <> l.quantidade_inicial")
    assert ruins == []


def test_ha_lotes_vencidos_e_lotes_a_vencer_para_as_consultas_terem_o_que_mostrar(db):
    assert db.um(f"SELECT COUNT(*) FROM lote WHERE data_validade < {db.hoje}") == 2
    assert db.um(f"SELECT COUNT(*) FROM lote WHERE data_validade BETWEEN {db.hoje} AND {db.hoje} + 7") == 3
