-- Este script é executado apenas ao inicializar um diretório de dados PostgreSQL vazio.
CREATE TABLE IF NOT EXISTS livros (id SERIAL PRIMARY KEY, titulo VARCHAR(180) NOT NULL, autor VARCHAR(120) NOT NULL, genero VARCHAR(80) NOT NULL, ano INTEGER NOT NULL CHECK (ano BETWEEN 1450 AND 2100), created_at TIMESTAMPTZ NOT NULL DEFAULT NOW());
INSERT INTO livros (titulo,autor,genero,ano) VALUES ('Dom Casmurro','Machado de Assis','Romance',1899),('O Cortiço','Aluísio Azevedo','Romance',1890),('Vidas Secas','Graciliano Ramos','Ficção',1938);
