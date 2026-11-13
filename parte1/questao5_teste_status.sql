-- Observações importantes:
-- Esse script deve ser executado pelo usuário chinook

-- Reinicia o cenário com o trigger desligado
ALTER TABLE invoice DISABLE TRIGGER trg_invoice_status;

UPDATE invoice SET status = 'criado' WHERE invoice_id IN (10, 11, 12, 13, 14, 15);
DELETE FROM invoice WHERE invoice_id BETWEEN 9001 AND 9010;

ALTER TABLE invoice ENABLE TRIGGER trg_invoice_status;

SELECT invoice_id, status
FROM invoice WHERE invoice_id IN (10, 11, 12, 13, 14, 15) ORDER BY invoice_id;
-- ESPERADO: as 6 invoices em 'criado'

-- 1. FUNÇÕES ISOLADAS (1 = válido, 0 = inválido)
SELECT teste, obtido, esperado,
       CASE WHEN obtido = esperado THEN 'OK' ELSE 'FALHOU' END AS conferencia
FROM (
    SELECT 1 AS ordem, 'validar_estado: estado existente (criado)' AS teste,
           validar_estado('invoice','status','criado') AS obtido, 1 AS esperado
    UNION ALL SELECT 2, 'validar_estado: estado inexistente (xyz)',
           validar_estado('invoice','status','xyz'), 0
    UNION ALL SELECT 3, 'validar_estado: maiúsculas (CRIADO)',
           validar_estado('invoice','status','CRIADO'), 0
    UNION ALL SELECT 4, 'validar_estado: estado de outro DTE (suspenso)',
           validar_estado('invoice','status','suspenso'), 0
    UNION ALL SELECT 5, 'validar_transicao: INSERT em estado inicial',
           validar_transicao('invoice','status',NULL,'criado'), 1
    UNION ALL SELECT 6, 'validar_transicao: INSERT em estado não inicial',
           validar_transicao('invoice','status',NULL,'aprovado'), 0
    UNION ALL SELECT 7, 'validar_transicao: criado -> pendente',
           validar_transicao('invoice','status','criado','pendente'), 1
    UNION ALL SELECT 8, 'validar_transicao: pendente -> vendo_pagamento',
           validar_transicao('invoice','status','pendente','vendo_pagamento'), 1
    UNION ALL SELECT 9, 'validar_transicao: vendo_pagamento -> em_transicao',
           validar_transicao('invoice','status','vendo_pagamento','em_transicao'), 1
    UNION ALL SELECT 10, 'validar_transicao: em_transicao -> aprovado',
           validar_transicao('invoice','status','em_transicao','aprovado'), 1
    UNION ALL SELECT 11, 'validar_transicao: em_transicao -> reprovado',
           validar_transicao('invoice','status','em_transicao','reprovado'), 1
    UNION ALL SELECT 12, 'validar_transicao: criado -> aprovado (pulo)',
           validar_transicao('invoice','status','criado','aprovado'), 0
    UNION ALL SELECT 13, 'validar_transicao: pendente -> criado (retrocesso)',
           validar_transicao('invoice','status','pendente','criado'), 0
    UNION ALL SELECT 14, 'validar_transicao: mesmo estado (pendente -> pendente)',
           validar_transicao('invoice','status','pendente','pendente'), 1
    UNION ALL SELECT 15, 'validar_transicao: final -> final (aprovado -> reprovado)',
           validar_transicao('invoice','status','aprovado','reprovado'), 0
    UNION ALL SELECT 16, 'validar_transicao: saída de final (reprovado -> criado)',
           validar_transicao('invoice','status','reprovado','criado'), 0
) t
ORDER BY ordem;
-- ESPERADO: todas as linhas com conferencia = OK

-- 2. UPDATE COM TRANSIÇÕES VÁLIDAS (todos devem funcionar)

