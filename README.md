# Biblioteca Comunitária em Docker

Laboratório de **Computação em Nuvem** — containerização de uma aplicação web com Docker Compose.

**Alunos:** Brendon e Leonardo  
**Professor:** Augusto  
**Disciplina:** Fundamentos de Computação em Nuvem

---

## Objetivo

O sistema já vinha pronto (API, interface e script SQL). O trabalho foi **criar apenas a infraestrutura Docker** para executá-lo:

- `Dockerfile` — imagem personalizada da aplicação Node.js
- `.dockerignore` — filtro do contexto de build
- `compose.yaml` — serviços, rede, volume e dependências

Nenhum arquivo do código original foi alterado.

---

## Tecnologias

| Camada | Tecnologia |
|---|---|
| API | Node.js 20 + Express |
| Frontend | HTML, CSS, JavaScript |
| Banco | PostgreSQL 16 (imagem oficial `postgres:16-alpine`) |
| Containerização | Docker + Docker Compose |
| Rede | bridge |
| Persistência | volume nomeado |

---

## Estrutura do projeto

```
.
├── Dockerfile              # imagem da aplicação (criado por nós)
├── .dockerignore           # filtro do build (criado por nós)
├── compose.yaml            # serviços, rede, volume (criado por nós)
├── README.md               # este arquivo
├── CONTEXTO-PARA-AMIGO.md  # explicação detalhada
├── APRESENTACAO.md         # roteiro para apresentar
├── APRESENTACAO-SLIDES.html# slides locais (opcional)
├── package.json            # dependências (original)
├── server.js               # API Express (original)
├── config.json             # configuração dos campos (original)
├── database/
│   └── init.sql            # cria a tabela e 3 livros (original)
└── public/
    ├── index.html          # interface (original)
    ├── script.js           # requisições à API (original)
    └── style.css           # estilos (original)
```

---

## Arquitetura

```
Navegador :3000  ->  biblioteca-app (Node/Express)  --rede bridge (db)-->  biblioteca-db (PostgreSQL)
                                                                              |
                                                                        volume pgdata
```

- A API acessa o banco pelo **nome do serviço `db`**, não por IP.
- O banco **não** publica porta no host — apenas a API expõe `3000:3000`.
- O `init.sql` é montado em `/docker-entrypoint-initdb.d/init.sql:ro` e roda só no primeiro start.
- O volume `pgdata` garante que os dados sobrevivam à recriação dos containers.

---

## Como executar

```bash
cd 02-biblioteca
docker compose up -d --build
docker compose ps
```

Acesse **http://localhost:3000**.

Para reiniciar mantendo os dados:

```bash
docker compose down
docker compose up -d
```

> Nunca use `docker compose down -v` — isso apaga o volume.

---

## Comandos que o aluno deve saber

```bash
docker compose up -d --build
docker compose ps
docker images
docker ps
docker network ls
docker network inspect 02-biblioteca_biblioteca-net
docker volume ls
docker compose logs
docker compose stop
docker compose start
docker compose down
docker compose up -d
```

---

## Funcionalidades

A interface permite:

- Cadastrar livro (título, autor, gênero, ano)
- Listar registros
- Atualizar registro
- Excluir registro
- Pesquisar registros

Endpoints da API:

| Método | Rota | Ação |
|---|---|---|
| GET | `/api/health` | verifica conexão com o banco |
| GET | `/api/config` | configuração da interface |
| GET | `/api/itens` | lista livros |
| POST | `/api/itens` | cria livro |
| PUT | `/api/itens/:id` | atualiza livro |
| DELETE | `/api/itens/:id` | exclui livro |

---

## Testes realizados

| Teste | Resultado |
|---|---|
| Build e subida dos containers | OK |
| Health check | HTTP 200 — `database conectado` |
| POST / GET / PUT / DELETE | 201 / 200 / 200 / 204 |
| init.sql | 3 livros carregados |
| `down` + `up` sem `-v` | dados preservados |
| Reboot da VM | registro id 107 preservado |
| 12 comandos do professor | todos executados |

Validação independente por 4 modelos: notas **9,5 / 9,0 / 10,0 / 8,5**.

---

## Arquivos de apoio

- **`CONTEXTO-PARA-AMIGO.md`** — explicação completa, com arquitetura, comandos, dicas e respostas para perguntas do professor.
- **`APRESENTACAO.md`** — roteiro passo a passo para a apresentação prática.
- **`APRESENTACAO-SLIDES.html`** — apresentação ilustrada local (abra no navegador; use ← → para navegar).

---

## Resumo para apresentar

> "O sistema veio pronto. Nós criamos só o Dockerfile, o .dockerignore e o compose.yaml. O Dockerfile gera a imagem da aplicação, o compose sobe dois containers — a API Node e o PostgreSQL — conectados por uma rede bridge. A API fala com o banco pelo nome do serviço `db`. O script init.sql cria a tabela na primeira subida, e um volume nomeado guarda os dados, que permanecem mesmo depois de recriarmos os containers ou reiniciarmos a VM."
