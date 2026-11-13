-- Observações importantes:
-- Esse script deve ser executado pelo usuário chinook

-- Reinicia o cenário com o trigger desligado
ALTER TABLE customer DISABLE TRIGGER trg_customer_situacao;

UPDATE customer SET situacao = 'ativo'      WHERE customer_id IN (1, 2, 4);
UPDATE customer SET situacao = 'cadastrado' WHERE customer_id IN (3, 5, 6);
DELETE FROM customer WHERE customer_id BETWEEN 9001 AND 9010;

ALTER TABLE customer ENABLE TRIGGER trg_customer_situacao;

SELECT customer_id, situacao
FROM customer WHERE customer_id IN (1, 2, 3, 4, 5, 6) ORDER BY customer_id;
-- ESPERADO: 1 ativo | 2 ativo | 3 cadastrado | 4 ativo | 5 cadastrado | 6 cadastrado

-- 1. FUNÇÕES ISOLADAS (1 = válido, 0 = inválido)
SELECT teste, obtido, esperado,
       CASE WHEN obtido = esperado THEN 'OK' ELSE 'FALHOU' END AS conferencia
FROM (
    SELECT 1 AS ordem, 'validar_estado: estado existente (cadastrado)' AS teste,
           validar_estado('customer','situacao','cadastrado') AS obtido, 1 AS esperado
    UNION ALL SELECT 2, 'validar_estado: estado inexistente (xyz)',
           validar_estado('customer','situacao','xyz'), 0
    UNION ALL SELECT 3, 'validar_estado: maiúsculas (ATIVO)',
           validar_estado('customer','situacao','ATIVO'), 0
    UNION ALL SELECT 4, 'validar_estado: estado de outro DTE (aprovado)',
           validar_estado('customer','situacao','aprovado'), 0
    UNION ALL SELECT 5, 'validar_transicao: INSERT em estado inicial',
           validar_transicao('customer','situacao',NULL,'cadastrado'), 1
    UNION ALL SELECT 6, 'validar_transicao: INSERT em estado não inicial',
           validar_transicao('customer','situacao',NULL,'ativo'), 0
    UNION ALL SELECT 7, 'validar_transicao: cadastrado -> ativo',
           validar_transicao('customer','situacao','cadastrado','ativo'), 1
    UNION ALL SELECT 8, 'validar_transicao: ativo -> suspenso',
           validar_transicao('customer','situacao','ativo','suspenso'), 1
    UNION ALL SELECT 9, 'validar_transicao: suspenso -> ativo (ciclo)',
           validar_transicao('customer','situacao','suspenso','ativo'), 1
    UNION ALL SELECT 10, 'validar_transicao: ativo -> inativo',
           validar_transicao('customer','situacao','ativo','inativo'), 1
    UNION ALL SELECT 11, 'validar_transicao: cadastrado -> suspenso (pulo)',
           validar_transicao('customer','situacao','cadastrado','suspenso'), 0
    UNION ALL SELECT 12, 'validar_transicao: ativo -> cadastrado (retrocesso)',
           validar_transicao('customer','situacao','ativo','cadastrado'), 0
    UNION ALL SELECT 13, 'validar_transicao: mesmo estado (ativo -> ativo)',
           validar_transicao('customer','situacao','ativo','ativo'), 1
    UNION ALL SELECT 14, 'validar_transicao: saída de final (inativo -> ativo)',
           validar_transicao('customer','situacao','inativo','ativo'), 0
) t
ORDER BY ordem;
-- ESPERADO: todas as linhas com conferencia = OK

-- 2. UPDATE COM TRANSIÇÕES VÁLIDAS (todos devem funcionar)

-- 2.1 Cliente 5: cadastrado -> ativo
UPDATE customer SET situacao = 'ativo' WHERE customer_id = 5;       -- ESPERADO: UPDATE 1

-- 2.2 Cliente 1: ciclo ativo <-> suspenso e depois inativo
UPDATE customer SET situacao = 'suspenso' WHERE customer_id = 1;    -- ESPERADO: UPDATE 1 (ativo -> suspenso)
UPDATE customer SET situacao = 'ativo'    WHERE customer_id = 1;    -- ESPERADO: UPDATE 1 (suspenso -> ativo)
UPDATE customer SET situacao = 'suspenso' WHERE customer_id = 1;    -- ESPERADO: UPDATE 1 (ativo -> suspenso, de novo)
UPDATE customer SET situacao = 'inativo'  WHERE customer_id = 1;    -- ESPERADO: UPDATE 1 (suspenso -> inativo)

