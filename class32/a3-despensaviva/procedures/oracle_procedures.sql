-- DespensaViva · Oracle · procedures e triggers (PL/SQL)
-- Códigos de erro (mesmos nos dois bancos, para a aplicação tratar igual). No Oracle viram ORA-20001..20004:
--   DESPENSA-001 quantidade deve ser positiva  (ORA-20001)    DESPENSA-003 estoque insuficiente (ORA-20003)
--   DESPENSA-002 validade mínima de 3 dias     (ORA-20002)    DESPENSA-004 insumo ou fornecedor inexistente (ORA-20004)
-- As procedures NÃO fazem COMMIT: quem chama decide a transação (e pode desfazer tudo).

-- ---------------------------------------------------------------------------------------------
-- Procedure 1: registra a entrada de um lote (RN-02: validade de pelo menos 3 dias à frente).
-- ---------------------------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE registrar_entrada_lote(
    p_insumo_id     IN NUMBER,
    p_fornecedor_id IN NUMBER,
    p_quantidade    IN NUMBER,
    p_validade      IN DATE)
IS
    v_lote_id NUMBER;
    v_existem NUMBER;
BEGIN
    IF p_quantidade IS NULL OR p_quantidade <= 0 THEN
        RAISE_APPLICATION_ERROR(-20001, 'DESPENSA-001: a quantidade deve ser positiva');
    END IF;
    IF p_validade < TRUNC(SYSDATE) + 3 THEN
        RAISE_APPLICATION_ERROR(-20002, 'DESPENSA-002: a validade deve ser de pelo menos 3 dias a partir de hoje');
    END IF;
    SELECT (SELECT COUNT(*) FROM insumo WHERE insumo_id = p_insumo_id)
         + (SELECT COUNT(*) FROM fornecedor WHERE fornecedor_id = p_fornecedor_id)
      INTO v_existem FROM dual;
    IF v_existem < 2 THEN
        RAISE_APPLICATION_ERROR(-20004, 'DESPENSA-004: insumo ou fornecedor inexistente');
    END IF;

    INSERT INTO lote (insumo_id, fornecedor_id, quantidade_inicial, quantidade_atual, data_entrada, data_validade)
    VALUES (p_insumo_id, p_fornecedor_id, p_quantidade, p_quantidade, TRUNC(SYSDATE), p_validade)
    RETURNING lote_id INTO v_lote_id;

    INSERT INTO movimentacao (lote_id, tipo, quantidade, motivo)
    VALUES (v_lote_id, 'ENTRADA', p_quantidade, 'Entrada de lote');
END registrar_entrada_lote;
/

-- ---------------------------------------------------------------------------------------------
-- Procedure 2: consome um insumo seguindo FEFO (RN-01) e sem tocar em lote vencido (RN-03).
-- Se o saldo NÃO vencido não cobre a quantidade, nada é consumido (a exceção sai antes de qualquer UPDATE).
-- ---------------------------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE consumir_insumo(
    p_insumo_id  IN NUMBER,
    p_quantidade IN NUMBER,
    p_motivo     IN VARCHAR2 DEFAULT 'Consumo')
IS
    v_saldo    NUMBER;
    v_restante NUMBER := p_quantidade;
    v_tirar    NUMBER;
    v_existe   NUMBER;

    -- FEFO: lotes não vencidos, do que vence primeiro para o que vence depois (desempate pelo lote mais antigo).
    CURSOR c_lotes IS
        SELECT lote_id, quantidade_atual
          FROM lote
         WHERE insumo_id = p_insumo_id AND data_validade >= TRUNC(SYSDATE) AND quantidade_atual > 0
         ORDER BY data_validade, lote_id
           FOR UPDATE;
BEGIN
    IF p_quantidade IS NULL OR p_quantidade <= 0 THEN
        RAISE_APPLICATION_ERROR(-20001, 'DESPENSA-001: a quantidade deve ser positiva');
    END IF;
    SELECT COUNT(*) INTO v_existe FROM insumo WHERE insumo_id = p_insumo_id;
    IF v_existe = 0 THEN
        RAISE_APPLICATION_ERROR(-20004, 'DESPENSA-004: insumo ou fornecedor inexistente');
    END IF;

    SELECT NVL(SUM(quantidade_atual), 0) INTO v_saldo
      FROM lote
     WHERE insumo_id = p_insumo_id AND data_validade >= TRUNC(SYSDATE);
    IF v_saldo < p_quantidade THEN
        RAISE_APPLICATION_ERROR(-20003, 'DESPENSA-003: estoque insuficiente (disponível ' || v_saldo || ', pedido ' || p_quantidade || ')');
    END IF;

    FOR r IN c_lotes LOOP
        EXIT WHEN v_restante <= 0;
        v_tirar := LEAST(r.quantidade_atual, v_restante);
        UPDATE lote SET quantidade_atual = quantidade_atual - v_tirar WHERE CURRENT OF c_lotes;
        INSERT INTO movimentacao (lote_id, tipo, quantidade, motivo) VALUES (r.lote_id, 'CONSUMO', v_tirar, p_motivo);
        v_restante := v_restante - v_tirar;
    END LOOP;

    -- Conferência final: o saldo lido lá em cima pode ter diminuído enquanto esperávamos o lock de outro operador.
    -- Sobrou pedido sem lote para atender? Recusa o pedido INTEIRO (a exceção desfaz o que esta chamada já consumiu).
    IF v_restante > 0 THEN
        RAISE_APPLICATION_ERROR(-20003, 'DESPENSA-003: estoque insuficiente (faltaram ' || v_restante || ' de ' || p_quantidade || ')');
    END IF;
END consumir_insumo;
/

-- ---------------------------------------------------------------------------------------------
-- Trigger 1 (validação, RN-02): protege também quem insere direto na tabela, sem passar pela procedure.
-- ---------------------------------------------------------------------------------------------
CREATE OR REPLACE TRIGGER trg_lote_validade
    BEFORE INSERT ON lote
    FOR EACH ROW
BEGIN
    IF :NEW.data_validade < :NEW.data_entrada + 3 THEN
        RAISE_APPLICATION_ERROR(-20002, 'DESPENSA-002: a validade deve ser de pelo menos 3 dias após a entrada');
    END IF;
END trg_lote_validade;
/

-- ---------------------------------------------------------------------------------------------
-- Trigger 2 (auditoria): registra toda inserção de lote e toda mudança de saldo.
-- ---------------------------------------------------------------------------------------------
CREATE OR REPLACE TRIGGER trg_lote_auditoria
    AFTER INSERT OR UPDATE OF quantidade_atual ON lote
    FOR EACH ROW
BEGIN
    IF INSERTING THEN
        INSERT INTO auditoria_lote (lote_id, operacao, qtd_antes, qtd_depois, usuario_banco)
        VALUES (:NEW.lote_id, 'INSERT', NULL, :NEW.quantidade_atual, USER);
    ELSE
        INSERT INTO auditoria_lote (lote_id, operacao, qtd_antes, qtd_depois, usuario_banco)
        VALUES (:NEW.lote_id, 'UPDATE', :OLD.quantidade_atual, :NEW.quantidade_atual, USER);
    END IF;
END trg_lote_auditoria;
/
