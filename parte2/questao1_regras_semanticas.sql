-- Observações:
-- Este arquivo contém apenas a descrição textual das regras semânticas (Questão 1 da Parte 2).
-- Não há comandos para executar: as regras são implementadas nas demais questões da Parte 2.

-- Regras Semânticas para a parte 2:

-- RS1 - Um funcionário (employee) não pode ganhar um salário maior que o do seu supervisor (reportsTo).
-- Consequentemente, o salário de um supervisor também não pode ser alterado para um valor menor que o
-- de qualquer um dos seus subordinados diretos. OBS: como o Chinook não contém a coluna salary em
-- employee, foram feitas modificações no esquema para comportar a regra.

-- RS2 - Um cliente (customer) só pode ter como funcionário associado a ele (supportRepId) um funcionário
-- que tenha o title de “Sales Support Agent”.

-- RS3 - Um cliente (customer) não pode comprar a mesma faixa de música (track) mais de uma vez, pois a
-- faixa é uma mídia digital. Ou seja, não podem existir duas linhas de invoiceline com a mesma faixa em
-- invoices pertencentes ao mesmo cliente.

-- RS4 - Uma mesma playlist não pode conter mais do que 500 faixas de música.

-- RS5 - O valor Total de uma fatura (invoice) deve ser sempre igual à soma de UnitPrice * Quantity de
-- todas as linhas (invoiceline) relacionadas a essa fatura. Uma fatura recém-criada, sem linhas, possui
-- Total igual a 0, e o Total não pode ser alterado manualmente, apenas pelo próprio sistema a partir das
-- alterações nas linhas.