-- 2.1 Invoice 10: caminho completo até 'aprovado'
UPDATE invoice SET status = 'pendente'        WHERE invoice_id = 10;   -- ESPERADO: UPDATE 1 (criado -> pendente)
UPDATE invoice SET status = 'vendo_pagamento' WHERE invoice_id = 10;   -- ESPERADO: UPDATE 1 (pendente -> vendo_pagamento)
UPDATE invoice SET status = 'em_transicao'    WHERE invoice_id = 10;   -- ESPERADO: UPDATE 1 (vendo_pagamento -> em_transicao)
UPDATE invoice SET status = 'aprovado'        WHERE invoice_id = 10;   -- ESPERADO: UPDATE 1 (em_transicao -> aprovado)

-- 2.2 Invoice 12: caminho alternativo até 'reprovado'
UPDATE invoice SET status = 'pendente'        WHERE invoice_id = 12;   -- ESPERADO: UPDATE 1
UPDATE invoice SET status = 'vendo_pagamento' WHERE invoice_id = 12;   -- ESPERADO: UPDATE 1
UPDATE invoice SET status = 'em_transicao'    WHERE invoice_id = 12;   -- ESPERADO: UPDATE 1
UPDATE invoice SET status = 'reprovado'       WHERE invoice_id = 12;   -- ESPERADO: UPDATE 1 (em_transicao -> reprovado)

-- 2.3 Invoice 13: avança até 'vendo_pagamento' (será usada nos testes inválidos)
UPDATE invoice SET status = 'pendente'        WHERE invoice_id = 13;   -- ESPERADO: UPDATE 1
UPDATE invoice SET status = 'vendo_pagamento' WHERE invoice_id = 13;   -- ESPERADO: UPDATE 1

-- 2.4 Invoice 14: avança até 'pendente' (será usada no teste de lote)
UPDATE invoice SET status = 'pendente'        WHERE invoice_id = 14;   -- ESPERADO: UPDATE 1

-- 2.5 Sem mudança de estado
UPDATE invoice SET status = 'aprovado'        WHERE invoice_id = 10;   -- ESPERADO: UPDATE 1 (aprovado -> aprovado)
UPDATE invoice SET billing_city = billing_city WHERE invoice_id = 10;  -- ESPERADO: UPDATE 1 (outra coluna, estado final)

SELECT invoice_id, status
FROM invoice WHERE invoice_id IN (10, 11, 12, 13, 14, 15) ORDER BY invoice_id;
-- ESPERADO: 10 aprovado | 11 criado | 12 reprovado | 13 vendo_pagamento | 14 pendente | 15 criado

-- 3. UPDATE COM TRANSIÇÕES INVÁLIDAS (todos devem dar ERRO)

-- 3.1 Saída de estado final (invoice 10 está 'aprovado', invoice 12 está 'reprovado')
UPDATE invoice SET status = 'criado'    WHERE invoice_id = 10;  -- ESPERADO: ERRO Transição inválida: aprovado -> criado
UPDATE invoice SET status = 'pendente'  WHERE invoice_id = 10;  -- ESPERADO: ERRO Transição inválida: aprovado -> pendente
UPDATE invoice SET status = 'reprovado' WHERE invoice_id = 10;  -- ESPERADO: ERRO Transição inválida: aprovado -> reprovado
UPDATE invoice SET status = 'aprovado'  WHERE invoice_id = 12;  -- ESPERADO: ERRO Transição inválida: reprovado -> aprovado

-- 3.2 Pulando etapas e estados inválidos (invoice 11 está 'criado')
UPDATE invoice SET status = 'vendo_pagamento' WHERE invoice_id = 11;  -- ESPERADO: ERRO Transição inválida: criado -> vendo_pagamento
UPDATE invoice SET status = 'em_transicao'    WHERE invoice_id = 11;  -- ESPERADO: ERRO Transição inválida: criado -> em_transicao
UPDATE invoice SET status = 'aprovado'        WHERE invoice_id = 11;  -- ESPERADO: ERRO Transição inválida: criado -> aprovado
UPDATE invoice SET status = 'reprovado'       WHERE invoice_id = 11;  -- ESPERADO: ERRO Transição inválida: criado -> reprovado
UPDATE invoice SET status = 'xyz'             WHERE invoice_id = 11;  -- ESPERADO: ERRO Estado "xyz" não existe
UPDATE invoice SET status = 'PENDENTE'        WHERE invoice_id = 11;  -- ESPERADO: ERRO Estado "PENDENTE" não existe (comparação exata)
UPDATE invoice SET status = 'ativo'           WHERE invoice_id = 11;  -- ESPERADO: ERRO Estado "ativo" não existe (é de outro DTE)
UPDATE invoice SET status = NULL              WHERE invoice_id = 11;  -- ESPERADO: ERRO Estado "NULL" não existe

