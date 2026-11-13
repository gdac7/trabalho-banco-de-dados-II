-- Observações importantes:
-- Esse script deve ser executado pelo usuário chinook

DROP FUNCTION IF EXISTS validar_estado;
DROP FUNCTION IF EXISTS validar_transicao;

CREATE OR REPLACE FUNCTION validar_estado(tabela text, coluna text, estado text)
RETURNS integer AS $$
BEGIN
    IF NOT EXISTS(
		SELECT 1 
		FROM tabela_estado
		WHERE nome_tabela = tabela AND nome_coluna = coluna AND nome_estado = estado)
		THEN
			return 0;
		END IF;
		RETURN 1;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION validar_transicao(
    tabela text, coluna text, origem text, destino text)
RETURNS integer AS $$
BEGIN
    -- INSERT (não existe estado antigo): o estado novo precisa ser inicial
    IF origem IS NULL THEN
        IF EXISTS (SELECT 1 FROM tabela_estado
                   WHERE nome_tabela = tabela
                     AND nome_coluna = coluna
                     AND nome_estado = destino
                     AND tipo_estado = 'inicial') THEN
            RETURN 1;
        END IF;
        RETURN 0;
    END IF;

    -- UPDATE sem mudar o estado: permitido
    IF origem = destino THEN
        RETURN 1;
    END IF;

    -- UPDATE com mudança: a transição precisa existir
    IF EXISTS (SELECT 1 FROM tabela_transicao
               WHERE nome_tabela = tabela
                 AND nome_coluna = coluna
                 AND estado_origem = origem
                 AND estado_destino = destino) THEN
        RETURN 1;
    END IF;
    RETURN 0;
	
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION trg_validar_dte()
RETURNS trigger AS $$
DECLARE
    v_coluna text := TG_ARGV[0];
    v_novo   text := to_jsonb(NEW) ->> v_coluna;  -- lê a coluna passada ao trigger (TG_ARGV[0]) pelo nome
    v_antigo text;
BEGIN
    IF validar_estado(TG_TABLE_NAME, v_coluna, v_novo) = 0 THEN
        RAISE EXCEPTION 'Estado "%" não existe para %.%', v_novo, TG_TABLE_NAME, v_coluna;
    END IF;

    IF TG_OP = 'UPDATE' THEN
        v_antigo := to_jsonb(OLD) ->> v_coluna;
    END IF;

    IF validar_transicao(TG_TABLE_NAME, v_coluna, v_antigo, v_novo) = 0 THEN
        RAISE EXCEPTION 'Transição inválida em %.%: % -> %',
            TG_TABLE_NAME, v_coluna, v_antigo, v_novo;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;
