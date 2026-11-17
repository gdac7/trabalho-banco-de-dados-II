-- Observações:
-- Esse script deve ser executado pelo usuário chinook
-- Reexecução: só funciona após rodar questao5_estruturaDTE de novo; senão os INSERTs no DTE falham por chave duplicada

/* DTE de customer.situacao: mesmas funções e trigger da invoice, só os dados do DTE mudam

	   ●
	   │
	   ▼
	┌────────────┐     ┌─────────┐ ──▶ ┌──────────┐
	│ cadastrado │ ──▶ │  ativo  │     │ suspenso │
	│ (inicial)  │     └─────────┘ ◀── └──────────┘
	└────────────┘          │               │
	                        │               │
	                        ▼               ▼
	                    ╔═══════════════════════════╗
	                    ║     inativo  (final)      ║
	                    ╚═══════════════════════════╝
*/

INSERT INTO tabela_estado(nome_tabela, nome_coluna, nome_estado, tipo_estado) VALUES
	('customer', 'situacao', 'cadastrado', 'inicial'),
	('customer', 'situacao', 'ativo', 'intermediario'),
	('customer', 'situacao', 'suspenso', 'intermediario'),
	('customer', 'situacao', 'inativo', 'final');

INSERT INTO tabela_transicao (nome_tabela, nome_coluna, estado_origem, estado_destino) VALUES
    ('customer', 'situacao', 'cadastrado', 'ativo'),
    ('customer', 'situacao', 'ativo', 'suspenso'),
    ('customer', 'situacao', 'suspenso', 'ativo'),
    ('customer', 'situacao', 'ativo', 'inativo'),
    ('customer', 'situacao', 'suspenso', 'inativo');

ALTER TABLE customer ADD COLUMN IF NOT EXISTS situacao varchar(500);
UPDATE customer SET situacao = 'ativo' WHERE situacao IS NULL;  -- linhas existentes, antes de o trigger existir

CREATE OR REPLACE TRIGGER trg_customer_situacao
BEFORE INSERT OR UPDATE ON customer
FOR EACH ROW EXECUTE FUNCTION trg_validar_dte('situacao');