-- 3.3 Retrocesso e pulo (invoice 13 está 'vendo_pagamento')
UPDATE invoice SET status = 'pendente' WHERE invoice_id = 13;   -- ESPERADO: ERRO Transição inválida: vendo_pagamento -> pendente
UPDATE invoice SET status = 'criado'   WHERE invoice_id = 13;   -- ESPERADO: ERRO Transição inválida: vendo_pagamento -> criado
UPDATE invoice SET status = 'aprovado' WHERE invoice_id = 13;   -- ESPERADO: ERRO Transição inválida: vendo_pagamento -> aprovado

SELECT invoice_id, status
FROM invoice WHERE invoice_id IN (10, 11, 12, 13) ORDER BY invoice_id;
-- ESPERADO: nada mudou -> 10 aprovado | 11 criado | 12 reprovado | 13 vendo_pagamento

-- 4. UPDATE EM LOTE (a operação é atômica)
UPDATE invoice SET status = 'vendo_pagamento' WHERE invoice_id IN (14, 15);
-- ESPERADO: ERRO Transição inválida: criado -> vendo_pagamento

SELECT invoice_id, status
FROM invoice WHERE invoice_id IN (14, 15) ORDER BY invoice_id;
-- ESPERADO: 14 pendente | 15 criado (nada foi alterado)

-- 5. INSERT
INSERT INTO invoice (invoice_id, customer_id, invoice_date, total, status)
VALUES (9001, 1, now(), 1.99, 'criado');
-- ESPERADO: INSERT 0 1 (estado inicial)

INSERT INTO invoice (invoice_id, customer_id, invoice_date, total, status)
VALUES (9002, 1, now(), 1.99, 'aprovado');
-- ESPERADO: ERRO Transição inválida: (inserção) -> aprovado (não é estado inicial)

INSERT INTO invoice (invoice_id, customer_id, invoice_date, total, status)
VALUES (9003, 1, now(), 1.99, 'xyz');
-- ESPERADO: ERRO Estado "xyz" não existe

INSERT INTO invoice (invoice_id, customer_id, invoice_date, total, status)
VALUES (9004, 1, now(), 1.99, NULL);
-- ESPERADO: ERRO Estado "NULL" não existe

SELECT invoice_id, status FROM invoice WHERE invoice_id BETWEEN 9001 AND 9004;
-- ESPERADO: apenas a linha 9001 | criado

-- A invoice inserida segue o DTE normalmente
UPDATE invoice SET status = 'pendente' WHERE invoice_id = 9001;  -- ESPERADO: UPDATE 1 (criado -> pendente)
UPDATE invoice SET status = 'criado'   WHERE invoice_id = 9001;  -- ESPERADO: ERRO Transição inválida: pendente -> criado

-- 6. TRIGGER POR LINHA (FOR EACH ROW)

-- 6.1 Confere no catálogo que o trigger é de nível de linha e BEFORE
SELECT t.tgname AS trigger,
       c.relname AS tabela,
       CASE WHEN t.tgtype & 1 = 1 THEN 'POR LINHA (FOR EACH ROW)'
            ELSE 'POR COMANDO (FOR EACH STATEMENT)' END AS nivel,
       CASE WHEN t.tgtype & 2 = 2 THEN 'BEFORE' ELSE 'AFTER/INSTEAD OF' END AS momento,
       concat_ws(' OR ',
                 CASE WHEN t.tgtype & 4  = 4  THEN 'INSERT' END,
                 CASE WHEN t.tgtype & 8  = 8  THEN 'DELETE' END,
                 CASE WHEN t.tgtype & 16 = 16 THEN 'UPDATE' END) AS eventos,
       CASE WHEN t.tgtype & 1 = 1 THEN 'OK' ELSE 'FALHOU' END AS conferencia
