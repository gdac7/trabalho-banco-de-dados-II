-- Observações:
-- Esse script deve ser executado pelo usuário postgres (superusuário), conectado ao banco chinook:
--   psql -h localhost -U postgres -d chinook -f parte2/questao3_criar_usuario.sql
-- O usuário chinook não tem permissão para criar usuários (CREATEROLE), por isso este passo fica separado.
-- Parte 2 - Questão 3 (PostgreSQL)

-- Recria o usuário do zero, para o script poder ser executado mais de uma vez.
-- DROP OWNED remove os privilégios concedidos a ele neste banco; sem isso o DROP ROLE falha.
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'chinook_app') THEN
        EXECUTE 'DROP OWNED BY chinook_app';
        EXECUTE 'DROP ROLE chinook_app';
    END IF;
END $$;

-- Usuário da aplicação: só vai consultar os dados e chamar os procedimentos da Q3
CREATE ROLE chinook_app LOGIN PASSWORD 'chinook_app';

-- Permite que o usuário chinook faça SET ROLE chinook_app no script de teste,
-- para executar os comandos como o usuário restrito sem precisar de outra conexão.
GRANT chinook_app TO chinook;
