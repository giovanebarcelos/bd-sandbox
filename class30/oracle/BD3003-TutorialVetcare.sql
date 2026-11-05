-- ============================================================================
-- BD3003-TutorialVetcare.sql (Oracle)
-- Aula 30 - Conectividade JDBC e DB-API - preparacao do schema do tutorial
-- Prof. Giovane Barcelos
--
-- Executar como SYSTEM no PDB FREEPDB1 (container "oracle" do A1/DBTools):
--   docker exec -i oracle sqlplus -s system/oracle@localhost/FREEPDB1 < BD3003-TutorialVetcare.sql
-- PowerShell:
--   Get-Content BD3003-TutorialVetcare.sql | docker exec -i oracle sqlplus -s system/oracle@localhost/FREEPDB1
--
-- A tabela fica no schema ALUNO (o usuario de trabalho do DBTools). O usuario
-- APP_USER, usado pelos programas, so pode conectar e LER a tabela; o sinonimo
-- permite escrever "funcionarios" sem o prefixo "aluno.".
-- Pode ser executado de novo: apaga e recria a tabela e o usuario.
-- ============================================================================
SET FEEDBACK ON
SET LINESIZE 120
COLUMN nome FORMAT A20
COLUMN cargo FORMAT A15

DROP USER IF EXISTS app_user CASCADE;
DROP TABLE IF EXISTS aluno.funcionarios PURGE;

CREATE TABLE aluno.funcionarios (
    id       NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nome     VARCHAR2(100) NOT NULL,
    cargo    VARCHAR2(50)  NOT NULL,
    salario  NUMBER(10,2)
);

INSERT INTO aluno.funcionarios (nome, cargo, salario) VALUES ('Ana Souza',    'Veterinario',   6500.00);
INSERT INTO aluno.funcionarios (nome, cargo, salario) VALUES ('Bruno Lima',   'Recepcionista', 2800.00);
INSERT INTO aluno.funcionarios (nome, cargo, salario) VALUES ('Carla Dias',   'Veterinario',   7200.00);
INSERT INTO aluno.funcionarios (nome, cargo, salario) VALUES ('Diego Alves',  'Auxiliar',      2400.00);
INSERT INTO aluno.funcionarios (nome, cargo, salario) VALUES ('Joana D''Arc', 'Veterinario',   6900.00);
COMMIT;

-- Senha de LABORATORIO: em producao ela viria de um cofre de segredos
CREATE USER app_user IDENTIFIED BY "senha_segura";
GRANT CREATE SESSION TO app_user;
GRANT SELECT ON aluno.funcionarios TO app_user;
CREATE SYNONYM app_user.funcionarios FOR aluno.funcionarios;

SELECT id, nome, cargo, salario FROM aluno.funcionarios ORDER BY id;
EXIT
