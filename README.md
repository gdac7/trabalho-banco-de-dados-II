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
psql -h localhost -U chinook -d chinook -f src/<arquivo>.sql
```

Execute primeiro os arquivos da Parte 1 (`parte1_q1` a `parte1_q5`) e depois os da Parte 2. A Q5 é dividida em quatro arquivos numerados (`parte1_q5_1` a `parte1_q5_4`), que devem rodar nessa ordem. Para recomeçar do zero, repita os passos 3 e 4.

Os testes ficam em `testes/` e seguem o mesmo padrão:

```bash
psql -h localhost -U chinook -d chinook -f testes/<arquivo>.sql
```

> Atenção: o teste da **Q2** (remover índices) roda dentro de `BEGIN; ... ROLLBACK;`, para não apagar de vez a chave primária de `track` (e as FKs que apontam para ela), o que alteraria o resultado das demais questões.

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
