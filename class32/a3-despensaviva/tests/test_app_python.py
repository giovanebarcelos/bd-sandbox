"""Etapa 6 (conexão via aplicação): a aplicação Python da entrega funciona nos dois bancos."""
import sys

import pytest

from conftest import RAIZ

sys.path.insert(0, str(RAIZ / "python"))
import despensa_app  # noqa: E402


@pytest.fixture
def d(db):
    return despensa_app.Despensa(db.con, db.nome)


def test_demonstracao_roda_o_roteiro_inteiro_e_desfaz_no_final(d):
    linhas = despensa_app.demonstracao(d, efetivar=False)
    texto = "\n".join(linhas)
    assert "saldo de tomate antes: 14 kg" in texto
    assert "saldo 8 kg, lotes [(5, 0.0), (6, 8.0)]" in texto            # FEFO: esgotou o lote que vence primeiro
    assert "DESPENSA-003" in texto and "DESPENSA-002" in texto
    assert "saldo volta a 14 kg" in texto
    assert d.saldo(3) == 14.0


def test_erro_de_negocio_vira_excecao_com_codigo(d):
    with pytest.raises(despensa_app.ErroDeNegocio) as e:
        d.consumir(3, 100)
    assert e.value.codigo == "DESPENSA-003"


def test_apos_um_erro_a_transacao_continua_utilizavel(d):
    """No PostgreSQL, sem o SAVEPOINT a transação ficaria abortada depois do erro."""
    with pytest.raises(despensa_app.ErroDeNegocio):
        d.consumir(3, 100)
    d.consumir(3, 1)
    assert d.saldo(3) == 13.0


def test_quantidade_decimal_funciona_em_ambos_os_bancos(d):
    """float virava double precision no PostgreSQL e a procedure de parâmetro NUMERIC não era encontrada."""
    d.consumir(3, 4.5)
    assert d.saldo(3) == 9.5
