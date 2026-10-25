-- DespensaViva · PostgreSQL · procedures e triggers (PL/pgSQL)
-- Códigos de erro (mesmos nos dois bancos, para a aplicação tratar igual):
--   DESPENSA-001 quantidade deve ser positiva      DESPENSA-003 estoque insuficiente (não vencido)
--   DESPENSA-002 validade mínima de 3 dias         DESPENSA-004 insumo ou fornecedor inexistente
-- As procedures NÃO fazem COMMIT: quem chama decide a transação (e pode desfazer tudo).

-- ---------------------------------------------------------------------------------------------
-- Procedure 1: registra a entrada de um lote (RN-02: validade de pelo menos 3 dias à frente).
-- ---------------------------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE registrar_entrada_lote(
    p_insumo_id     INTEGER,
    p_fornecedor_id INTEGER,
    p_quantidade    NUMERIC,
    p_validade      DATE)
LANGUAGE plpgsql AS $$
DECLARE
    v_lote_id INTEGER;
BEGIN
    IF p_quantidade IS NULL OR p_quantidade <= 0 THEN
        RAISE EXCEPTION 'DESPENSA-001: a quantidade deve ser positiva' USING ERRCODE = 'P0001';
    END IF;
    IF p_validade < CURRENT_DATE + 3 THEN
        RAISE EXCEPTION 'DESPENSA-002: a validade deve ser de pelo menos 3 dias a partir de hoje' USING ERRCODE = 'P0001';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM insumo WHERE insumo_id = p_insumo_id)
       OR NOT EXISTS (SELECT 1 FROM fornecedor WHERE fornecedor_id = p_fornecedor_id) THEN
        RAISE EXCEPTION 'DESPENSA-004: insumo ou fornecedor inexistente' USING ERRCODE = 'P0001';
    END IF;

    INSERT INTO lote (insumo_id, fornecedor_id, quantidade_inicial, quantidade_atual, data_entrada, data_validade)
    VALUES (p_insumo_id, p_fornecedor_id, p_quantidade, p_quantidade, CURRENT_DATE, p_validade)
    RETURNING lote_id INTO v_lote_id;

    INSERT INTO movimentacao (lote_id, tipo, quantidade, motivo)
    VALUES (v_lote_id, 'ENTRADA', p_quantidade, 'Entrada de lote');
END;
$$;

-- ---------------------------------------------------------------------------------------------
-- Procedure 2: consome um insumo seguindo FEFO (RN-01) e sem tocar em lote vencido (RN-03).
-- Se o saldo NÃO vencido não cobre a quantidade, nada é consumido (a exceção desfaz o que já foi feito).
-- ---------------------------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE consumir_insumo(
    p_insumo_id  INTEGER,
    p_quantidade NUMERIC,
    p_motivo     VARCHAR DEFAULT 'Consumo')
LANGUAGE plpgsql AS $$
DECLARE
    v_saldo    NUMERIC;
    v_restante NUMERIC := p_quantidade;
    v_tirar    NUMERIC;
    r          RECORD;
BEGIN
    IF p_quantidade IS NULL OR p_quantidade <= 0 THEN
        RAISE EXCEPTION 'DESPENSA-001: a quantidade deve ser positiva' USING ERRCODE = 'P0001';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM insumo WHERE insumo_id = p_insumo_id) THEN
        RAISE EXCEPTION 'DESPENSA-004: insumo ou fornecedor inexistente' USING ERRCODE = 'P0001';
    END IF;

    SELECT COALESCE(SUM(quantidade_atual), 0) INTO v_saldo
      FROM lote
     WHERE insumo_id = p_insumo_id AND data_validade >= CURRENT_DATE;
    IF v_saldo < p_quantidade THEN
        RAISE EXCEPTION 'DESPENSA-003: estoque insuficiente (disponível %, pedido %)', v_saldo, p_quantidade
            USING ERRCODE = 'P0001';
    END IF;

    -- FEFO: lotes não vencidos, do que vence primeiro para o que vence depois (desempate pelo lote mais antigo).
    FOR r IN SELECT lote_id, quantidade_atual
               FROM lote
              WHERE insumo_id = p_insumo_id AND data_validade >= CURRENT_DATE AND quantidade_atual > 0
              ORDER BY data_validade, lote_id
                FOR UPDATE
    LOOP
        EXIT WHEN v_restante <= 0;
        v_tirar := LEAST(r.quantidade_atual, v_restante);
        UPDATE lote SET quantidade_atual = quantidade_atual - v_tirar WHERE lote_id = r.lote_id;
        INSERT INTO movimentacao (lote_id, tipo, quantidade, motivo) VALUES (r.lote_id, 'CONSUMO', v_tirar, p_motivo);
        v_restante := v_restante - v_tirar;
    END LOOP;

    -- Conferência final: o saldo lido lá em cima pode ter diminuído enquanto esperávamos o lock de outro operador.
    -- Sobrou pedido sem lote para atender? Recusa o pedido INTEIRO (o RAISE desfaz o que este CALL já consumiu).
    IF v_restante > 0 THEN
        RAISE EXCEPTION 'DESPENSA-003: estoque insuficiente (faltaram % de %)', v_restante, p_quantidade USING ERRCODE = 'P0001';
    END IF;
END;
$$;

-- ---------------------------------------------------------------------------------------------
-- Trigger 1 (validação, RN-02): protege também quem insere direto na tabela, sem passar pela procedure.
-- ---------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_lote_validade() RETURNS TRIGGER AS $$
BEGIN
    IF NEW.data_validade < NEW.data_entrada + 3 THEN
        RAISE EXCEPTION 'DESPENSA-002: a validade deve ser de pelo menos 3 dias após a entrada' USING ERRCODE = 'P0001';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_lote_validade ON lote;
CREATE TRIGGER trg_lote_validade
    BEFORE INSERT ON lote
    FOR EACH ROW EXECUTE FUNCTION fn_lote_validade();

-- ---------------------------------------------------------------------------------------------
-- Trigger 2 (auditoria): registra toda inserção de lote e toda mudança de saldo.
-- ---------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_lote_auditoria() RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        INSERT INTO auditoria_lote (lote_id, operacao, qtd_antes, qtd_depois, usuario_banco)
        VALUES (NEW.lote_id, 'INSERT', NULL, NEW.quantidade_atual, current_user);
    ELSE
        INSERT INTO auditoria_lote (lote_id, operacao, qtd_antes, qtd_depois, usuario_banco)
        VALUES (NEW.lote_id, 'UPDATE', OLD.quantidade_atual, NEW.quantidade_atual, current_user);
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_lote_auditoria ON lote;
CREATE TRIGGER trg_lote_auditoria
    AFTER INSERT OR UPDATE OF quantidade_atual ON lote
    FOR EACH ROW EXECUTE FUNCTION fn_lote_auditoria();
