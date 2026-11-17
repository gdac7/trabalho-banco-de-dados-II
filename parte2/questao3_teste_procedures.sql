-- Observações:
-- Esse script deve ser executado pelo usuário chinook, depois de questao3_criar_usuario,
-- questao3_procedures e questao3_permissoes

-- Teste executado em transação (BEGIN ... ROLLBACK) para não deixar dados de teste no banco
-- e permitir reexecutar o script. O ON_ERROR_ROLLBACK (variável do psql) cria um savepoint
-- antes de cada comando: os comandos que devem FALHAR não abortam a transação inteira.
-- SET ROLE chinook_app faz os comandos seguintes rodarem como o usuário restrito.
\set ON_ERROR_ROLLBACK on
BEGIN;

-- 0) Preparação, ainda como chinook (dono das tabelas): playlist 9999 com 499 faixas,
-- para testar o limite de 500 da RS4
INSERT INTO playlist (playlist_id, name) VALUES (9999, 'Teste RS4');
INSERT INTO playlist_track (playlist_id, track_id)
SELECT 9999, track_id FROM track WHERE track_id <= 499;

SET ROLE chinook_app;
SELECT current_user;
-- ESPERADO: chinook_app


-- 1) Acesso direto às tabelas
SELECT count(*) FROM track;
-- ESPERADO: 3503 (leitura liberada)

UPDATE employee SET salary = 99999 WHERE employee_id = 3;
-- ESPERADO: ERRO permission denied for table employee

UPDATE customer SET support_rep_id = 1 WHERE customer_id = 1;
-- ESPERADO: ERRO permission denied for table customer

INSERT INTO invoice_line (invoice_line_id, invoice_id, track_id, unit_price, quantity)
VALUES (99999, 1, 262, 0.99, 1);
-- ESPERADO: ERRO permission denied for table invoice_line

DELETE FROM playlist_track WHERE playlist_id = 9999;
-- ESPERADO: ERRO permission denied for table playlist_track


-- 2) RS1 - salário do funcionário <= salário do supervisor
SELECT employee_id, first_name, title, reports_to, salary FROM employee ORDER BY employee_id;
-- ESPERADO: 1 Andrew 20000 | 2 Nancy 12000 (reporta a 1) | 3, 4, 5 Sales Support Agent 5000 (reportam a 2)
--           6 Michael 12000 (reporta a 1) | 7, 8 IT Staff 6000 (reportam a 6)

CALL alterar_salario_funcionario(3, 6000);
SELECT salary FROM employee WHERE employee_id = 3;
-- ESPERADO: 6000.00 (Jane continua abaixo da supervisora Nancy, 12000)

CALL alterar_salario_funcionario(3, 13000);
-- ESPERADO: ERRO! RS1: salário 13000 maior que o do supervisor 2 (12000.00)

CALL alterar_salario_funcionario(2, 5500);
-- ESPERADO: ERRO! RS1: salário 5500 menor que o de um subordinado direto (6000.00)

CALL cadastrar_funcionario(9999, 'Ana', 'Teste', 'Sales Support Agent', 2, 5500);
SELECT employee_id, title, reports_to, salary FROM employee WHERE employee_id = 9999;
-- ESPERADO: 9999 | Sales Support Agent | 2 | 5500.00

CALL cadastrar_funcionario(9998, 'Bruno', 'Teste', 'Sales Support Agent', 2, 15000);
-- ESPERADO: ERRO! RS1: salário 15000 maior que o do supervisor 2 (12000.00)

CALL alterar_supervisor_funcionario(6, 3);
-- ESPERADO: ERRO! RS1: o funcionário 6 ganha 12000.00 e o novo supervisor 3 ganha 6000.00

CALL alterar_supervisor_funcionario(7, 2);
SELECT reports_to FROM employee WHERE employee_id = 7;
-- ESPERADO: 2 (Robert, 6000, passa a reportar a Nancy, 12000)


-- 3) RS2 - representante do cliente precisa ser Sales Support Agent
CALL cadastrar_cliente(9999, 'Carla', 'Teste', 'carla@teste.com', 3);
SELECT customer_id, support_rep_id, situacao FROM customer WHERE customer_id = 9999;
-- ESPERADO: 9999 | 3 | cadastrado

CALL cadastrar_cliente(9998, 'Davi', 'Teste', 'davi@teste.com', 2);
-- ESPERADO: ERRO! RS2: o funcionário 2 é Sales Manager e não Sales Support Agent

CALL alterar_representante_cliente(1, 5);
SELECT support_rep_id FROM customer WHERE customer_id = 1;
-- ESPERADO: 5

CALL alterar_representante_cliente(1, 6);
-- ESPERADO: ERRO! RS2: o funcionário 6 é IT Manager e não Sales Support Agent

CALL alterar_cargo_funcionario(3, 'Sales Manager');
-- ESPERADO: ERRO! RS2: o funcionário 3 atende 21 clientes e precisa continuar Sales Support Agent

CALL alterar_cargo_funcionario(9999, 'IT Staff');
SELECT title FROM employee WHERE employee_id = 9999;
-- ESPERADO: IT Staff (Ana, cadastrada no item 2, não atende nenhum cliente)


-- 4) RS3 - cliente não compra a mesma faixa duas vezes
CALL criar_fatura(9999, 1);
SELECT invoice_id, customer_id, total, status FROM invoice WHERE invoice_id = 9999;
-- ESPERADO: 9999 | 1 | 0.00 | criado

CALL adicionar_item_fatura(99999, 9999, 1);
SELECT total FROM invoice WHERE invoice_id = 9999;
-- ESPERADO: 0.99 (faixa 1 nunca comprada pelo cliente 1; o total sobe pelo trigger da Q4)

CALL adicionar_item_fatura(99998, 9999, 1);
-- ESPERADO: ERRO! RS3: o cliente 1 já comprou a faixa 1 (invoice 9999)

CALL adicionar_item_fatura(99998, 9999, 262);
-- ESPERADO: ERRO! RS3: o cliente 1 já comprou a faixa 262 (invoice 327)

CALL criar_fatura(9998, 2);
CALL adicionar_item_fatura(99998, 9998, 1);
SELECT invoice_id, customer_id, total FROM invoice WHERE invoice_id IN (9998, 9999) ORDER BY invoice_id;
-- ESPERADO: 9998 | 2 | 0.99  e  9999 | 1 | 0.99 (outro cliente pode comprar a mesma faixa)


-- 5) RS4 - playlist com no máximo 500 faixas
SELECT count(*) FROM playlist_track WHERE playlist_id = 9999;
-- ESPERADO: 499

CALL adicionar_faixa_playlist(9999, 500);
SELECT count(*) FROM playlist_track WHERE playlist_id = 9999;
-- ESPERADO: 500

CALL adicionar_faixa_playlist(9999, 501);
-- ESPERADO: ERRO! RS4: a playlist 9999 já tem 500 faixas (máximo 500)

CALL adicionar_faixa_playlist(1, 1);
-- ESPERADO: ERRO! RS4: a playlist 1 já tem 3290 faixas (máximo 500) (dado original do Chinook)


RESET ROLE;
ROLLBACK;
