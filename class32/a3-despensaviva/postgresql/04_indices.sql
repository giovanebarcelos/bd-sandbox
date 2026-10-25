-- DespensaViva · PostgreSQL · 04_indices.sql
-- O PostgreSQL NÃO indexa chave estrangeira sozinho (ao contrário da PK/UK). Estes três cobrem o FEFO e os JOINs.
CREATE INDEX idx_lote_insumo_validade ON lote (insumo_id, data_validade);  -- FEFO: lotes do insumo, na ordem de validade
CREATE INDEX idx_mov_lote             ON movimentacao (lote_id);            -- FK: movimentações de um lote
CREATE INDEX idx_lote_fornecedor      ON lote (fornecedor_id);              -- FK: DELETE em fornecedor sem varredura total
