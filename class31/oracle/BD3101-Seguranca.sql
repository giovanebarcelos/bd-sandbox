-- BD3101-Seguranca.sql
-- Oracle: Seguranca - Usuarios, Roles, Grants e Views
-- UA12 - Aula 31 - Conectividade, Seguranca e Projeto Final

-- ============================================================
-- PARTE 1: CRIACAO DE USUARIOS
-- ============================================================
CREATE USER app_user IDENTIFIED BY "SenhaSegura123!";
CREATE USER relatorio_user IDENTIFIED BY "SenhaSegura456!";

-- ============================================================
-- PARTE 2: ROLES
-- ============================================================
CREATE ROLE role_leitura;
CREATE ROLE role_escrita;
CREATE ROLE role_admin;

-- ============================================================
-- PARTE 3: GRANT DE PRIVILEGIOS DE SISTEMA
-- ============================================================
GRANT CREATE SESSION TO role_leitura;
GRANT CREATE SESSION TO role_escrita;
GRANT CREATE SESSION, CREATE TABLE, CREATE VIEW TO role_admin;

-- ============================================================
-- PARTE 4: GRANT DE PRIVILEGIOS DE OBJETO
-- ============================================================
GRANT SELECT ON aluno TO role_leitura;
GRANT SELECT ON professor TO role_leitura;
GRANT SELECT ON curso TO role_leitura;

GRANT INSERT, UPDATE, DELETE ON aluno TO role_escrita;
GRANT INSERT, UPDATE, DELETE ON matricula TO role_escrita;
GRANT SELECT ON aluno TO role_escrita;
GRANT SELECT ON matricula TO role_escrita;

GRANT ALL ON aluno TO role_admin;
GRANT ALL ON professor TO role_admin;
GRANT ALL ON turma TO role_admin;

-- ============================================================
-- PARTE 5: ATRIBUICAO DE ROLES A USUARIOS
-- ============================================================
GRANT role_leitura TO relatorio_user;
GRANT role_escrita TO app_user;
GRANT role_admin TO app_user;

-- ============================================================
-- PARTE 6: REVOKE
-- ============================================================
-- REVOKE INSERT ON aluno FROM role_escrita;
-- REVOKE role_admin FROM app_user;

-- ============================================================
-- PARTE 7: CONSULTAR PRIVILEGIOS
-- ============================================================
SELECT * FROM USER_ROLE_PRIVS;
SELECT * FROM USER_TAB_PRIVS WHERE grantee = 'ROLE_LEITURA';
SELECT * FROM USER_SYS_PRIVS;

-- ============================================================
-- PARTE 8: VIEW DE SEGURANCA
-- ============================================================
CREATE VIEW vw_aluno_seguro AS
SELECT aluno_id, nome, email
  FROM aluno;

GRANT SELECT ON vw_aluno_seguro TO role_leitura;
