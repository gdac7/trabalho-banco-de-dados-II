-- Observações:
-- Esse script deve ser executado pelo usuário chinook, depois de questao2_triggers

BEGIN;

DO $$
DECLARE
    v_inv       INT;
    v_track_dup INT;
    v_track_ok  INT;
    v_line_id   INT;
    v_pl_id     INT;
BEGIN
    -- RS1: Salário x Supervisor
    BEGIN
        UPDATE employee SET salary = 13000.00 WHERE employee_id = 3;
        RAISE NOTICE 'RS1 [FALHA]: subordinado acima do chefe aceito';
    EXCEPTION WHEN check_violation THEN
        RAISE NOTICE 'RS1 [OK]: %', SQLERRM;
    END;

    BEGIN
        UPDATE employee SET salary = 4000.00 WHERE employee_id = 2;
        RAISE NOTICE 'RS1 [FALHA]: chefe abaixo de subordinado aceito';
    EXCEPTION WHEN check_violation THEN
        RAISE NOTICE 'RS1 [OK]: %', SQLERRM;
    END;

    UPDATE employee SET salary = 7000.00 WHERE employee_id = 3;
    RAISE NOTICE 'RS1 [OK]: alteração válida aceita';

    -- RS2: Representante de suporte
    BEGIN
        UPDATE customer SET support_rep_id = 6 WHERE customer_id = 1;
        RAISE NOTICE 'RS2 [FALHA]: cargo inválido aceito';
    EXCEPTION WHEN check_violation THEN
        RAISE NOTICE 'RS2 [OK]: %', SQLERRM;
    END;

    BEGIN
        UPDATE employee SET title = 'Manager' WHERE employee_id = 5;
        RAISE NOTICE 'RS2 [FALHA]: troca de cargo com clientes aceita';
    EXCEPTION WHEN check_violation THEN
        RAISE NOTICE 'RS2 [OK]: %', SQLERRM;
    END;

    UPDATE customer SET support_rep_id = 4 WHERE customer_id = 1;
    RAISE NOTICE 'RS2 [OK]: alteração válida aceita';

    -- RS3: Faixa única por cliente
    SELECT min(invoice_id) INTO v_inv FROM invoice WHERE customer_id = 1;
    SELECT min(il.track_id) INTO v_track_dup
      FROM invoice_line il JOIN invoice i ON i.invoice_id = il.invoice_id
     WHERE i.customer_id = 1;
    SELECT min(t.track_id) INTO v_track_ok
      FROM track t
     WHERE NOT EXISTS (
         SELECT 1 FROM invoice_line il JOIN invoice i ON i.invoice_id = il.invoice_id
          WHERE i.customer_id = 1 AND il.track_id = t.track_id
     );
    SELECT max(invoice_line_id) + 1 INTO v_line_id FROM invoice_line;

    BEGIN
        INSERT INTO invoice_line VALUES (v_line_id, v_inv, v_track_dup, 0.99, 1);
        RAISE NOTICE 'RS3 [FALHA]: faixa repetida aceita';
    EXCEPTION WHEN check_violation THEN
        RAISE NOTICE 'RS3 [OK]: %', SQLERRM;
    END;

    INSERT INTO invoice_line VALUES (v_line_id, v_inv, v_track_ok, 0.99, 1);
    RAISE NOTICE 'RS3 [OK]: compra válida aceita';

    -- RS4: Limite de 500 faixas por playlist
    SELECT max(playlist_id) + 1 INTO v_pl_id FROM playlist;
    INSERT INTO playlist VALUES (v_pl_id, 'Teste 500');
    INSERT INTO playlist_track SELECT v_pl_id, track_id FROM track ORDER BY track_id LIMIT 500;

    BEGIN
        INSERT INTO playlist_track SELECT v_pl_id, track_id FROM track ORDER BY track_id OFFSET 500 LIMIT 1;
        RAISE NOTICE 'RS4 [FALHA]: 501ª faixa aceita';
    EXCEPTION WHEN check_violation THEN
        RAISE NOTICE 'RS4 [OK]: %', SQLERRM;
    END;
END $$;

ROLLBACK;