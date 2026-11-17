-- Observações:
-- Esse script deve ser executado pelo usuário chinook

-- Teste executado em transação (BEGIN ... ROLLBACK) para comprovar a remoção dos índices
-- sem apagar definitivamente a PK e as FKs vinculadas, preservando o esquema para as demais questões.
BEGIN;
CALL remover_indices_tabela('track');
\d track
ROLLBACK;
