-- Observações:
-- Esse script deve ser executado pelo usuário chinook
-- Uso: SELECT * FROM gerar_ddl('public');

CREATE OR REPLACE FUNCTION gerar_ddl(p_esquema text DEFAULT 'public')
RETURNS SETOF text
LANGUAGE plpgsql
AS $$
DECLARE
    v_tabela     record;
    v_coluna     record;
    v_constraint record;
    v_tipo       text;
    v_linhas     text[];
BEGIN
    FOR v_tabela IN
        WITH RECURSIVE dependencias AS (
            SELECT DISTINCT fk.table_name AS filha, pai.table_name AS pai
            FROM information_schema.table_constraints fk
            JOIN information_schema.referential_constraints rc
              ON rc.constraint_schema = fk.constraint_schema
             AND rc.constraint_name   = fk.constraint_name
            JOIN information_schema.table_constraints pai
              ON pai.constraint_schema = rc.unique_constraint_schema
             AND pai.constraint_name   = rc.unique_constraint_name
            WHERE fk.table_schema    = p_esquema
              AND fk.constraint_type = 'FOREIGN KEY'
              AND fk.table_name     <> pai.table_name
        ),
        niveis AS (
            SELECT t.table_name, 0 AS nivel
            FROM information_schema.tables t
            WHERE t.table_schema = p_esquema
              AND t.table_type   = 'BASE TABLE'
            UNION ALL
            SELECT d.filha, n.nivel + 1
            FROM niveis n
            JOIN dependencias d ON d.pai = n.table_name
            WHERE n.nivel < 100  -- Uma proteção contra ciclos de FKs!!!
        )
        SELECT table_name, max(nivel) AS nivel
        FROM niveis
        GROUP BY table_name
        ORDER BY nivel, table_name
    LOOP
        v_linhas := ARRAY[]::text[];

        FOR v_coluna IN
            SELECT column_name, data_type, udt_name, character_maximum_length,
                   numeric_precision, numeric_scale, is_nullable
            FROM information_schema.columns
            WHERE table_schema = p_esquema
              AND table_name   = v_tabela.table_name
            ORDER BY ordinal_position
        LOOP
            v_tipo := CASE
                WHEN v_coluna.data_type = 'character varying' THEN
                    'varchar' || coalesce('(' || v_coluna.character_maximum_length || ')', '')
                WHEN v_coluna.data_type = 'character' THEN
                    'char' || coalesce('(' || v_coluna.character_maximum_length || ')', '')
                WHEN v_coluna.data_type = 'numeric' AND v_coluna.numeric_precision IS NOT NULL THEN
                    format('numeric(%s,%s)', v_coluna.numeric_precision, v_coluna.numeric_scale)
                WHEN v_coluna.data_type = 'USER-DEFINED' THEN
                    v_coluna.udt_name
                ELSE
                    v_coluna.data_type
            END;

            v_linhas := v_linhas || format('    %I %s%s',
                                           v_coluna.column_name,
                                           v_tipo,
                                           CASE WHEN v_coluna.is_nullable = 'NO' THEN ' NOT NULL' ELSE '' END);
        END LOOP;

        FOR v_constraint IN
            SELECT tc.constraint_name,
                   string_agg(format('%I', kcu.column_name), ', ' ORDER BY kcu.ordinal_position) AS colunas
            FROM information_schema.table_constraints tc
            JOIN information_schema.key_column_usage kcu
              ON kcu.constraint_schema = tc.constraint_schema
             AND kcu.constraint_name   = tc.constraint_name
             AND kcu.table_name        = tc.table_name
            WHERE tc.table_schema    = p_esquema
              AND tc.table_name      = v_tabela.table_name
              AND tc.constraint_type = 'PRIMARY KEY'
            GROUP BY tc.constraint_name
        LOOP
            v_linhas := v_linhas || format('    CONSTRAINT %I PRIMARY KEY (%s)',
                                           v_constraint.constraint_name,
                                           v_constraint.colunas);
        END LOOP;

        FOR v_constraint IN
            SELECT tc.constraint_name,
                   pai.table_name AS tabela_pai,
                   string_agg(format('%I', kcu.column_name), ', ' ORDER BY kcu.ordinal_position) AS colunas,
                   string_agg(format('%I', pai.column_name), ', ' ORDER BY kcu.ordinal_position) AS colunas_pai
            FROM information_schema.table_constraints tc
            JOIN information_schema.key_column_usage kcu
              ON kcu.constraint_schema = tc.constraint_schema
             AND kcu.constraint_name   = tc.constraint_name
             AND kcu.table_name        = tc.table_name
            JOIN information_schema.referential_constraints rc
              ON rc.constraint_schema = tc.constraint_schema
             AND rc.constraint_name   = tc.constraint_name
            JOIN information_schema.key_column_usage pai
              ON pai.constraint_schema = rc.unique_constraint_schema
             AND pai.constraint_name   = rc.unique_constraint_name
             AND pai.ordinal_position  = kcu.position_in_unique_constraint
            WHERE tc.table_schema    = p_esquema
              AND tc.table_name      = v_tabela.table_name
              AND tc.constraint_type = 'FOREIGN KEY'
            GROUP BY tc.constraint_name, pai.table_name
            ORDER BY tc.constraint_name
        LOOP
            v_linhas := v_linhas || format('    CONSTRAINT %I FOREIGN KEY (%s) REFERENCES %I (%s)',
                                           v_constraint.constraint_name,
                                           v_constraint.colunas,
                                           v_constraint.tabela_pai,
                                           v_constraint.colunas_pai);
        END LOOP;

        RETURN NEXT format(E'CREATE TABLE %I (\n%s\n);\n',
                           v_tabela.table_name,
                           array_to_string(v_linhas, E',\n'));
    END LOOP;
END;
$$;