FROM pg_trigger t
JOIN pg_class c ON c.oid = t.tgrelid
WHERE t.tgname = 'trg_invoice_status' AND NOT t.tgisinternal;
-- ESPERADO: 1 linha | POR LINHA (FOR EACH ROW) | BEFORE | INSERT OR UPDATE | OK

-- 6.2 INSERT de várias linhas com uma inválida: nenhuma é gravada
INSERT INTO invoice (invoice_id, customer_id, invoice_date, total, status)
VALUES (9005, 1, now(), 1.99, 'criado'),
       (9006, 1, now(), 1.99, 'aprovado');
-- ESPERADO: ERRO Transição inválida: (inserção) -> aprovado

SELECT invoice_id, status FROM invoice WHERE invoice_id IN (9005, 9006);
-- ESPERADO: nenhuma linha

-- 6.3 INSERT de várias linhas, todas válidas: o trigger roda 1 vez por linha
INSERT INTO invoice (invoice_id, customer_id, invoice_date, total, status)
VALUES (9005, 1, now(), 1.99, 'criado'),
       (9006, 1, now(), 1.99, 'criado'),
       (9007, 1, now(), 1.99, 'criado');
-- ESPERADO: INSERT 0 3

-- 6.4 UPDATE de várias linhas, todas válidas (criado -> pendente)
UPDATE invoice SET status = 'pendente' WHERE invoice_id IN (9005, 9006);
-- ESPERADO: UPDATE 2

-- 6.5 Deixa as duas linhas em estados DIFERENTES (9005 pendente, 9006 vendo_pagamento)
UPDATE invoice SET status = 'vendo_pagamento' WHERE invoice_id = 9006;
-- ESPERADO: UPDATE 1 (pendente -> vendo_pagamento)

-- 6.6 Um único UPDATE em que cada linha parte de um estado (OLD) diferente
UPDATE invoice
SET status = CASE status
                 WHEN 'pendente'        THEN 'vendo_pagamento'
                 WHEN 'vendo_pagamento' THEN 'em_transicao'
             END
WHERE invoice_id IN (9005, 9006);
-- ESPERADO: UPDATE 2

-- 6.7 UPDATE em lote com uma linha inválida: nenhuma muda
UPDATE invoice SET status = 'pendente' WHERE invoice_id IN (9007, 9006);
-- ESPERADO: ERRO Transição inválida: em_transicao -> pendente

SELECT i.invoice_id,
       i.status,
       v.esperado,
       CASE WHEN i.status = v.esperado THEN 'OK' ELSE 'FALHOU' END AS conferencia
FROM invoice i
JOIN (VALUES (9005, 'vendo_pagamento'),
             (9006, 'em_transicao'),
             (9007, 'criado')) AS v(id, esperado)
  ON v.id = i.invoice_id
ORDER BY i.invoice_id;
-- ESPERADO: 3 linhas, todas com conferencia = OK

-- Limpeza das invoices usadas nesta seção
DELETE FROM invoice WHERE invoice_id BETWEEN 9005 AND 9007;

-- 7. CONFERÊNCIA FINAL (tudo junto)
SELECT i.invoice_id,
       i.status,
       v.esperado,
       CASE WHEN i.status = v.esperado THEN 'OK' ELSE 'FALHOU' END AS conferencia
FROM invoice i
JOIN (VALUES (10,   'aprovado'),
             (11,   'criado'),
             (12,   'reprovado'),
             (13,   'vendo_pagamento'),
             (14,   'pendente'),
             (15,   'criado'),
             (9001, 'pendente')) AS v(id, esperado)
  ON v.id = i.invoice_id
ORDER BY i.invoice_id;
-- ESPERADO: 7 linhas, todas com conferencia = OK