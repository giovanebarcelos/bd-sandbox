-- ============================================================================
-- BD2102-TutorialTransacoes.sql
-- Aula 21 - Tutorial passo a passo: transacoes, ACID e concorrencia
-- SGBD: Oracle Database XE 21c (container da Aula 03, usuario bd_aluno)
--
-- Roteiro do tutorial Aula_21_..._Tutorial_Oracle.md.
--   * Passos 1 a 5: uma sessao so; podem ser executados direto (@arquivo).
--   * Passos 6 a 12: precisam de DUAS sessoes (dois terminais). Estao aqui
--     como roteiro comentado: [A] = sessao A, [B] = sessao B, na ordem.
-- Atencao: no SQL*Plus, nunca coloque comentario "--" depois do ";" na
-- mesma linha (da ORA-00933).
-- ============================================================================

SET SERVEROUTPUT ON
SET FEEDBACK ON
SET LINESIZE 150
COLUMN titular  FORMAT A12
COLUMN username FORMAT A10
COLUMN event    FORMAT A32
COLUMN object_name FORMAT A16


-- ----------------------------------------------------------------------------
-- PASSO 1. TABELA DE APOIO
-- ----------------------------------------------------------------------------
BEGIN
    FOR t IN (SELECT table_name FROM user_tables
               WHERE table_name IN ('CONTA_CORRENTE', 'TABELA_TEMPORARIA')) LOOP
        EXECUTE IMMEDIATE 'DROP TABLE ' || t.table_name || ' PURGE';
    END LOOP;
END;
/

CREATE TABLE conta_corrente (
    id_conta   NUMBER(10)      NOT NULL,
    titular    VARCHAR2(100)   NOT NULL,
    saldo      NUMBER(12,2)    NOT NULL,
    CONSTRAINT pk_conta_corrente PRIMARY KEY (id_conta),
    CONSTRAINT ck_saldo_nao_negativo CHECK (saldo >= 0)
);

INSERT INTO conta_corrente (id_conta, titular, saldo) VALUES (1, 'Ana Souza', 1000.00);
INSERT INTO conta_corrente (id_conta, titular, saldo) VALUES (2, 'Bruno Lima', 500.00);
COMMIT;

SELECT * FROM conta_corrente ORDER BY id_conta;


-- ----------------------------------------------------------------------------
-- PASSO 2. ATOMICIDADE: a transacao comeca sozinha no primeiro DML
-- ----------------------------------------------------------------------------
-- 2a. Transferencia desfeita
UPDATE conta_corrente SET saldo = saldo - 200 WHERE id_conta = 1;
UPDATE conta_corrente SET saldo = saldo + 200 WHERE id_conta = 2;
SELECT id_conta, saldo FROM conta_corrente ORDER BY id_conta;
ROLLBACK;
SELECT id_conta, saldo FROM conta_corrente ORDER BY id_conta;

-- 2b. Transferencia confirmada
UPDATE conta_corrente SET saldo = saldo - 200 WHERE id_conta = 1;
UPDATE conta_corrente SET saldo = saldo + 200 WHERE id_conta = 2;
COMMIT;
SELECT id_conta, saldo FROM conta_corrente ORDER BY id_conta;


-- ----------------------------------------------------------------------------
-- PASSO 3. UM ERRO DESFAZ SO O COMANDO QUE FALHOU (atomicidade de comando)
-- ----------------------------------------------------------------------------
UPDATE conta_corrente SET saldo = saldo + 5000 WHERE id_conta = 2;
-- viola o CHECK (saldo >= 0): erro proposital
UPDATE conta_corrente SET saldo = saldo - 5000 WHERE id_conta = 1;
-- o credito de 5000 CONTINUA la, pendente
SELECT id_conta, saldo FROM conta_corrente ORDER BY id_conta;
-- quem decide e voce: aqui, desfazer tudo
ROLLBACK;
SELECT id_conta, saldo FROM conta_corrente ORDER BY id_conta;

-- 3b. "Tudo ou nada" automatico: bloco PL/SQL com EXCEPTION + ROLLBACK
BEGIN
    UPDATE conta_corrente SET saldo = saldo + 5000 WHERE id_conta = 2;
    UPDATE conta_corrente SET saldo = saldo - 5000 WHERE id_conta = 1;
    COMMIT;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE('Transferencia revertida: ' || SQLERRM);
END;
/
SELECT id_conta, saldo FROM conta_corrente ORDER BY id_conta;


-- ----------------------------------------------------------------------------
-- PASSO 4. ARMADILHA: DDL FAZ COMMIT IMPLICITO
-- ----------------------------------------------------------------------------
UPDATE conta_corrente SET saldo = 0 WHERE id_conta = 1;
-- um CREATE/ALTER/DROP confirma tudo o que estava pendente...
CREATE TABLE tabela_temporaria (x NUMBER);
-- ...entao este ROLLBACK nao tem mais o que desfazer
ROLLBACK;
SELECT id_conta, saldo FROM conta_corrente ORDER BY id_conta;

