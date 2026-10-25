-- DespensaViva · Oracle · 04_indices.sql
-- O Oracle também NÃO indexa chave estrangeira sozinho (só PK/UK). Estes três cobrem o FEFO e os JOINs.
-- FEFO: lotes do insumo, na ordem de validade
CREATE INDEX idx_lote_insumo_validade ON lote (insumo_id, data_validade);
-- FK: movimentações de um lote
CREATE INDEX idx_mov_lote             ON movimentacao (lote_id);
-- FK: DELETE em fornecedor sem varredura total
CREATE INDEX idx_lote_fornecedor      ON lote (fornecedor_id);
