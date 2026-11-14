-- Observações importantes:
-- Esse script deve ser executado pelo usuário chinook

CREATE OR REPLACE PROCEDURE remover_indices_tabela(p_tabela text)
LANGUAGE plpgsql
AS $$
DECLARE
    v_oid oid;
    r     record;
BEGIN
    SELECT c.oid INTO v_oid
      FROM pg_class c
      JOIN pg_namespace n ON n.oid = c.relnamespace
     WHERE n.nspname = 'public'
       AND c.relkind = 'r'
       AND lower(c.relname) = lower(p_tabela);

    -- Remove índices vinculados a constraints (PK, UNIQUE, EXCLUDE)
    FOR r IN
        SELECT conname
          FROM pg_constraint
         WHERE conrelid = v_oid
           AND contype IN ('p', 'u', 'x')
    LOOP
        EXECUTE format('ALTER TABLE public.%I DROP CONSTRAINT %I CASCADE', lower(p_tabela), r.conname);
    END LOOP;

    -- Remove índices comuns
    FOR r IN
        SELECT i.relname AS indice
          FROM pg_index ix
          JOIN pg_class i ON i.oid = ix.indexrelid
         WHERE ix.indrelid = v_oid
           AND NOT EXISTS (
               SELECT 1 FROM pg_constraint con WHERE con.conindid = i.oid
           )
    LOOP
        EXECUTE format('DROP INDEX public.%I', r.indice);
    END LOOP;
END;
$$;



