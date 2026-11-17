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
\dt                           -- 11 tabelas
SELECT count(*) FROM track;   -- 3503
```

## 5. Rodar os scripts das questões

```bash
psql -h localhost -U chinook -d chinook -f parte1/<arquivo>.sql
```

Os arquivos ficam em `parte1/` e `parte2/`, um por questão (`questaoN_...`), junto com os seus testes. Execute primeiro a Parte 1 e depois a Parte 2. A Q5 tem quatro arquivos que devem rodar nesta ordem: `questao5_estruturaDTE`, `questao5_functions_triggers`, `questao5_status_invoice` e `questao5_situacao_customer`; os testes (`questao5_teste_status` e `questao5_teste_situacao`) vêm depois. Na Parte 2, a Q1 (`parte2/questao1_regras_semanticas.sql`) contém só a descrição textual das regras semânticas e não precisa ser executada. A Q3 tem quatro arquivos, nesta ordem: `questao3_criar_usuario` (rodado pelo **postgres**, porque o usuário `chinook` não pode criar usuários), `questao3_procedures`, `questao3_permissoes` e o teste `questao3_teste_procedures` (estes três pelo `chinook`). O teste da Q3 deve ser rodado depois de `parte2/questao4_total_invoice.sql`, porque confere o total da invoice atualizado pelo trigger da Q4:

```bash
psql -h localhost -U postgres -d chinook -f parte2/questao3_criar_usuario.sql
psql -h localhost -U chinook  -d chinook -f parte2/questao3_procedures.sql
psql -h localhost -U chinook  -d chinook -f parte2/questao3_permissoes.sql
psql -h localhost -U chinook  -d chinook -f parte2/questao3_teste_procedures.sql
```

A Q4 é `parte2/questao4_total_invoice.sql`, com o teste em `parte2/questao4_teste_total_invoice.sql`. Para recomeçar do zero, repita os passos 3 e 4.

**Por que alguns testes terminam em `ROLLBACK`:** os testes da Q2 da Parte 1 (`questao2_teste_deletar_index`) e das Q3 e Q4 da Parte 2 (`questao3_teste_procedures` e `questao4_teste_total_invoice`) rodam dentro de `BEGIN; ... ROLLBACK;`. No PostgreSQL até o DDL é transacional, então o `ROLLBACK` desfaz tudo o que o teste fez:

- **Q2:** remover os índices de `track` apaga a chave primária e, junto, as chaves estrangeiras de `invoice_line` e `playlist_track` que apontam para ela. Sem o `ROLLBACK`, o esquema ficaria alterado e mudaria o resultado de outras questões (por exemplo, o DDL gerado pela Q4 da Parte 1).
- **Q3 da Parte 2:** o teste cadastra funcionário, cliente, invoices e uma playlist de teste (ids 9998/9999) e altera salários e representantes. Sem o `ROLLBACK`, esses dados ficariam no banco e a segunda execução falharia por chave duplicada.
- **Q4 da Parte 2:** o teste insere, altera e apaga dados (invoice 9999, `TRUNCATE` em `invoice_line`). Sem o `ROLLBACK`, esses dados ficariam no banco e a segunda execução falharia por chave duplicada.

O `ROLLBACK` desfaz só o que o teste fez: as procedures e triggers instaladas pelos scripts das questões continuam no banco. Os resultados aparecem na tela antes do `ROLLBACK`, então o teste demonstra o funcionamento do mesmo jeito.

Esses testes devem ser rodados pelo **psql** (`-f`), não pelo pgAdmin: eles usam comandos do psql (`\d` na Q2 e `\set ON_ERROR_ROLLBACK on` nas Q3 e Q4, que faz um comando que deve falhar não abortar o restante da transação).


## 6. Salvar a saída em arquivo

```bash
psql -h localhost -U chinook -d chinook -f <pasta>/<arquivo>.sql > saidas/<nome>.txt
```

Para obter só o texto, sem cabeçalho e sem bordas (ex.: o DDL gerado pela Q4, que pode ser executado depois):

```bash
psql -At -h localhost -U chinook -d chinook -c "SELECT * FROM gerar_ddl('public')" > saidas/ddl_gerado.sql
```

---

## Clientes

- **psql**: linha de comando, usado nos comandos acima.
- **pgAdmin 4** (opcional): host `localhost`, porta `5432`, banco `chinook`, usuário `chinook`, senha `chinook`.