DROP TABLE tabela_temporaria PURGE;
UPDATE conta_corrente SET saldo = 800 WHERE id_conta = 1;
COMMIT;


-- ----------------------------------------------------------------------------
-- PASSO 5. SAVEPOINT
-- ----------------------------------------------------------------------------
UPDATE conta_corrente SET saldo = saldo - 100 WHERE id_conta = 1;
SAVEPOINT apos_debito;
-- valor errado!
UPDATE conta_corrente SET saldo = saldo + 1000 WHERE id_conta = 2;
ROLLBACK TO SAVEPOINT apos_debito;
UPDATE conta_corrente SET saldo = saldo + 100 WHERE id_conta = 2;
COMMIT;
SELECT id_conta, saldo FROM conta_corrente ORDER BY id_conta;


-- ============================================================================
-- DAQUI EM DIANTE: DUAS SESSOES. Abra dois terminais com
--   docker exec -it bd-oracle-xe sqlplus bd_aluno/bd_aluno_pwd@//localhost/XEPDB1
-- e antes de cada passo rode, em qualquer uma delas, o "reset" (duas linhas):
--   UPDATE conta_corrente SET saldo = CASE id_conta WHEN 1 THEN 1000 ELSE 500 END;
--   COMMIT;
-- ============================================================================

-- ----------------------------------------------------------------------------
-- PASSO 6. NAO EXISTE LEITURA SUJA (e nem existe READ UNCOMMITTED)
-- ----------------------------------------------------------------------------
-- [A] UPDATE conta_corrente SET saldo = 0 WHERE id_conta = 1;
-- [B] SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;   -> ORA-02179
-- [B] SELECT saldo FROM conta_corrente WHERE id_conta = 1;  -> 1000 (versao do undo)
-- [A] ROLLBACK;

-- ----------------------------------------------------------------------------
-- PASSO 7. READ COMMITTED x SERIALIZABLE x READ ONLY
-- ----------------------------------------------------------------------------
-- 7a. READ COMMITTED (padrao): leitura nao repetivel
-- [B] SELECT saldo FROM conta_corrente WHERE id_conta = 1;  -> 1000
-- [A] UPDATE conta_corrente SET saldo = 900 WHERE id_conta = 1;
-- [A] COMMIT;
-- [B] SELECT saldo FROM conta_corrente WHERE id_conta = 1;  ->  900
-- [B] COMMIT;
--
-- 7b. SERIALIZABLE: snapshot fixo (SET TRANSACTION tem de ser o 1o comando)
-- [B] SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;
-- [B] SELECT saldo FROM conta_corrente WHERE id_conta = 1;  ->  900
-- [A] UPDATE conta_corrente SET saldo = 800 WHERE id_conta = 1;
-- [A] COMMIT;
-- [B] SELECT saldo FROM conta_corrente WHERE id_conta = 1;  ->  900 (!)
-- [B] COMMIT;
-- [B] SELECT saldo FROM conta_corrente WHERE id_conta = 1;  ->  800
--
-- 7c. READ ONLY: snapshot fixo e nenhuma escrita
-- [B] SET TRANSACTION READ ONLY;
-- [B] UPDATE conta_corrente SET saldo = 1 WHERE id_conta = 1;  -> ORA-01456
-- [B] ROLLBACK;

-- ----------------------------------------------------------------------------
-- PASSO 8. ATUALIZACAO PERDIDA (lost update) e SELECT ... FOR UPDATE
-- ----------------------------------------------------------------------------
-- 8a. O problema
-- [A] SELECT saldo FROM conta_corrente WHERE id_conta = 1;      -> 1000 (saca 100)
-- [B] SELECT saldo FROM conta_corrente WHERE id_conta = 1;      -> 1000 (saca 50)
-- [A] UPDATE conta_corrente SET saldo = 900 WHERE id_conta = 1;
-- [B] UPDATE conta_corrente SET saldo = 950 WHERE id_conta = 1;  -> FICA ESPERANDO
-- [A] COMMIT;                                                    -> B e liberado
-- [B] COMMIT;
-- [B] SELECT saldo FROM conta_corrente WHERE id_conta = 1;      -> 950 (saque de A sumiu)
--
-- 8b. A correcao (reset antes)
-- [A] SELECT saldo FROM conta_corrente WHERE id_conta = 1 FOR UPDATE;  -> 1000
-- [B] SELECT saldo FROM conta_corrente WHERE id_conta = 1 FOR UPDATE;  -> FICA ESPERANDO
-- [A] UPDATE conta_corrente SET saldo = 900 WHERE id_conta = 1;
-- [A] COMMIT;                                              -> B recebe 900
-- [B] UPDATE conta_corrente SET saldo = 850 WHERE id_conta = 1;
-- [B] COMMIT;                                              -> saldo final 850

