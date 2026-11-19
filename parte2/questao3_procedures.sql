-- Observações:
-- Esse script deve ser executado pelo usuário chinook
-- Procedimentos armazenados que validam as regras semânticas RS1 a RS4 (questao1_regras_semanticas).
-- A RS5 (total da invoice) é garantida por triggers na Q4.
--
-- Todos os procedimentos são SECURITY DEFINER: executam com os privilégios do dono (chinook),
-- e não de quem chama. Assim o usuário chinook_app, que não pode alterar as tabelas diretamente
-- (questao3_permissoes), consegue manipular os dados, mas só por aqui, passando pelas validações.
-- SET search_path fixa onde os procedimentos procuram as tabelas, para que quem chama não consiga
-- trocá-las por objetos com o mesmo nome.
--
-- Concorrência: cada procedimento trava, em SHARE ROW EXCLUSIVE, as tabelas que a sua validação
-- consulta. Esse modo continua permitindo leituras, mas impede que duas operações que alteram
-- essas tabelas validem ao mesmo tempo e passem juntas por uma checagem que, somadas, violariam.


-- 0) Ajuste de esquema exigido pela RS1: o Chinook não tem salário em employee.
-- IF NOT EXISTS / WHERE salary IS NULL: se a coluna já tiver sido criada (ex.: pela Q2), nada muda.
ALTER TABLE employee ADD COLUMN IF NOT EXISTS salary NUMERIC(10,2);

-- Salários iniciais por cargo, respeitando a RS1 (ninguém ganha mais que o supervisor)
UPDATE employee
   SET salary = CASE title
                    WHEN 'General Manager'     THEN 20000
                    WHEN 'Sales Manager'       THEN 12000
                    WHEN 'IT Manager'          THEN 12000
                    WHEN 'IT Staff'            THEN 6000
                    WHEN 'Sales Support Agent' THEN 5000
                END
 WHERE salary IS NULL;


-- =====================================================================
-- RS1 - Um funcionário não pode ganhar mais que o seu supervisor (reports_to)
-- Operações que podem violar: cadastrar funcionário, alterar salário, alterar supervisor
-- =====================================================================

