-- Observações:
-- Esse script deve ser executado pelo usuário chinook

SELECT
    c.conname   AS nome_fk,
    tf.relname  AS tabela_tem_fk,
    af.attname  AS coluna_tem_fk,
    tp.relname  AS tabela_referenciada,
    ap.attname  AS coluna_referenciada
FROM pg_constraint c
JOIN pg_class tf     ON tf.oid = c.conrelid
JOIN pg_class tp     ON tp.oid = c.confrelid
JOIN pg_namespace n  ON n.oid = tf.relnamespace
CROSS JOIN LATERAL unnest(c.conkey, c.confkey) AS k(attnum_filha, attnum_pai)
JOIN pg_attribute af ON af.attrelid = c.conrelid  AND af.attnum = k.attnum_filha
JOIN pg_attribute ap ON ap.attrelid = c.confrelid AND ap.attnum = k.attnum_pai
WHERE c.contype = 'f'
  AND n.nspname = 'public'
ORDER BY tf.relname, c.conname;