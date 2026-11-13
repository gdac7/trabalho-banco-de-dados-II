-- Observações importantes:
-- Esse script deve ser executado pelo usuário postgres (superusuário)

DROP DATABASE IF EXISTS chinook WITH (FORCE);
DROP ROLE IF EXISTS chinook;

CREATE ROLE chinook LOGIN PASSWORD 'chinook';
CREATE DATABASE chinook OWNER chinook;

\c chinook
ALTER SCHEMA public OWNER TO chinook;
