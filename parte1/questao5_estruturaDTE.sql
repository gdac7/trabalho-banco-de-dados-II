-- Observações importantes:
-- Esse script deve ser executado pelo usuário chinook
-- OBS: Reexecução: apaga e recria as tabelas do DTE (os estados e transições cadastrados são perdidos); depois dele, rode de novo questao5_status_invoice e questao5_situacao_customer

DROP TRIGGER IF EXISTS trg_invoice_status ON invoice;
DROP TABLE IF EXISTS tabela_transicao;
DROP TABLE IF EXISTS tabela_estado;

CREATE TABLE tabela_estado(
	nome_tabela varchar(500) NOT NULL,
	nome_coluna varchar(500) NOT NULL,
	nome_estado varchar(500) NOT NULL,
	tipo_estado varchar(15) NOT NULL
           CHECK (tipo_estado IN ('inicial', 'intermediario', 'final')),
	PRIMARY KEY (nome_tabela, nome_coluna, nome_estado)

);

CREATE TABLE tabela_transicao(
	nome_tabela varchar(500) NOT NULL,
	nome_coluna varchar(500) NOT NULL,
	estado_origem varchar(500) NOT NULL,
	estado_destino varchar(500) NOT NULL,
	PRIMARY KEY (nome_tabela, nome_coluna, estado_origem, estado_destino),
    FOREIGN KEY (nome_tabela, nome_coluna, estado_origem)
        REFERENCES tabela_estado (nome_tabela, nome_coluna, nome_estado),
    FOREIGN KEY (nome_tabela, nome_coluna, estado_destino)
        REFERENCES tabela_estado (nome_tabela, nome_coluna, nome_estado)
);
