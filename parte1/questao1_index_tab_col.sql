-- Observações:
-- Esse script deve ser executado pelo usuário chinook

SELECT
    i.relname  AS indice,
    t.relname  AS tabela,
    a.attname  AS coluna_indexada
FROM pg_index ix
JOIN pg_class i      ON i.oid = ix.indexrelid
JOIN pg_class t      ON t.oid = ix.indrelid
JOIN pg_namespace n  ON n.oid = t.relnamespace
CROSS JOIN LATERAL unnest(ix.indkey) WITH ORDINALITY AS k(attnum, pos)
JOIN pg_attribute a  ON a.attrelid = t.oid
                    AND a.attnum   = k.attnum
WHERE n.nspname = 'public'
ORDER BY t.relname, i.relname, k.pos;