-- 2.3 Cliente 4: ativo -> inativo direto
UPDATE customer SET situacao = 'inativo' WHERE customer_id = 4;     -- ESPERADO: UPDATE 1

-- 2.4 Sem mudança de estado
UPDATE customer SET situacao = 'ativo'   WHERE customer_id = 2;     -- ESPERADO: UPDATE 1 (ativo -> ativo)
UPDATE customer SET phone = phone        WHERE customer_id = 2;     -- ESPERADO: UPDATE 1 (outra coluna)
UPDATE customer SET situacao = 'inativo' WHERE customer_id = 4;     -- ESPERADO: UPDATE 1 (inativo -> inativo)

SELECT customer_id, situacao
FROM customer WHERE customer_id IN (1, 2, 3, 4, 5, 6) ORDER BY customer_id;
-- ESPERADO: 1 inativo | 2 ativo | 3 cadastrado | 4 inativo | 5 ativo | 6 cadastrado

-- 3. UPDATE COM TRANSIÇÕES INVÁLIDAS (todos devem dar ERRO)

-- 3.1 Saída de estado final (cliente 1 está 'inativo')
UPDATE customer SET situacao = 'ativo'      WHERE customer_id = 1;  -- ESPERADO: ERRO Transição inválida: inativo -> ativo
UPDATE customer SET situacao = 'suspenso'   WHERE customer_id = 1;  -- ESPERADO: ERRO Transição inválida: inativo -> suspenso
UPDATE customer SET situacao = 'cadastrado' WHERE customer_id = 1;  -- ESPERADO: ERRO Transição inválida: inativo -> cadastrado

-- 3.2 Retrocesso e estados inválidos (cliente 2 está 'ativo')
UPDATE customer SET situacao = 'cadastrado' WHERE customer_id = 2;  -- ESPERADO: ERRO Transição inválida: ativo -> cadastrado
UPDATE customer SET situacao = 'xyz'        WHERE customer_id = 2;  -- ESPERADO: ERRO Estado "xyz" não existe
UPDATE customer SET situacao = 'ATIVO'      WHERE customer_id = 2;  -- ESPERADO: ERRO Estado "ATIVO" não existe (comparação exata)
UPDATE customer SET situacao = 'aprovado'   WHERE customer_id = 2;  -- ESPERADO: ERRO Estado "aprovado" não existe (é de outro DTE)
UPDATE customer SET situacao = NULL         WHERE customer_id = 2;  -- ESPERADO: ERRO Estado "NULL" não existe

-- 3.3 Pulando etapas (cliente 3 está 'cadastrado')
UPDATE customer SET situacao = 'suspenso' WHERE customer_id = 3;    -- ESPERADO: ERRO Transição inválida: cadastrado -> suspenso
UPDATE customer SET situacao = 'inativo'  WHERE customer_id = 3;    -- ESPERADO: ERRO Transição inválida: cadastrado -> inativo

SELECT customer_id, situacao
FROM customer WHERE customer_id IN (1, 2, 3) ORDER BY customer_id;
-- ESPERADO: nada mudou -> 1 inativo | 2 ativo | 3 cadastrado

-- 4. UPDATE EM LOTE (a operação é atômica)

UPDATE customer SET situacao = 'suspenso' WHERE customer_id IN (2, 6);
-- ESPERADO: ERRO Transição inválida: cadastrado -> suspenso

SELECT customer_id, situacao
FROM customer WHERE customer_id IN (2, 6) ORDER BY customer_id;
-- ESPERADO: 2 ativo | 6 cadastrado (nada foi alterado)

-- 5. INSERT

INSERT INTO customer (customer_id, first_name, last_name, email, situacao)
VALUES (9001, 'Teste', 'Um', 'teste1@exemplo.com', 'cadastrado');
-- ESPERADO: INSERT 0 1 (estado inicial)

INSERT INTO customer (customer_id, first_name, last_name, email, situacao)
VALUES (9002, 'Teste', 'Dois', 'teste2@exemplo.com', 'ativo');
-- ESPERADO: ERRO Transição inválida: (inserção) -> ativo (não é estado inicial)

INSERT INTO customer (customer_id, first_name, last_name, email, situacao)
VALUES (9003, 'Teste', 'Tres', 'teste3@exemplo.com', 'xyz');
-- ESPERADO: ERRO Estado "xyz" não existe

