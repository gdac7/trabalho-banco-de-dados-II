-- Observações importantes:
-- Esse script deve ser executado pelo usuário chinook
-- Reexecução: só funciona após rodar questao5_estruturaDTE de novo; senão os INSERTs no DTE falham por chave duplicada

/* DTE de invoice.status
	
	   ●
	   │
	   ▼
	┌─────────┐     ┌──────────┐     ┌─────────────────┐     ┌──────────────┐
	│ criado  │ ──▶ │ pendente │ ──▶ │ vendo_pagamento │ ──▶ │ em_transicao │
	│(inicial)│     └──────────┘     └─────────────────┘     └──────────────┘
	└─────────┘                                                 │          │
	                                                            ▼          ▼
	                                                    ╔══════════╗  ╔═══════════╗
	                                                    ║ aprovado ║  ║ reprovado ║
	                                                    ║ (final)  ║  ║  (final)  ║
	                                                    ╚══════════╝  ╚═══════════╝

*/

INSERT INTO tabela_estado(nome_tabela, nome_coluna, nome_estado, tipo_estado) VALUES
	('invoice', 'status', 'criado', 'inicial'),
	('invoice', 'status', 'pendente', 'intermediario'),
	('invoice', 'status', 'vendo_pagamento', 'intermediario'),
	('invoice', 'status', 'em_transicao', 'intermediario'),
	('invoice', 'status', 'aprovado', 'final'),	
	('invoice', 'status', 'reprovado', 'final');

INSERT INTO tabela_transicao (nome_tabela, nome_coluna, estado_origem, estado_destino) VALUES
    ('invoice', 'status', 'criado', 'pendente'),
    ('invoice', 'status', 'pendente', 'vendo_pagamento'),
    ('invoice', 'status', 'vendo_pagamento', 'em_transicao'),
    ('invoice', 'status', 'em_transicao', 'aprovado'),
    ('invoice', 'status', 'em_transicao', 'reprovado');

ALTER TABLE invoice ADD COLUMN IF NOT EXISTS status varchar(500);
UPDATE invoice SET status = 'criado' WHERE status IS NULL;  -- linhas existentes, antes de o trigger existir

CREATE OR REPLACE TRIGGER trg_invoice_status
BEFORE INSERT OR UPDATE ON invoice
FOR EACH ROW EXECUTE FUNCTION trg_validar_dte('status');