-- 1) Cadastra um funcionário: o salário não pode passar o do supervisor
CREATE OR REPLACE PROCEDURE cadastrar_funcionario(
    p_employee_id INT,
    p_first_name  VARCHAR,
    p_last_name   VARCHAR,
    p_title       VARCHAR,
    p_reports_to  INT,
    p_salary      NUMERIC
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_salario_supervisor NUMERIC;
BEGIN
    LOCK TABLE employee IN SHARE ROW EXCLUSIVE MODE;

    IF p_salary IS NULL OR p_salary <= 0 THEN
        RAISE EXCEPTION 'ERRO! O salário deve ser informado e maior que zero';
    END IF;

    IF p_reports_to IS NOT NULL THEN
        SELECT salary INTO v_salario_supervisor FROM employee WHERE employee_id = p_reports_to;
        IF NOT FOUND THEN
            RAISE EXCEPTION 'ERRO! Supervisor % não existe', p_reports_to;
        END IF;
        IF p_salary > v_salario_supervisor THEN
            RAISE EXCEPTION 'ERRO! RS1: salário % maior que o do supervisor % (%)',
                p_salary, p_reports_to, v_salario_supervisor;
        END IF;
    END IF;

    INSERT INTO employee (employee_id, first_name, last_name, title, reports_to, salary)
    VALUES (p_employee_id, p_first_name, p_last_name, p_title, p_reports_to, p_salary);
END;
$$;


-- 2) Altera o salário: não pode passar o do supervisor nem ficar abaixo do de um subordinado direto
CREATE OR REPLACE PROCEDURE alterar_salario_funcionario(
    p_employee_id INT,
    p_salary      NUMERIC
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_supervisor           INT;
    v_salario_supervisor   NUMERIC;
    v_maior_salario_subord NUMERIC;
BEGIN
    LOCK TABLE employee IN SHARE ROW EXCLUSIVE MODE;

    IF p_salary IS NULL OR p_salary <= 0 THEN
        RAISE EXCEPTION 'ERRO! O salário deve ser informado e maior que zero';
    END IF;

    SELECT reports_to INTO v_supervisor FROM employee WHERE employee_id = p_employee_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'ERRO! Funcionário % não existe', p_employee_id;
    END IF;

    -- lado do supervisor
    IF v_supervisor IS NOT NULL THEN
        SELECT salary INTO v_salario_supervisor FROM employee WHERE employee_id = v_supervisor;
        IF p_salary > v_salario_supervisor THEN
            RAISE EXCEPTION 'ERRO! RS1: salário % maior que o do supervisor % (%)',
                p_salary, v_supervisor, v_salario_supervisor;
        END IF;
    END IF;

    -- lado dos subordinados diretos
    SELECT max(salary) INTO v_maior_salario_subord FROM employee WHERE reports_to = p_employee_id;
    IF p_salary < v_maior_salario_subord THEN
        RAISE EXCEPTION 'ERRO! RS1: salário % menor que o de um subordinado direto (%)',
            p_salary, v_maior_salario_subord;
    END IF;

    UPDATE employee SET salary = p_salary WHERE employee_id = p_employee_id;
END;
$$;


-- 3) Troca o supervisor: o funcionário não pode ganhar mais que o novo supervisor
CREATE OR REPLACE PROCEDURE alterar_supervisor_funcionario(
    p_employee_id INT,
    p_reports_to  INT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_salario            NUMERIC;
    v_salario_supervisor NUMERIC;
BEGIN
    LOCK TABLE employee IN SHARE ROW EXCLUSIVE MODE;

    SELECT salary INTO v_salario FROM employee WHERE employee_id = p_employee_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'ERRO! Funcionário % não existe', p_employee_id;
    END IF;

    IF p_reports_to IS NOT NULL THEN
        SELECT salary INTO v_salario_supervisor FROM employee WHERE employee_id = p_reports_to;
        IF NOT FOUND THEN
            RAISE EXCEPTION 'ERRO! Supervisor % não existe', p_reports_to;
        END IF;
        IF v_salario > v_salario_supervisor THEN
            RAISE EXCEPTION 'ERRO! RS1: o funcionário % ganha % e o novo supervisor % ganha %',
                p_employee_id, v_salario, p_reports_to, v_salario_supervisor;
        END IF;
    END IF;

    UPDATE employee SET reports_to = p_reports_to WHERE employee_id = p_employee_id;
END;
$$;


-- =====================================================================
-- RS2 - O funcionário associado a um cliente (support_rep_id) precisa ter o title
-- 'Sales Support Agent'
-- Operações que podem violar: cadastrar cliente, trocar o representante do cliente,
-- e trocar o cargo de um funcionário que já atende clientes
-- =====================================================================

-- 4) Cadastra um cliente (situacao 'cadastrado', estado inicial do DTE da Q5 da Parte 1)
CREATE OR REPLACE PROCEDURE cadastrar_cliente(
    p_customer_id    INT,
    p_first_name     VARCHAR,
    p_last_name      VARCHAR,
    p_email          VARCHAR,
    p_support_rep_id INT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_title employee.title%TYPE;
BEGIN
    LOCK TABLE employee, customer IN SHARE ROW EXCLUSIVE MODE;

    IF p_support_rep_id IS NOT NULL THEN
        SELECT title INTO v_title FROM employee WHERE employee_id = p_support_rep_id;
        IF NOT FOUND THEN
            RAISE EXCEPTION 'ERRO! Funcionário % não existe', p_support_rep_id;
        END IF;
        IF v_title IS DISTINCT FROM 'Sales Support Agent' THEN
            RAISE EXCEPTION 'ERRO! RS2: o funcionário % é % e não Sales Support Agent',
                p_support_rep_id, coalesce(v_title, 'sem cargo');
        END IF;
    END IF;

    INSERT INTO customer (customer_id, first_name, last_name, email, support_rep_id, situacao)
    VALUES (p_customer_id, p_first_name, p_last_name, p_email, p_support_rep_id, 'cadastrado');
END;
$$;


-- 5) Troca o representante de um cliente
CREATE OR REPLACE PROCEDURE alterar_representante_cliente(
    p_customer_id    INT,
    p_support_rep_id INT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_title employee.title%TYPE;
BEGIN
    LOCK TABLE employee, customer IN SHARE ROW EXCLUSIVE MODE;

    IF NOT EXISTS (SELECT 1 FROM customer WHERE customer_id = p_customer_id) THEN
        RAISE EXCEPTION 'ERRO! Cliente % não existe', p_customer_id;
    END IF;

    IF p_support_rep_id IS NOT NULL THEN
        SELECT title INTO v_title FROM employee WHERE employee_id = p_support_rep_id;
        IF NOT FOUND THEN
            RAISE EXCEPTION 'ERRO! Funcionário % não existe', p_support_rep_id;
        END IF;
        IF v_title IS DISTINCT FROM 'Sales Support Agent' THEN
            RAISE EXCEPTION 'ERRO! RS2: o funcionário % é % e não Sales Support Agent',
                p_support_rep_id, coalesce(v_title, 'sem cargo');
        END IF;
    END IF;

    UPDATE customer SET support_rep_id = p_support_rep_id WHERE customer_id = p_customer_id;
END;
$$;


-- 6) Troca o cargo de um funcionário: quem atende clientes não pode deixar de ser Sales Support Agent
CREATE OR REPLACE PROCEDURE alterar_cargo_funcionario(
    p_employee_id INT,
    p_title       VARCHAR
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_qtd_clientes INT;
BEGIN
    LOCK TABLE employee, customer IN SHARE ROW EXCLUSIVE MODE;

    IF NOT EXISTS (SELECT 1 FROM employee WHERE employee_id = p_employee_id) THEN
        RAISE EXCEPTION 'ERRO! Funcionário % não existe', p_employee_id;
    END IF;

    IF p_title IS DISTINCT FROM 'Sales Support Agent' THEN
        SELECT count(*) INTO v_qtd_clientes FROM customer WHERE support_rep_id = p_employee_id;
        IF v_qtd_clientes > 0 THEN
            RAISE EXCEPTION 'ERRO! RS2: o funcionário % atende % clientes e precisa continuar Sales Support Agent',
                p_employee_id, v_qtd_clientes;
        END IF;
    END IF;

    UPDATE employee SET title = p_title WHERE employee_id = p_employee_id;
END;
$$;


-- =====================================================================
-- RS3 - Um cliente não pode comprar a mesma faixa mais de uma vez
-- Operações: criar a invoice (sem linhas, não viola nada) e adicionar linhas
-- =====================================================================

-- 7) Cria uma invoice vazia para o cliente.
-- O endereço de cobrança vem do cadastro do cliente; o status começa em 'criado' (DTE da Q5 da Parte 1)
-- e o total em 0 (o trigger da Q4 zera o total no INSERT de qualquer forma).
CREATE OR REPLACE PROCEDURE criar_fatura(
    p_invoice_id  INT,
    p_customer_id INT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_cliente customer%ROWTYPE;
BEGIN
    SELECT * INTO v_cliente FROM customer WHERE customer_id = p_customer_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'ERRO! Cliente % não existe', p_customer_id;
    END IF;

    INSERT INTO invoice (invoice_id, customer_id, invoice_date,
                         billing_address, billing_city, billing_state,
                         billing_country, billing_postal_code, total, status)
    VALUES (p_invoice_id, p_customer_id, now(),
            v_cliente.address, v_cliente.city, v_cliente.state,
            v_cliente.country, v_cliente.postal_code, 0, 'criado');
END;
$$;


-- 8) Adiciona uma faixa a uma invoice: o cliente da invoice não pode já ter comprado essa faixa,
-- em nenhuma das suas invoices (inclusive a atual).
-- O preço vem da tabela track; o total da invoice é atualizado pelo trigger da Q4 (RS5).
-- A quantidade é sempre 1: como a faixa é mídia digital, quantity > 1 seria comprar a mesma faixa
-- mais de uma vez na mesma linha, o que a RS3 proíbe.
CREATE OR REPLACE PROCEDURE adicionar_item_fatura(
    p_invoice_line_id INT,
    p_invoice_id      INT,
    p_track_id        INT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_cliente     INT;
    v_preco       NUMERIC;
    v_invoice_ant INT;
BEGIN
    LOCK TABLE invoice, invoice_line IN SHARE ROW EXCLUSIVE MODE;

    SELECT customer_id INTO v_cliente FROM invoice WHERE invoice_id = p_invoice_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'ERRO! Invoice % não existe', p_invoice_id;
    END IF;

    SELECT unit_price INTO v_preco FROM track WHERE track_id = p_track_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'ERRO! Faixa % não existe', p_track_id;
    END IF;

    SELECT il.invoice_id INTO v_invoice_ant
      FROM invoice_line il
      JOIN invoice i ON i.invoice_id = il.invoice_id
     WHERE i.customer_id = v_cliente
       AND il.track_id   = p_track_id
     LIMIT 1;
    IF FOUND THEN
        RAISE EXCEPTION 'ERRO! RS3: o cliente % já comprou a faixa % (invoice %)',
            v_cliente, p_track_id, v_invoice_ant;
    END IF;

    INSERT INTO invoice_line (invoice_line_id, invoice_id, track_id, unit_price, quantity)
    VALUES (p_invoice_line_id, p_invoice_id, p_track_id, v_preco, 1);
END;
$$;


-- =====================================================================
-- RS4 - Uma playlist não pode ter mais de 500 faixas
-- OBS: no Chinook original as playlists 1, 5 e 8 já passam de 500; o procedimento
-- impede que elas recebam novas faixas, mas não remove as que já existem.
-- =====================================================================

-- 9) Adiciona uma faixa a uma playlist
CREATE OR REPLACE PROCEDURE adicionar_faixa_playlist(
    p_playlist_id INT,
    p_track_id    INT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_qtd_faixas INT;
BEGIN
    LOCK TABLE playlist_track IN SHARE ROW EXCLUSIVE MODE;

    IF NOT EXISTS (SELECT 1 FROM playlist WHERE playlist_id = p_playlist_id) THEN
        RAISE EXCEPTION 'ERRO! Playlist % não existe', p_playlist_id;
    END IF;

    SELECT count(*) INTO v_qtd_faixas FROM playlist_track WHERE playlist_id = p_playlist_id;
    IF v_qtd_faixas >= 500 THEN
        RAISE EXCEPTION 'ERRO! RS4: a playlist % já tem % faixas (máximo 500)',
            p_playlist_id, v_qtd_faixas;
    END IF;

    INSERT INTO playlist_track (playlist_id, track_id) VALUES (p_playlist_id, p_track_id);
END;
$$;
