-- Observações:
-- Esse script deve ser executado pelo usuário chinook, depois de questao3_criar_usuario e questao3_procedures
-- Mecanismo de permissões: o usuário chinook_app consulta qualquer tabela, mas só altera os dados
-- das regras RS1 a RS4 chamando os procedimentos de questao3_procedures.


-- 1) Acesso ao banco e ao schema
GRANT CONNECT ON DATABASE chinook TO chinook_app;
GRANT USAGE ON SCHEMA public TO chinook_app;


-- 2) Tabelas: somente leitura. Nenhum INSERT, UPDATE, DELETE ou TRUNCATE direto.
REVOKE ALL    ON ALL TABLES IN SCHEMA public FROM chinook_app;
GRANT  SELECT ON ALL TABLES IN SCHEMA public TO   chinook_app;


-- 3) Procedimentos: no PostgreSQL toda function/procedure nasce com EXECUTE liberado para PUBLIC.
-- Como os procedimentos são SECURITY DEFINER (rodam com os privilégios do chinook), deixar isso
-- aberto daria a qualquer usuário do banco o poder de alterar os dados. Por isso o EXECUTE é
-- retirado de PUBLIC e concedido só ao chinook_app.
REVOKE EXECUTE ON PROCEDURE
    cadastrar_funcionario(INT, VARCHAR, VARCHAR, VARCHAR, INT, NUMERIC),
    alterar_salario_funcionario(INT, NUMERIC),
    alterar_supervisor_funcionario(INT, INT),
    cadastrar_cliente(INT, VARCHAR, VARCHAR, VARCHAR, INT),
    alterar_representante_cliente(INT, INT),
    alterar_cargo_funcionario(INT, VARCHAR),
    criar_fatura(INT, INT),
    adicionar_item_fatura(INT, INT, INT),
    adicionar_faixa_playlist(INT, INT)
FROM PUBLIC;

GRANT EXECUTE ON PROCEDURE
    cadastrar_funcionario(INT, VARCHAR, VARCHAR, VARCHAR, INT, NUMERIC),
    alterar_salario_funcionario(INT, NUMERIC),
    alterar_supervisor_funcionario(INT, INT),
    cadastrar_cliente(INT, VARCHAR, VARCHAR, VARCHAR, INT),
    alterar_representante_cliente(INT, INT),
    alterar_cargo_funcionario(INT, VARCHAR),
    criar_fatura(INT, INT),
    adicionar_item_fatura(INT, INT, INT),
    adicionar_faixa_playlist(INT, INT)
TO chinook_app;


-- 4) Conferência dos privilégios do chinook_app nas tabelas envolvidas nas regras
SELECT t.tabela,
       has_table_privilege('chinook_app', t.tabela, 'SELECT') AS pode_select,
       has_table_privilege('chinook_app', t.tabela, 'INSERT') AS pode_insert,
       has_table_privilege('chinook_app', t.tabela, 'UPDATE') AS pode_update,
       has_table_privilege('chinook_app', t.tabela, 'DELETE') AS pode_delete
  FROM (VALUES ('employee'), ('customer'), ('invoice'), ('invoice_line'), ('playlist_track')) AS t(tabela);
-- ESPERADO: pode_select = t e as outras três colunas = f nas 5 tabelas

-- 5) Conferência dos procedimentos: quem pode executar cada um.
-- proacl lista os privilégios; "=X/chinook" (sem nome antes do =) significaria EXECUTE para PUBLIC.
SELECT p.proname AS procedimento,
       has_function_privilege('chinook_app', p.oid, 'EXECUTE') AS chinook_app_executa,
       p.proacl AS privilegios
  FROM pg_proc p
  JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname = 'public'
   AND p.prokind = 'p'
   AND p.prosecdef          -- só os SECURITY DEFINER (os da Q3)
 ORDER BY 1;
-- ESPERADO: 9 linhas, chinook_app_executa = t e privilegios = {chinook=X/chinook,chinook_app=X/chinook}
