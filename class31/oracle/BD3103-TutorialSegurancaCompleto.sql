-- ============================================================================
-- BD3103-TutorialSegurancaCompleto.sql (Oracle)
-- Aula 31 - Seguranca - TODOS os passos do tutorial de uma vez (gabarito)
-- Prof. Giovane Barcelos
--
-- Use para conferir o seu trabalho ou para recuperar o ambiente se algo deu
-- errado. Executa a base (BD3102) antes, para partir do zero (como SYSTEM):
--   docker exec -i oracle sqlplus -s system/oracle@localhost/FREEPDB1 < BD3102-TutorialSegurancaBase.sql
--   docker exec -i oracle sqlplus -s system/oracle@localhost/FREEPDB1 < BD3103-TutorialSegurancaCompleto.sql
--
-- Senhas de LABORATORIO, so para o tutorial: nunca guarde senha real em script.
-- ============================================================================
SET FEEDBACK ON
SET LINESIZE 120
COLUMN grantee FORMAT A16
COLUMN table_name FORMAT A20
COLUMN privilege FORMAT A18

-- Passo B2: roles (perfis) e usuarios
CREATE ROLE vet_admin;
CREATE ROLE vet_veterinario;
CREATE ROLE vet_recepcao;
CREATE USER gestor_rui IDENTIFIED BY "Rui_2026";
CREATE USER dra_ana    IDENTIFIED BY "Ana_2026";
CREATE USER dr_carlos  IDENTIFIED BY "Carlos_2026";
CREATE USER recep_bia  IDENTIFIED BY "Bia_2026";
GRANT vet_admin       TO gestor_rui;
GRANT vet_veterinario TO dra_ana, dr_carlos;
GRANT vet_recepcao    TO recep_bia;

-- Passo B3: sem CREATE SESSION ninguem entra (ORA-01045)
GRANT CREATE SESSION TO vet_admin, vet_veterinario, vet_recepcao;

-- Passo B4: privilegios de objeto (menor privilegio)
GRANT SELECT ON clinica.animais      TO vet_veterinario;
GRANT SELECT ON clinica.veterinarios TO vet_veterinario;
GRANT SELECT, INSERT ON clinica.consultas TO vet_veterinario;
GRANT UPDATE (diagnostico) ON clinica.consultas TO vet_veterinario;

GRANT SELECT ON clinica.animais      TO vet_recepcao;
GRANT SELECT ON clinica.veterinarios TO vet_recepcao;
GRANT SELECT, INSERT ON clinica.agendamentos TO vet_recepcao;

-- Passo B5: privilegio de SCHEMA (Oracle 23ai): vale para tabelas futuras
GRANT SELECT ANY TABLE, INSERT ANY TABLE, UPDATE ANY TABLE, DELETE ANY TABLE
   ON SCHEMA clinica TO vet_admin;

-- Passo B6: view de seguranca com CPF mascarado para a recepcao
CREATE OR REPLACE VIEW clinica.vw_tutores_recepcao AS
SELECT id, nome, telefone,
       '***.***.***-' || SUBSTR(cpf, -2) AS cpf_mascarado
  FROM clinica.tutores;
GRANT SELECT ON clinica.vw_tutores_recepcao TO vet_recepcao;

-- Passo B7: VPD - cada veterinario so ve (e so grava) as proprias consultas
CREATE OR REPLACE FUNCTION clinica.fn_politica_consultas (
    p_schema IN VARCHAR2,
    p_objeto IN VARCHAR2
) RETURN VARCHAR2
IS
BEGIN
  -- o texto devolvido e acrescentado como WHERE em toda consulta na tabela
  RETURN 'veterinario_id = (SELECT v.id FROM clinica.veterinarios v '
      || 'WHERE v.login = SYS_CONTEXT(''USERENV'', ''SESSION_USER''))';
END;
/

BEGIN
  DBMS_RLS.ADD_POLICY(
    object_schema   => 'CLINICA',
    object_name     => 'CONSULTAS',
    policy_name     => 'CONSULTAS_DO_VETERINARIO',
    function_schema => 'CLINICA',
    policy_function => 'FN_POLITICA_CONSULTAS',
    statement_types => 'SELECT, INSERT, UPDATE, DELETE',
    update_check    => TRUE);          -- equivalente ao WITH CHECK do PostgreSQL
END;
/

-- O gestor enxerga tudo: isencao de VPD (equivalente ao BYPASSRLS)
GRANT EXEMPT ACCESS POLICY TO vet_admin;

-- Auditoria (Passo B8)
SELECT grantee, table_name, privilege
  FROM dba_tab_privs
 WHERE owner = 'CLINICA' AND grantee LIKE 'VET%'
 ORDER BY grantee, table_name, privilege;
EXIT
