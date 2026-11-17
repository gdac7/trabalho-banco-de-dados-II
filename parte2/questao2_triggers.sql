-- Observações:
-- Esse script deve ser executado pelo usuário chinook
-- Parte 2 - Questão 2 (PostgreSQL)

-- Ajuste de esquema para RS1 (compatível com a Q3)
ALTER TABLE employee ADD COLUMN IF NOT EXISTS salary NUMERIC(10,2) CHECK (salary > 0);

UPDATE employee
   SET salary = CASE title
       WHEN 'General Manager'     THEN 20000.00
       WHEN 'Sales Manager'       THEN 12000.00
       WHEN 'IT Manager'          THEN 12000.00
       WHEN 'IT Staff'            THEN  6000.00
       WHEN 'Sales Support Agent' THEN  5000.00
       ELSE 5000.00
   END
 WHERE salary IS NULL;

-- RS1: Salário do funcionário não pode superar o do supervisor
CREATE OR REPLACE FUNCTION fn_employee_valida_salario()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_sal_chefe NUMERIC(10,2);
    v_max_sub   NUMERIC(10,2);
BEGIN
    IF NEW.salary IS NULL THEN
        RETURN NEW;
    END IF;

    IF NEW.reports_to IS NOT NULL THEN
        SELECT salary INTO v_sal_chefe FROM employee WHERE employee_id = NEW.reports_to FOR SHARE;
        IF FOUND AND v_sal_chefe IS NOT NULL AND NEW.salary > v_sal_chefe THEN
            RAISE EXCEPTION 'ERRO! RS1: salário (%) maior que o do supervisor (%).', NEW.salary, v_sal_chefe
                  USING ERRCODE = 'check_violation';
        END IF;
    END IF;

    IF TG_OP = 'UPDATE' THEN
        SELECT max(salary) INTO v_max_sub FROM employee WHERE reports_to = NEW.employee_id;
        IF v_max_sub IS NOT NULL AND NEW.salary < v_max_sub THEN
            RAISE EXCEPTION 'ERRO! RS1: salário (%) menor que o de subordinado (%).', NEW.salary, v_max_sub
                  USING ERRCODE = 'check_violation';
        END IF;
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_employee_salario ON employee;
CREATE TRIGGER trg_employee_salario
    BEFORE INSERT OR UPDATE OF salary, reports_to ON employee
    FOR EACH ROW EXECUTE FUNCTION fn_employee_valida_salario();

-- RS2: Representante de suporte deve ser 'Sales Support Agent'
CREATE OR REPLACE FUNCTION fn_customer_valida_representante()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_title VARCHAR;
BEGIN
    IF NEW.support_rep_id IS NULL THEN
        RETURN NEW;
    END IF;

    SELECT title INTO v_title FROM employee WHERE employee_id = NEW.support_rep_id FOR SHARE;
    IF FOUND AND v_title IS DISTINCT FROM 'Sales Support Agent' THEN
        RAISE EXCEPTION 'ERRO! RS2: funcionário % não é Sales Support Agent.', NEW.support_rep_id
              USING ERRCODE = 'check_violation';
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_customer_representante ON customer;
CREATE TRIGGER trg_customer_representante
    BEFORE INSERT OR UPDATE OF support_rep_id ON customer
    FOR EACH ROW EXECUTE FUNCTION fn_customer_valida_representante();

CREATE OR REPLACE FUNCTION fn_employee_valida_cargo()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
    IF OLD.title = 'Sales Support Agent'
       AND NEW.title IS DISTINCT FROM 'Sales Support Agent'
       AND EXISTS (SELECT 1 FROM customer WHERE support_rep_id = OLD.employee_id) THEN
        RAISE EXCEPTION 'ERRO! RS2: funcionário % ainda atende clientes.', OLD.employee_id
              USING ERRCODE = 'check_violation';
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_employee_cargo ON employee;
CREATE TRIGGER trg_employee_cargo
    BEFORE UPDATE OF title ON employee
    FOR EACH ROW EXECUTE FUNCTION fn_employee_valida_cargo();

-- RS3: Faixa única por cliente
CREATE OR REPLACE FUNCTION fn_invoice_line_valida_faixa_unica()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_customer_id INT;
BEGIN
    SELECT customer_id INTO v_customer_id FROM invoice WHERE invoice_id = NEW.invoice_id;
    IF NOT FOUND THEN
        RETURN NEW;
    END IF;

    IF EXISTS (
        SELECT 1
          FROM invoice_line il
          JOIN invoice i ON i.invoice_id = il.invoice_id
         WHERE i.customer_id = v_customer_id
           AND il.track_id = NEW.track_id
           AND il.invoice_line_id IS DISTINCT FROM NEW.invoice_line_id
    ) THEN
        RAISE EXCEPTION 'ERRO! RS3: cliente % já possui a faixa %.', v_customer_id, NEW.track_id
              USING ERRCODE = 'check_violation';
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_invoice_line_faixa_unica ON invoice_line;
CREATE TRIGGER trg_invoice_line_faixa_unica
    BEFORE INSERT OR UPDATE OF invoice_id, track_id ON invoice_line
    FOR EACH ROW EXECUTE FUNCTION fn_invoice_line_valida_faixa_unica();

CREATE OR REPLACE FUNCTION fn_invoice_valida_troca_cliente()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
    IF NEW.customer_id IS DISTINCT FROM OLD.customer_id AND EXISTS (
        SELECT 1
          FROM invoice_line il1
          JOIN invoice_line il2 ON il2.track_id = il1.track_id
          JOIN invoice i2       ON i2.invoice_id = il2.invoice_id
         WHERE il1.invoice_id = NEW.invoice_id
           AND i2.customer_id = NEW.customer_id
           AND i2.invoice_id <> NEW.invoice_id
    ) THEN
        RAISE EXCEPTION 'ERRO! RS3: cliente % já possui faixas desta fatura.', NEW.customer_id
              USING ERRCODE = 'check_violation';
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_invoice_troca_cliente ON invoice;
CREATE TRIGGER trg_invoice_troca_cliente
    BEFORE UPDATE OF customer_id ON invoice
    FOR EACH ROW EXECUTE FUNCTION fn_invoice_valida_troca_cliente();

-- RS4: Máximo de 500 faixas por playlist
CREATE OR REPLACE FUNCTION fn_playlist_track_valida_limite()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_qtd INT;
BEGIN
    IF TG_OP = 'UPDATE' AND NEW.playlist_id IS NOT DISTINCT FROM OLD.playlist_id THEN
        RETURN NEW;
    END IF;

    SELECT count(*) INTO v_qtd FROM playlist_track WHERE playlist_id = NEW.playlist_id;
    IF v_qtd >= 500 THEN
        RAISE EXCEPTION 'ERRO! RS4: playlist % já atingiu o limite de 500 faixas.', NEW.playlist_id
              USING ERRCODE = 'check_violation';
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_playlist_track_limite ON playlist_track;
CREATE TRIGGER trg_playlist_track_limite
    BEFORE INSERT OR UPDATE OF playlist_id ON playlist_track
    FOR EACH ROW EXECUTE FUNCTION fn_playlist_track_valida_limite();