-- BD3101-Seguranca.sql
-- PostgreSQL: Seguranca - Usuarios, Roles, Grants e Views
-- UA12 - Aula 31 - Conectividade, Seguranca e Projeto Final

-- ============================================================
-- PARTE 1: CRIACAO DE ROLES (PostgreSQL trata usuarios como roles)
-- ============================================================
CREATE ROLE app_user WITH LOGIN PASSWORD 'SenhaSegura123!';
CREATE ROLE relatorio_user WITH LOGIN PASSWORD 'SenhaSegura456!';

-- ============================================================
-- PARTE 2: ROLES DE GRUPO
-- ============================================================
CREATE ROLE role_leitura;
CREATE ROLE role_escrita;
CREATE ROLE role_admin;

-- ============================================================
-- PARTE 3: GRANT DE PRIVILEGIOS
-- ============================================================
GRANT CONNECT ON DATABASE escola TO role_leitura;
GRANT CONNECT ON DATABASE escola TO role_escrita;
GRANT CONNECT, CREATE ON DATABASE escola TO role_admin;

GRANT USAGE ON SCHEMA public TO role_leitura, role_escrita, role_admin;

-- ============================================================
-- PARTE 4: GRANT DE PRIVILEGIOS DE OBJETO
-- ============================================================
GRANT SELECT ON aluno TO role_leitura;
GRANT SELECT ON professor TO role_leitura;
GRANT SELECT ON curso TO role_leitura;

GRANT INSERT, UPDATE, DELETE ON aluno TO role_escrita;
GRANT INSERT, UPDATE, DELETE ON matricula TO role_escrita;
GRANT SELECT ON aluno, matricula TO role_escrita;

GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO role_admin;

-- ============================================================
-- PARTE 5: ATRIBUICAO DE ROLES
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
SELECT * FROM information_schema.role_table_grants WHERE grantee = 'role_leitura';
SELECT * FROM information_schema.table_privileges WHERE grantee = 'role_escrita';
SELECT rolname, rolsuper, rolinherit FROM pg_roles;

-- ============================================================
-- PARTE 8: VIEW DE SEGURANCA
-- ============================================================
CREATE VIEW vw_aluno_seguro AS
SELECT aluno_id, nome, email
  FROM aluno;

GRANT SELECT ON vw_aluno_seguro TO role_leitura;

-- ============================================================
-- PARTE 9: ROW-LEVEL SECURITY (RLS) - PostgreSQL
-- ============================================================
ALTER TABLE aluno ENABLE ROW LEVEL SECURITY;

CREATE POLICY aluno_self_access ON aluno
    FOR SELECT
    USING (current_user = 'app_user');
