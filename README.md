# Trabalho de Banco de Dados II em PostgreSQL 18

Guia do projeto: como preparar o ambiente, criar o banco e rodar os scripts.

- **SGBD:** PostgreSQL 18
- **Esquema exemplo:** [Chinook Database](https://github.com/lerocha/chinook-database) (versão 1.4.5, nomes em snake_case: `album`, `invoice_line`, `artist_id`...)
- **Linguagens:** SQL e PL/pgSQL

## 1. Instalar o PostgreSQL 18

Ubuntu/Debian:

```bash
sudo apt install postgresql-18
systemctl status postgresql
```

## 2. Definir a senha do superusuário `postgres`

```bash
sudo -u postgres psql -c "ALTER USER postgres PASSWORD 'postgres';"
psql -h localhost -U postgres -c "SELECT version();"
```

## 3. Criar o banco `chinook`

```bash
psql -h localhost -U postgres -f setup/00_setup_admin.sql
psql -h localhost -U chinook -d chinook -c "SELECT current_user, current_database();"
```

## 4. Carregar o Chinook

```bash
psql -h localhost -U chinook -d chinook -f setup/01_ddl_chinook.sql
```

Conferir (`psql -h localhost -U chinook -d chinook`):

```sql
-- 11 tabelas
\dt
SELECT count(*) FROM track;   -- 3503
```

## 5. Rodar os scripts das questões

```bash
psql -h localhost -U chinook -d chinook -f <pasta>/<arquivo>.sql
```

Os arquivos ficam em `parte1/` e `parte2/`, um ou mais por questão (`questaoN_...`), junto com os seus testes. Rode-os nesta ordem (a mesma do relatório), todos pelo `chinook`, exceto o `questao3_criar_usuario`:

1. **Parte 1:** `questao1_index_tab_col`, `questao2_deletar_index_tab`, `questao3_fk_tab_col`, `questao4_gerar_ddl` e os quatro arquivos da Q5, nesta ordem: `questao5_estruturaDTE`, `questao5_functions_triggers`, `questao5_status_invoice` e `questao5_situacao_customer`.
2. **Parte 2:**
   - `questao1_regras_semanticas.txt` contém só a descrição textual das regras semânticas (RS1–RS5) e não é executado;
   - `questao2_triggers`;
   - `questao3_criar_usuario`, rodado pelo **postgres**, porque o usuário `chinook` não pode criar usuários; depois `questao3_procedures` e `questao3_permissoes`;
   - `questao4_total_invoice`.
3. **Testes, por último:** `questao2_teste_deletar_index`, `questao4_teste_ddl`, `questao5_teste_status` e `questao5_teste_situacao`, da Parte 1; `questao2_teste_triggers`, `questao3_teste_procedures` e `questao4_teste_total_invoice`, da Parte 2.

A Q3 da Parte 2 é a única que mistura os dois usuários:

```bash
psql -h localhost -U postgres -d chinook -f parte2/questao3_criar_usuario.sql
psql -h localhost -U chinook  -d chinook -f parte2/questao3_procedures.sql
psql -h localhost -U chinook  -d chinook -f parte2/questao3_permissoes.sql
```

**Por que os testes vão por último:** eles dependem de objetos de outras questões. O teste da Q3 da Parte 2 confere o total da invoice atualizado pelo trigger da Q4. O `questao5_teste_status` grava a invoice 9001 de forma permanente (sem `ROLLBACK`): com o trigger da Q4 já instalado, o total dela é zerado; sem ele, a invoice fica com total 1,99 e nenhuma linha, e as verificações de `questao4_teste_total_invoice` acusam essa diferença em vez de retornar 0 linhas. Rodando os testes depois de todos os scripts, os resultados batem com os comentários `ESPERADO`.

Para recomeçar do zero, repita os passos 3 e 4.

**Por que alguns testes terminam em `ROLLBACK`:** os testes da Q2 da Parte 1 (`questao2_teste_deletar_index`) e das Q2, Q3 e Q4 da Parte 2 (`questao2_teste_triggers`, `questao3_teste_procedures` e `questao4_teste_total_invoice`) rodam dentro de `BEGIN; ... ROLLBACK;`. No PostgreSQL até o DDL é transacional, então o `ROLLBACK` desfaz tudo o que o teste fez:

- **Q2 da Parte 1:** remover os índices de `track` apaga a chave primária e, junto, as chaves estrangeiras de `invoice_line` e `playlist_track` que apontam para ela. Sem o `ROLLBACK`, o esquema ficaria alterado e mudaria o resultado de outras questões (por exemplo, o DDL gerado pela Q4 da Parte 1).
- **Q2 da Parte 2:** o teste altera salários, cargos e representantes e insere uma linha de invoice e uma playlist de teste. Sem o `ROLLBACK`, essas alterações ficariam no banco e mudariam o resultado dos testes das outras questões.
- **Q3 da Parte 2:** o teste cadastra funcionário, cliente, invoices e uma playlist de teste (ids 9998/9999) e altera salários e representantes. Sem o `ROLLBACK`, esses dados ficariam no banco e a segunda execução falharia por chave duplicada.
- **Q4 da Parte 2:** o teste insere, altera e apaga dados (invoice 9999, `TRUNCATE` em `invoice_line`). Sem o `ROLLBACK`, esses dados ficariam no banco e a segunda execução falharia por chave duplicada.

O `ROLLBACK` desfaz só o que o teste fez: as procedures e triggers instaladas pelos scripts das questões continuam no banco. Os resultados aparecem na tela antes do `ROLLBACK`, então o teste demonstra o funcionamento do mesmo jeito.

Rode todos os testes pelo **psql** (`-f`), não pelo pgAdmin. Os testes têm comandos que devem falhar: o psql mostra o erro e segue para o próximo comando, enquanto o pgAdmin envia o script inteiro de uma vez, para no primeiro erro e desfaz o que veio antes. Além disso, alguns testes usam comandos do próprio psql: `\d` na Q2 da Parte 1 e `\set ON_ERROR_ROLLBACK on` nas Q3 e Q4 da Parte 2, que faz um comando que deve falhar não abortar o restante da transação.


## 6. Salvar a saída em arquivo

```bash
psql -a -h localhost -U chinook -d chinook -f <pasta>/<arquivo>.sql > saidas/<nome>.txt 2>&1
```

- `-a` repete no arquivo cada comando do script, então cada resultado aparece ao lado do seu comentário `ESPERADO`.
- `2>&1` grava também os erros e os avisos (`RAISE NOTICE`), que o psql escreve fora da saída normal. Sem ele, os erros esperados dos testes ficam de fora, e o arquivo do teste da Q2 da Parte 2 fica só com `BEGIN` e `ROLLBACK`.

Para obter só o texto, sem cabeçalho e sem bordas (ex.: o DDL gerado pela Q4, que pode ser executado depois):

```bash
psql -At -h localhost -U chinook -d chinook -c "SELECT * FROM gerar_ddl('public')" > saidas/ddl_gerado.sql
```

---

## Clientes

- **psql**: linha de comando, usado nos comandos acima.
- **pgAdmin 4** (opcional): host `localhost`, porta `5432`, banco `chinook`, usuário `chinook`, senha `chinook`.
