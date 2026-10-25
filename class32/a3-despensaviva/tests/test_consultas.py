"""Etapa 3 (DQL): as 10 consultas dão o resultado esperado — e O MESMO resultado nos dois bancos."""
import re

import pytest

from conftest import consultas_do_arquivo

ESPERADO = {
    "Q01": [("Alho", "KG", 3.0), ("Arroz", "KG", 68.0), ("Cebola", "KG", 7.0), ("Farinha de trigo", "KG", 0.0),
            ("Feijão", "KG", 45.0), ("Leite", "L", 18.0), ("Sal", "KG", 5.0), ("Tomate", "KG", 14.0)],
    "Q02": [("Tomate", 5, 4.0, 2), ("Leite", 8, 6.0, 5), ("Tomate", 6, 10.0, 7)],
    "Q03": [("Leite", 18.0, 1), ("Feijão", 15.0, 2), ("Arroz", 12.0, 3), ("Tomate", 11.0, 4), ("Cebola", 5.0, 5), ("Sal", 5.0, 5)],
    "Q04": [("Alho",), ("Farinha de trigo",)],
    "Q05": [("Arroz", 5.0, 5.0), ("Arroz", 7.0, 12.0), ("Cebola", 5.0, 5.0), ("Feijão", 10.0, 10.0), ("Feijão", 5.0, 15.0),
            ("Leite", 10.0, 10.0), ("Leite", 8.0, 18.0), ("Sal", 5.0, 5.0), ("Tomate", 6.0, 6.0), ("Tomate", 5.0, 11.0)],
    "Q06": [("Cebola", 8.0, 7.0), ("Farinha de trigo", 5.0, 0.0)],
    "Q07": [("Feira do Produtor", "COMERCIO", 5, 38.5), ("Banco de Alimentos Central", "DOADOR", 3, 23.1),
            ("Mercado Bom Preço", "COMERCIO", 3, 23.1), ("Padaria Solidária", "DOADOR", 2, 15.4)],
    "Q08": [("Alho", 11, 8), ("Arroz", 1, 150), ("Cebola", 7, 20), ("Feijão", 3, 90), ("Leite", 8, 5), ("Sal", 10, 400),
            ("Tomate", 5, 2)],
    "Q09": [("Arroz e feijão",)],           # a sopa pede 14,5 kg de tomate e há 14 kg
    "Q10": [("Grãos", 10.0), ("Laticínios", 8.0), ("TOTAL", 18.0)],
}


def normaliza(linhas):
    return [tuple(round(v, 3) if isinstance(v, float) else v for v in linha) for linha in linhas]


@pytest.mark.parametrize("q", sorted(ESPERADO))
def test_consulta_devolve_o_resultado_esperado(db, q):
    sql = consultas_do_arquivo(db)[q]
    assert normaliza(db.consulta(sql)) == ESPERADO[q]


def test_o_arquivo_tem_exatamente_as_10_consultas(db):
    assert sorted(consultas_do_arquivo(db)) == sorted(ESPERADO)


def test_requisitos_de_tecnica_da_rubrica(db):
    """A rubrica pede: 2+ com JOIN, 2+ com window function e 2+ com agregação."""
    qs = consultas_do_arquivo(db)
    com_join = [q for q, s in qs.items() if re.search(r"\bJOIN\b", s)]
    com_window = [q for q, s in qs.items() if re.search(r"\bOVER\s*\(", s)]
    com_agregacao = [q for q, s in qs.items() if re.search(r"\b(SUM|COUNT|AVG|MAX|MIN)\s*\(", s)]
    assert len(com_join) >= 2 and len(com_window) >= 2 and len(com_agregacao) >= 2
    assert set(com_window) == {"Q03", "Q05", "Q07", "Q08"}


def insere_lote(db, insumo, quantidade, dias_ate_vencer):
    db.executa("INSERT INTO lote (insumo_id, fornecedor_id, quantidade_inicial, quantidade_atual, data_entrada, data_validade) "
               f"VALUES (?, 4, ?, ?, {db.hoje} - 10, {db.hoje} + ?)", insumo, quantidade, quantidade, dias_ate_vencer)


def test_lote_que_vence_hoje_conta_como_saldo_e_nao_como_desperdicio(db):
    """Valor-limite do vencimento: no dia da validade o lote ainda vale (Q01) e ainda não é desperdício (Q10)."""
    qs = consultas_do_arquivo(db)
    insere_lote(db, 6, 1, 0)                                             # 1 kg de sal que vence HOJE
    assert dict((n, s) for n, _, s in db.consulta(qs["Q01"]))["Sal"] == 6.0
    assert db.consulta(qs["Q10"]) == [("Grãos", 10.0), ("Laticínios", 8.0), ("TOTAL", 18.0)]
    insere_lote(db, 6, 1, -1)                                            # 1 kg que venceu ONTEM
    assert db.consulta(qs["Q10"])[-1] == ("TOTAL", 19.0)


def test_q09_a_sopa_so_aparece_quando_o_tomate_cobre_as_50_porcoes(db):
    """50 porções × 0,29 kg = 14,5 kg. Com 14 kg não dá; com +1 kg (15 kg) dá."""
    sql = consultas_do_arquivo(db)["Q09"]
    assert db.consulta(sql) == [("Arroz e feijão",)]
    insere_lote(db, 3, 1, 30)
    assert db.consulta(sql) == [("Arroz e feijão",), ("Sopa de tomate",)]
