-- Observações:
-- Esse script deve ser executado pelo usuário chinook

-- Teste executado em transação (BEGIN ... ROLLBACK) para não deixar dados de teste no banco
-- e permitir reexecutar o script. O ON_ERROR_ROLLBACK (variável do psql) cria um savepoint
-- antes de cada comando: os comandos que devem FALHAR não abortam a transação inteira.
\set ON_ERROR_ROLLBACK on
BEGIN;

-- 0) Verificação: deve retornar 0 linhas se tudo estiver consistente
SELECT i.invoice_id, i.total AS total_gravado,
       COALESCE(SUM(il.unit_price * il.quantity), 0) AS total_calculado
  FROM invoice i
  LEFT JOIN invoice_line il ON il.invoice_id = i.invoice_id
 GROUP BY i.invoice_id, i.total
HAVING i.total <> COALESCE(SUM(il.unit_price * il.quantity), 0);
-- ESPERADO: 0 linhas

-- a) Update manual deve falhar
UPDATE invoice SET total = 999 WHERE invoice_id = 1;
-- ESPERADO: ERRO! Impossível alterar o total manualmente

-- b) Inserir invoice com total "falso" -> fica 0
-- (status 'criado' é exigido pelo DTE da Q5 da Parte 1)
INSERT INTO invoice (invoice_id, customer_id, invoice_date, total, status)
VALUES (9999, 1, now(), 500, 'criado');
SELECT total FROM invoice WHERE invoice_id = 9999;
-- ESPERADO: 0.00

-- c) Inserir linha -> total sobe
INSERT INTO invoice_line (invoice_line_id, invoice_id, track_id, unit_price, quantity)
VALUES (99999, 9999, 1, 0.99, 2);
SELECT total FROM invoice WHERE invoice_id = 9999;
-- ESPERADO: 1.98

-- d) Alterar quantidade, depois apagar a linha -> total volta a 0
UPDATE invoice_line SET quantity = 3 WHERE invoice_line_id = 99999;
SELECT total FROM invoice WHERE invoice_id = 9999;
-- ESPERADO: 2.97
DELETE FROM invoice_line WHERE invoice_line_id = 99999;
SELECT total FROM invoice WHERE invoice_id = 9999;
-- ESPERADO: 0.00

-- e) Mover uma linha para outra invoice -> sai da antiga e entra na nova
SELECT invoice_id, total FROM invoice WHERE invoice_id IN (1, 9999) ORDER BY invoice_id;
-- ESPERADO: 1 = 1.98 | 9999 = 0.00
UPDATE invoice_line SET invoice_id = 9999 WHERE invoice_line_id = 1;
SELECT invoice_id, total FROM invoice WHERE invoice_id IN (1, 9999) ORDER BY invoice_id;
-- ESPERADO: 1 = 0.99 | 9999 = 0.99

-- f) TRUNCATE em invoice_line -> todos os totais vão para 0
SAVEPOINT antes_truncate;
TRUNCATE invoice_line;
SELECT count(*) AS invoices_com_total FROM invoice WHERE total <> 0;
-- ESPERADO: 0
ROLLBACK TO SAVEPOINT antes_truncate;

-- Verificação final: a regra continua valendo para todas as invoices
SELECT i.invoice_id, i.total AS total_gravado,
       COALESCE(SUM(il.unit_price * il.quantity), 0) AS total_calculado
  FROM invoice i
  LEFT JOIN invoice_line il ON il.invoice_id = i.invoice_id
 GROUP BY i.invoice_id, i.total
HAVING i.total <> COALESCE(SUM(il.unit_price * il.quantity), 0);
-- ESPERADO: 0 linhas

ROLLBACK;
