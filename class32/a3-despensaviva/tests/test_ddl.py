"""Etapa 2 (DDL): constraints, chaves estrangeiras e ON DELETE — nos dois bancos."""
import pytest

from conftest import DbError

TABELAS = {"auditoria_lote", "categoria", "fornecedor", "insumo", "lote", "movimentacao", "receita", "receita_insumo"}


def test_as_oito_tabelas_existem(db):
    if db.nome == "postgresql":
        achadas = db.consulta("SELECT table_name FROM information_schema.tables WHERE table_schema = 'public'")
    else:
        achadas = db.consulta("SELECT LOWER(table_name) FROM user_tables")
    assert {a[0] for a in achadas} == TABELAS


def test_toda_constraint_tem_nome_explicito(db):
    """Nada de `lote_insumo_id_fkey` nem `SYS_C0012345`: pk_, uk_, fk_ ou ck_."""
    if db.nome == "postgresql":
        nomes = db.consulta("SELECT constraint_name FROM information_schema.table_constraints "
                            "WHERE table_schema = 'public' AND constraint_type IN ('PRIMARY KEY','UNIQUE','FOREIGN KEY','CHECK') "
                            "AND constraint_name NOT LIKE '%%_not_null'")
    else:
        nomes = db.consulta("SELECT LOWER(constraint_name) FROM user_constraints "
                            "WHERE constraint_type IN ('P','U','R','C') AND generated = 'USER NAME'")
    assert len(nomes) == 28          # 8 PK + 4 UK + 6 FK + 10 CHECK
    assert all(n[0].startswith(("pk_", "uk_", "fk_", "ck_")) for n in nomes), nomes


def test_toda_chave_estrangeira_tem_on_delete_explicito(db):
    """CASCADE só em receita_insumo -> receita; as outras bloqueiam (RESTRICT no PostgreSQL, NO ACTION no Oracle)."""
    if db.nome == "postgresql":
        regras = db.consulta("SELECT conname, confdeltype FROM pg_constraint WHERE contype = 'f' ORDER BY conname")
        cascata = {n for n, r in regras if r == "c"}
        bloqueio = {n for n, r in regras if r == "r"}
    else:
        regras = db.consulta("SELECT LOWER(constraint_name), delete_rule FROM user_constraints WHERE constraint_type = 'R'")
        cascata = {n for n, r in regras if r == "CASCADE"}
        bloqueio = {n for n, r in regras if r == "NO ACTION"}
    assert cascata == {"fk_ri_receita"}
    assert len(bloqueio) == 5 and len(regras) == 6


def test_unidade_invalida_e_barrada_pelo_check(db):
    with pytest.raises(DbError, match="(?i)ck_insumo_unid"):
        db.executa("INSERT INTO insumo (nome, unidade, estoque_minimo, categoria_id) VALUES ('Teste', 'XX', 0, 1)")


def test_nome_de_insumo_repetido_e_barrado_pela_unique(db):
    with pytest.raises(DbError, match="(?i)uk_insumo_nome"):
        db.executa("INSERT INTO insumo (nome, unidade, estoque_minimo, categoria_id) VALUES ('Arroz', 'KG', 0, 1)")


def test_tipo_de_fornecedor_fora_da_lista_e_barrado(db):
    with pytest.raises(DbError, match="(?i)ck_fornecedor_tipo"):
        db.executa("INSERT INTO fornecedor (nome, tipo) VALUES ('Novo', 'OUTRO')")


@pytest.mark.parametrize("inicial, atual", [(10, 11), (10, -1), (0, 0)])
def test_quantidade_do_lote_fora_dos_limites_e_barrada(db, inicial, atual):
    sql = ("INSERT INTO lote (insumo_id, fornecedor_id, quantidade_inicial, quantidade_atual, data_entrada, data_validade) "
           f"VALUES (1, 1, ?, ?, {db.hoje}, {db.hoje} + 10)")
    with pytest.raises(DbError, match="(?i)ck_lote_"):
        db.executa(sql, inicial, atual)


def test_insert_com_validade_antes_da_entrada_e_barrado(db):
    """No INSERT quem barra primeiro é o trigger (BEFORE); a CHECK é a segunda linha de defesa (teste seguinte)."""
    with pytest.raises(DbError, match="(?i)DESPENSA-002|ck_lote_datas"):
        db.executa("INSERT INTO lote (insumo_id, fornecedor_id, quantidade_inicial, quantidade_atual, data_entrada, data_validade) "
                   f"VALUES (1, 1, 5, 5, {db.hoje}, {db.hoje} - 1)")


def test_update_com_validade_antes_da_entrada_e_barrado_pela_check(db):
    """O trigger de validade só olha o INSERT; no UPDATE quem protege é a CHECK `ck_lote_datas`."""
    with pytest.raises(DbError, match="(?i)ck_lote_datas"):
        db.executa("UPDATE lote SET data_validade = data_entrada - 1 WHERE lote_id = 1")


def test_apagar_insumo_com_lotes_e_bloqueado(db):
    with pytest.raises(DbError, match="(?i)fk_(lote_insumo|ri_insumo)"):
        db.executa("DELETE FROM insumo WHERE insumo_id = 1")


def test_apagar_fornecedor_com_lotes_e_bloqueado(db):
    with pytest.raises(DbError, match="(?i)fk_lote_forn"):
        db.executa("DELETE FROM fornecedor WHERE fornecedor_id = 1")


def test_apagar_receita_leva_os_ingredientes_junto(db):
    assert db.um("SELECT COUNT(*) FROM receita_insumo WHERE receita_id = 1") == 3
    db.executa("DELETE FROM receita WHERE receita_id = 1")
    assert db.um("SELECT COUNT(*) FROM receita_insumo WHERE receita_id = 1") == 0


def test_chave_estrangeira_barra_lote_de_insumo_inexistente(db):
    with pytest.raises(DbError, match="(?i)fk_lote_insumo"):
        db.executa("INSERT INTO lote (insumo_id, fornecedor_id, quantidade_inicial, quantidade_atual, data_entrada, data_validade) "
                   f"VALUES (999, 1, 5, 5, {db.hoje}, {db.hoje} + 10)")