-- ----------------------------------------------------------------------------
-- PASSO 9. CONFLITO DE ESCRITA EM SERIALIZABLE (ORA-08177)
-- ----------------------------------------------------------------------------
-- [A] SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;
-- [A] SELECT saldo FROM conta_corrente WHERE id_conta = 1;      -> 1000
-- [B] SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;
-- [B] SELECT saldo FROM conta_corrente WHERE id_conta = 2;      ->  500
-- [A] UPDATE conta_corrente SET saldo = saldo - 50 WHERE id_conta = 1;
-- [B] UPDATE conta_corrente SET saldo = saldo + 50 WHERE id_conta = 1;  -> FICA ESPERANDO
-- [A] COMMIT;
-- [B] -> ORA-08177: can't serialize access for this transaction (no UPDATE)
-- [B] ROLLBACK;

-- ----------------------------------------------------------------------------
-- PASSO 10. WRITE SKEW: o SERIALIZABLE do Oracle DEIXA PASSAR
-- ----------------------------------------------------------------------------
-- Regra da familia: a soma dos saldos precisa ficar >= 500.
-- [A] SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;
-- [A] SELECT SUM(saldo) FROM conta_corrente;            -> 1500 (pode sacar 600)
-- [B] SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;
-- [B] SELECT SUM(saldo) FROM conta_corrente;            -> 1500 (pode sacar 450)
-- [A] UPDATE conta_corrente SET saldo = saldo - 600 WHERE id_conta = 1;
-- [B] UPDATE conta_corrente SET saldo = saldo - 450 WHERE id_conta = 2;
-- [A] COMMIT;
-- [B] COMMIT;                                           -> confirma (sem erro!)
-- [A] SELECT SUM(saldo) FROM conta_corrente;            -> 450 (regra violada)

-- ----------------------------------------------------------------------------
-- PASSO 11. DEADLOCK (ORA-00060)
-- ----------------------------------------------------------------------------
-- [A] UPDATE conta_corrente SET saldo = saldo - 10 WHERE id_conta = 1;
-- [B] UPDATE conta_corrente SET saldo = saldo - 20 WHERE id_conta = 2;
-- [A] UPDATE conta_corrente SET saldo = saldo + 10 WHERE id_conta = 2;  -> espera B
-- [B] UPDATE conta_corrente SET saldo = saldo + 20 WHERE id_conta = 1;  -> espera A: CICLO
--     ~3 s depois, UMA delas recebe ORA-00060 (so o comando dela e desfeito)
-- [vitima] ROLLBACK;   -> libera a outra sessao
-- [outra]  COMMIT;

-- ----------------------------------------------------------------------------
-- PASSO 12. NOWAIT, WAIT n, SKIP LOCKED E MONITORAMENTO
-- ----------------------------------------------------------------------------
-- Uma vez so, como SYSTEM, para o bd_aluno poder ler as views V$:
--   docker exec -it bd-oracle-xe sqlplus system/bd_admin_pwd@//localhost/XEPDB1
--   GRANT SELECT_CATALOG_ROLE TO bd_aluno;
-- (reconecte o bd_aluno depois do GRANT)
--
-- [A] SELECT saldo FROM conta_corrente WHERE id_conta = 1 FOR UPDATE;
-- [B] SELECT saldo FROM conta_corrente WHERE id_conta = 1 FOR UPDATE NOWAIT;  -> ORA-00054
-- [B] SELECT saldo FROM conta_corrente WHERE id_conta = 1 FOR UPDATE WAIT 3;  -> ORA-30006
-- [B] SELECT id_conta, saldo FROM conta_corrente FOR UPDATE SKIP LOCKED;     -> so a conta 2
-- [B] ROLLBACK;
-- [B] UPDATE conta_corrente SET saldo = saldo WHERE id_conta = 1;            -> FICA ESPERANDO
-- [C] (terceiro terminal) consultas abaixo
-- [A] COMMIT;

-- Quem esta bloqueado por quem:
SELECT sid, username, status, blocking_session, event, seconds_in_wait
  FROM v$session
 WHERE username = USER AND sid <> SYS_CONTEXT('USERENV', 'SID')
 ORDER BY sid;

-- Tabelas com linhas travadas e a sessao que trava:
SELECT l.session_id AS sid, o.object_name, l.locked_mode
  FROM v$locked_object l
  JOIN user_objects o ON o.object_id = l.object_id
 ORDER BY l.session_id;
