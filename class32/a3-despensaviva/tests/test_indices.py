"""Etapa 5 (índices): os três índices existem, nas colunas e na ordem certas, nos dois bancos."""

ESPERADO = {
    "idx_lote_insumo_validade": ("lote", ["insumo_id", "data_validade"]),
    "idx_mov_lote": ("movimentacao", ["lote_id"]),
    "idx_lote_fornecedor": ("lote", ["fornecedor_id"]),
}


def indices_do_banco(db):
    if db.nome == "postgresql":
        linhas = db.consulta(
            "SELECT i.relname, t.relname, a.attname, k.ord FROM pg_index x "
            "JOIN pg_class i ON i.oid = x.indexrelid JOIN pg_class t ON t.oid = x.indrelid "
            "CROSS JOIN LATERAL unnest(x.indkey) WITH ORDINALITY AS k(attnum, ord) "
            "JOIN pg_attribute a ON a.attrelid = t.oid AND a.attnum = k.attnum "
            "WHERE i.relname LIKE 'idx%%' ORDER BY i.relname, k.ord")
    else:
        linhas = db.consulta(
            "SELECT LOWER(index_name), LOWER(table_name), LOWER(column_name), column_position "
            "FROM user_ind_columns WHERE LOWER(index_name) LIKE 'idx%' ORDER BY index_name, column_position")
    achados: dict[str, tuple] = {}
    for indice, tabela, coluna, _ in linhas:
        achados.setdefault(indice, (tabela, []))[1].append(coluna)
    return achados


def test_os_tres_indices_existem_nas_colunas_certas(db):
    assert indices_do_banco(db) == ESPERADO
