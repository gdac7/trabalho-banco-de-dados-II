-- Observações:
-- Esse script deve ser executado pelo usuário chinook

SELECT * FROM gerar_ddl('public');

-- Esperado: 11 | 11 | 11 no Chinook original (13 | 13 | 13 depois da Q5)
SELECT count(*)                                              AS tabelas,
       sum((ddl LIKE '%PRIMARY KEY%')::int)                  AS com_pk,
       sum(array_length(regexp_split_to_array(ddl, 'FOREIGN KEY'), 1) - 1) AS fks
FROM gerar_ddl('public') AS ddl;