INSERT INTO customer (customer_id, first_name, last_name, email, situacao)
VALUES (9004, 'Teste', 'Quatro', 'teste4@exemplo.com', NULL);
-- ESPERADO: ERRO Estado "NULL" não existe

SELECT customer_id, situacao FROM customer WHERE customer_id BETWEEN 9001 AND 9004;
-- ESPERADO: apenas a linha 9001 | cadastrado

-- O cliente inserido segue o ciclo de vida normalmente
UPDATE customer SET situacao = 'ativo'      WHERE customer_id = 9001;  -- ESPERADO: UPDATE 1 (cadastrado -> ativo)
UPDATE customer SET situacao = 'cadastrado' WHERE customer_id = 9001;  -- ESPERADO: ERRO Transição inválida: ativo -> cadastrado

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
WHERE t.tgname = 'trg_customer_situacao' AND NOT t.tgisinternal;
-- ESPERADO: 1 linha | POR LINHA (FOR EACH ROW) | BEFORE | INSERT OR UPDATE | OK

-- 6.2 INSERT de várias linhas com uma inválida: nenhuma é gravada
INSERT INTO customer (customer_id, first_name, last_name, email, situacao)
VALUES (9005, 'Teste', 'Cinco', 'teste5@exemplo.com', 'cadastrado'),
       (9006, 'Teste', 'Seis',  'teste6@exemplo.com', 'ativo');
-- ESPERADO: ERRO Transição inválida: (inserção) -> ativo

SELECT customer_id, situacao FROM customer WHERE customer_id IN (9005, 9006);
-- ESPERADO: nenhuma linha

-- 6.3 INSERT de várias linhas, todas válidas: o trigger roda 1 vez por linha
INSERT INTO customer (customer_id, first_name, last_name, email, situacao)
VALUES (9005, 'Teste', 'Cinco', 'teste5@exemplo.com', 'cadastrado'),
       (9006, 'Teste', 'Seis',  'teste6@exemplo.com', 'cadastrado'),
       (9007, 'Teste', 'Sete',  'teste7@exemplo.com', 'cadastrado');
-- ESPERADO: INSERT 0 3

-- 6.4 UPDATE de várias linhas, todas válidas (cadastrado -> ativo)
UPDATE customer SET situacao = 'ativo' WHERE customer_id IN (9005, 9006);
-- ESPERADO: UPDATE 2

-- 6.5 Deixa as duas linhas em estados DIFERENTES (9005 ativo, 9006 suspenso)
UPDATE customer SET situacao = 'suspenso' WHERE customer_id = 9006;
-- ESPERADO: UPDATE 1 (ativo -> suspenso)

-- 6.6 Um único UPDATE em que cada linha parte de um estado (OLD) diferente
UPDATE customer SET situacao = 'inativo' WHERE customer_id IN (9005, 9006);
-- ESPERADO: UPDATE 2

-- 6.7 UPDATE em lote com uma linha inválida: nenhuma muda
UPDATE customer SET situacao = 'ativo' WHERE customer_id IN (9007, 9005);
-- ESPERADO: ERRO Transição inválida: inativo -> ativo

SELECT c.customer_id,
       c.situacao,
       v.esperado,
       CASE WHEN c.situacao = v.esperado THEN 'OK' ELSE 'FALHOU' END AS conferencia
FROM customer c
JOIN (VALUES (9005, 'inativo'),
             (9006, 'inativo'),
             (9007, 'cadastrado')) AS v(id, esperado)
  ON v.id = c.customer_id
ORDER BY c.customer_id;
-- ESPERADO: 3 linhas, todas com conferencia = OK

-- Limpeza dos clientes usados nesta seção
DELETE FROM customer WHERE customer_id BETWEEN 9005 AND 9007;

-- 7. CONFERÊNCIA FINAL (tudo junto)
SELECT c.customer_id,
       c.situacao,
       v.esperado,
       CASE WHEN c.situacao = v.esperado THEN 'OK' ELSE 'FALHOU' END AS conferencia
FROM customer c
JOIN (VALUES (1,    'inativo'),
             (2,    'ativo'),
             (3,    'cadastrado'),
             (4,    'inativo'),
             (5,    'ativo'),
             (6,    'cadastrado'),
             (9001, 'ativo')) AS v(id, esperado)
  ON v.id = c.customer_id
ORDER BY c.customer_id;
-- ESPERADO: 7 linhas, todas com conferencia = OK