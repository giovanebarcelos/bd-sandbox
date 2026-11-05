-- ============================================================================
-- BD3103-TutorialSegurancaCompleto.sql (PostgreSQL)
-- Aula 31 - Seguranca - TODOS os passos do tutorial de uma vez (gabarito)
-- Prof. Giovane Barcelos
--
-- Use para conferir o seu trabalho ou para recuperar o ambiente se algo deu
-- errado. Executa a base (BD3102) antes, para partir do zero:
--   docker exec -i postgres psql -U postgres < BD3102-TutorialSegurancaBase.sql
--   docker exec -i postgres psql -U postgres < BD3103-TutorialSegurancaCompleto.sql
--
-- Senhas de LABORATORIO, so para o tutorial: nunca guarde senha real em script.
-- ============================================================================
\c vetcare postgres

-- Passo A2: roles de grupo (sem LOGIN) e usuarios (com LOGIN)
CREATE ROLE vet_admin NOLOGIN;
CREATE ROLE vet_veterinario NOLOGIN;
CREATE ROLE vet_recepcao NOLOGIN;
CREATE ROLE gestor_rui LOGIN PASSWORD 'Rui_2026'    IN ROLE vet_admin;
CREATE ROLE dra_ana    LOGIN PASSWORD 'Ana_2026'    IN ROLE vet_veterinario;
CREATE ROLE dr_carlos  LOGIN PASSWORD 'Carlos_2026' IN ROLE vet_veterinario;
CREATE ROLE recep_bia  LOGIN PASSWORD 'Bia_2026'    IN ROLE vet_recepcao
       CONNECTION LIMIT 2 VALID UNTIL '2027-12-31';

-- Passo A3: as tres concessoes em cascata (banco -> schema -> tabela)
GRANT CONNECT ON DATABASE vetcare TO vet_admin, vet_veterinario, vet_recepcao;
GRANT USAGE ON SCHEMA clinica TO vet_admin, vet_veterinario, vet_recepcao;

-- Passo A4: privilegios de cada perfil (menor privilegio)
GRANT SELECT ON clinica.animais, clinica.veterinarios TO vet_veterinario;
GRANT SELECT, INSERT ON clinica.consultas TO vet_veterinario;
GRANT UPDATE (diagnostico) ON clinica.consultas TO vet_veterinario;
GRANT SELECT (id, nome, telefone) ON clinica.tutores TO vet_veterinario;

GRANT SELECT ON clinica.animais, clinica.veterinarios TO vet_recepcao;
GRANT SELECT, INSERT ON clinica.agendamentos TO vet_recepcao;

GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA clinica TO vet_admin;

-- Passo A5: view de seguranca com CPF mascarado para a recepcao
CREATE VIEW clinica.vw_tutores_recepcao AS
SELECT id, nome, telefone,
       '***.***.***-' || right(cpf, 2) AS cpf_mascarado
  FROM clinica.tutores;
GRANT SELECT ON clinica.vw_tutores_recepcao TO vet_recepcao;

-- Passo A6: Row-Level Security - cada veterinario so ve as proprias consultas
ALTER TABLE clinica.consultas ENABLE ROW LEVEL SECURITY;

CREATE POLICY consultas_do_veterinario ON clinica.consultas
    FOR ALL TO vet_veterinario
    USING      (veterinario_id = (SELECT id FROM clinica.veterinarios WHERE login = current_user))
    WITH CHECK (veterinario_id = (SELECT id FROM clinica.veterinarios WHERE login = current_user));

CREATE POLICY consultas_admin ON clinica.consultas
    FOR ALL TO vet_admin
    USING (true) WITH CHECK (true);

-- Passo A9: tabelas criadas no futuro ja nascem com os privilegios do admin
ALTER DEFAULT PRIVILEGES IN SCHEMA clinica
    GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO vet_admin;

-- Auditoria (Passo A7)
SELECT grantee, table_name,
       string_agg(privilege_type, ', ' ORDER BY privilege_type) AS privilegios
  FROM information_schema.role_table_grants
 WHERE table_schema = 'clinica' AND grantee LIKE 'vet_%'
 GROUP BY grantee, table_name
 ORDER BY grantee, table_name;
