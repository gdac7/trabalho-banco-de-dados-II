-- Observações:
-- Esse script deve ser executado pelo usuário chinook
-- Parte 2 - Questão 4 (PostgreSQL)
-- Regra: invoice.total = SUM(invoice_line.unit_price * invoice_line.quantity)


-- 1) Toda invoice nasce com total = 0 (as linhas são inseridas depois)
CREATE OR REPLACE FUNCTION fn_bi_invoice_zero()
RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
    NEW.total := 0;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_bi_invoice_zero ON invoice;
CREATE TRIGGER trg_bi_invoice_zero
    BEFORE INSERT ON invoice
    FOR EACH ROW
    EXECUTE FUNCTION fn_bi_invoice_zero();


-- 2) Impede alteração manual do total.
-- pg_trigger_depth() = 1  -> o UPDATE veio direto do usuário
-- pg_trigger_depth() > 1  -> o UPDATE veio de dentro de outro trigger (o de invoice_line)
CREATE OR REPLACE FUNCTION fn_bu_invoice_total()
RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
    IF pg_trigger_depth() = 1 AND NEW.total IS DISTINCT FROM OLD.total THEN
        RAISE EXCEPTION 'ERRO! Impossível alterar o total manualmente'
            USING ERRCODE = 'P0001';
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_bu_invoice_total ON invoice;
CREATE TRIGGER trg_bu_invoice_total
    BEFORE UPDATE OF total ON invoice
    FOR EACH ROW
    EXECUTE FUNCTION fn_bu_invoice_total();


-- 3) Mantém o total em dia a cada INSERT/UPDATE/DELETE em invoice_line
CREATE OR REPLACE FUNCTION fn_aiud_invoice_line()
RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        UPDATE invoice
           SET total = total + (NEW.unit_price * NEW.quantity)
         WHERE invoice_id = NEW.invoice_id;

    ELSIF TG_OP = 'DELETE' THEN
        UPDATE invoice
           SET total = total - (OLD.unit_price * OLD.quantity)
         WHERE invoice_id = OLD.invoice_id;

    ELSE -- UPDATE
        IF OLD.invoice_id = NEW.invoice_id THEN
            UPDATE invoice
               SET total = total - (OLD.unit_price * OLD.quantity)
                                 + (NEW.unit_price * NEW.quantity)
             WHERE invoice_id = NEW.invoice_id;
        ELSE
            -- a linha mudou de invoice: tira da antiga e coloca na nova
            UPDATE invoice
               SET total = total - (OLD.unit_price * OLD.quantity)
             WHERE invoice_id = OLD.invoice_id;

            UPDATE invoice
               SET total = total + (NEW.unit_price * NEW.quantity)
             WHERE invoice_id = NEW.invoice_id;
        END IF;
    END IF;

    RETURN NULL; -- trigger AFTER: o valor de retorno é ignorado
END;
$$;

DROP TRIGGER IF EXISTS trg_aiud_invoice_line ON invoice_line;
CREATE TRIGGER trg_aiud_invoice_line
    AFTER INSERT OR DELETE OR UPDATE OF quantity, unit_price, invoice_id ON invoice_line
    FOR EACH ROW
    EXECUTE FUNCTION fn_aiud_invoice_line();


-- 4) TRUNCATE não dispara triggers FOR EACH ROW: sem este trigger as linhas
-- sumiriam e os totais ficariam desatualizados. Como a tabela fica vazia,
-- todo total passa a ser 0 (o UPDATE vem de dentro de um trigger, então o
-- trigger 2 deixa passar).
CREATE OR REPLACE FUNCTION fn_bt_invoice_line()
RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
    UPDATE invoice
       SET total = 0
     WHERE total <> 0;

    RETURN NULL; -- trigger FOR EACH STATEMENT: o valor de retorno é ignorado
END;
$$;

DROP TRIGGER IF EXISTS trg_bt_invoice_line ON invoice_line;
CREATE TRIGGER trg_bt_invoice_line
    BEFORE TRUNCATE ON invoice_line
    FOR EACH STATEMENT
    EXECUTE FUNCTION fn_bt_invoice_line();
