# Contexto do Projeto — Biblioteca Comunitária em Docker

Olá! Este arquivo explica **tudo** sobre este projeto para que você consiga entender, executar e apresentar sem dúvidas.

---

## 1. Sobre o que é este trabalho

É um laboratório da disciplina **Fundamentos de Computação em Nuvem** (professor Augusto). O professor entregou uma aplicação web pronta e pediu para os alunos **apenas containerizá-la** — ou seja, criar a infraestrutura Docker para executá-la.

**Ponto importante:** o código da aplicação já vinha pronto. Não foi preciso programar nada. O trabalho foi criar somente **três arquivos de infraestrutura**:

| Arquivo | Para que serve |
|---|---|
| `Dockerfile` | Constrói a imagem personalizada da aplicação Node.js |
| `.dockerignore` | Diz ao Docker o que **não** copiar para dentro da imagem |
| `compose.yaml` | Define os serviços, rede, volume e como tudo sobe junto |

Tudo o mais (`server.js`, `config.json`, `public/`, `database/init.sql`, `package.json`) são os arquivos originais fornecidos pelo professor e **não foram modificados**.

---

## 2. O que a aplicação faz

É uma **Biblioteca Comunitária**: um CRUD de livros.

- Cadastrar livro (título, autor, gênero, ano)
- Listar livros
- Atualizar livro
- Excluir livro
- Pesquisar livros

Tecnologias: **Node.js 20 + Express** (API e interface) e **PostgreSQL 16** (banco de dados).

---

## 3. Arquitetura montada

```
Navegador (localhost:3000)
        |
        v
+-----------------------------+        rede bridge
| biblioteca-app              | <-------------------->  +---------------------+
| Node.js 20 + Express        |     DB_HOST=db           | biblioteca-db       |
| imagem: 02-biblioteca-app   |     (nome do serviço)    | postgres:16-alpine  |
+-----------------------------+                          +----------+----------+
                                                                    |
                                                           volume pgdata
                                                    /var/lib/postgresql/data
                                                                    |
                                            init.sql -> /docker-entrypoint-initdb.d/
```

**Pontos-chave para explicar:**

- São **dois containers**: um com a API e outro com o banco.
- A API conecta no banco pelo **nome do serviço `db`**, não por IP fixo. O Docker resolve esse nome pela rede interna (DNS do Docker).
- O banco **não publica porta no host** — só a API expõe a porta 3000.
- O `init.sql` cria a tabela `livros` e insere 3 livros (Dom Casmurro, O Cortiço, Vidas Secas). Ele roda **apenas na primeira inicialização**, quando o volume está vazio.
- O volume `pgdata` guarda os dados **fora** do container. Por isso, recriar o container não apaga os registros.
- O `healthcheck` usa `pg_isready` para esperar o banco ficar pronto antes de subir a API (`depends_on: condition: service_healthy`).

---

## 4. Como executar do zero

Pré-requisito: ter Docker e Docker Compose instalados.

```bash
# Entre na pasta do projeto
cd 02-biblioteca

# Construa a imagem e suba os dois containers
docker compose up -d --build

# Verifique se estão rodando
docker compose ps
```

Acesse **http://localhost:3000** no navegador.

Para descer e subir de novo:

```bash
docker compose down      # NÃO use -v, senão apaga o volume
docker compose up -d
```

---

## 5. Os 12 comandos que o professor pede saber

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

### O que cada um mostra

| Comando | O que você vê / deve explicar |
|---|---|
| `up -d --build` | cria a imagem `02-biblioteca-app` e sobe os dois containers |
| `compose ps` | `biblioteca-app` Up na porta 3000 e `biblioteca-db` Up (healthy) |
| `images` | as imagens `02-biblioteca-app` e `postgres:16-alpine` |
| `docker ps` | os containers em execução com suas portas |
| `network ls` | a rede `02-biblioteca_biblioteca-net` (driver bridge) |
| `network inspect ...` | os dois containers conectados na rede, com IPs internos |
| `volume ls` | o volume `02-biblioteca_pgdata` |
| `compose logs` | a API em `localhost:3000` e o PostgreSQL `ready to accept connections` |
| `stop` / `start` | para e inicia os containers sem removê-los |
| `down` / `up -d` | remove e recria — os dados permanecem |

**Nunca use `docker compose down -v` no teste de persistência:** o `-v` remove o volume e apaga os dados.

---

## 6. Explicação dos arquivos criados

### Dockerfile
```dockerfile
FROM node:20-alpine
WORKDIR /app
COPY package.json ./
RUN npm install --omit=dev && npm cache clean --force
COPY . .
ENV PORT=3000
ENV NODE_ENV=production
EXPOSE 3000
CMD ["npm", "start"]
```
- `node:20-alpine`: imagem oficial, LTS e leve.
- Copia `package.json` primeiro para aproveitar o cache de camadas.
- `--omit=dev`: instala só as dependências de produção (express, pg, dotenv).
- `CMD ["npm","start"]`: executa `node server.js`.

### .dockerignore
Exclui `node_modules`, `.env`, `.git`, documentação, logs e arquivos de mídia. Isso evita que arquivos desnecessários entrem na imagem. **Ele mesmo não vai para dentro da imagem** — é uma instrução usada apenas no build.

### compose.yaml
Define:
- serviço `db` com `postgres:16-alpine`, `POSTGRES_DB/USER/PASSWORD`, volume `pgdata`, montagem do `init.sql` como `:ro` e healthcheck;
- serviço `app` com `build: .`, variáveis `DB_*`, porta `3000:3000` e `depends_on` com `condition: service_healthy`;
- rede bridge `biblioteca-net` e o volume nomeado `pgdata` na raiz do arquivo.

**Atenção:** `POSTGRES_*` configura a imagem do PostgreSQL; `DB_*` configura a aplicação Node.js. Os valores precisam combinar entre si.

---

## 7. Testes realizados (todos aprovados)

| Teste | Resultado |
|---|---|
| Build e subida | imagem criada, dois containers Up, banco healthy |
| Health check | HTTP 200 — `{"status":"ok","database":"conectado"}` |
| Cadastrar (POST) | HTTP 201 |
| Listar (GET) | HTTP 200 |
| Atualizar (PUT) | HTTP 200 |
| Excluir (DELETE) | HTTP 204 |
| init.sql | 3 livros carregados na primeira subida |
| `Skipping initialization` | apareceu na segunda subida — prova de que o SQL não roda de novo |
| Persistência com `down`/`up` | registro permaneceu |
| Persistência com reboot da VM | registro id 107 permaneceu depois de desligar e ligar a máquina |
| 12 comandos | todos executados na VM |

---

## 8. Comprovação dos testes

Todos os testes foram executados e aprovados (ver seção 7). Se você quiser refazer a verificação, execute os comandos da seção 5 e confira:

- `docker compose ps` → os dois serviços Up, banco healthy
- `curl http://localhost:3000/api/health` → `{"status":"ok","database":"conectado"}`
- cadastre um livro, rode `docker compose down` + `docker compose up -d` e confirme que ele continuou na lista

---

## 9. Apresentação ilustrativa

Há também o arquivo `APRESENTACAO.md` com o roteiro completo passo a passo (o que fazer e o que falar em cada momento), incluindo perguntas que o professor pode fazer e respostas prontas.

O arquivo `APRESENTACAO-SLIDES.html` é uma versão local em slides (abra no navegador e use as setas para navegar), caso queira usar sem internet.

---

## 10. Dicas para apresentar

1. Abra o terminal e rode `docker compose ps` — mostre os dois serviços Up.
2. Abra `localhost:3000` no navegador — mostre a lista de livros.
3. Cadastre um livro, edite e exclua pela interface.
4. Rode `docker network ls` e `docker volume ls` — explique rede e persistência.
5. Rode `docker compose logs` — mostre a conexão do Node com o PostgreSQL.
6. Para a persistência: cadastre um livro, rode `docker compose down`, depois `docker compose up -d`, e mostre que o livro continua.
7. Explique que vocês **não programaram** — só criaram `Dockerfile`, `.dockerignore` e `compose.yaml`.

---

## 11. Problemas comuns e soluções

| Sintoma | Causa provável | Solução |
|---|---|---|
| API retorna 503 | banco não pronto | conferir logs e healthcheck |
| `ECONNREFUSED` / `getaddrinfo ENOTFOUND db` | `DB_HOST` como localhost | usar `DB_HOST=db` |
| Livros iniciais não aparecem | volume antigo | usar volume novo para o `init.sql` rodar |
| `init.sql` não executa | diretório de dados já populado | é normal; só roda no primeiro start |
| Porta 3000 ocupada | outro processo usando a porta | parar o processo ou trocar para `3001:3000` |

---

## 12. Perguntas que o professor pode fazer — respostas curtas

**Por que dois containers?**
Para separar responsabilidades: a API pode ser recriada sem afetar os dados do banco.

**Como a API encontra o banco?**
Pelo nome do serviço `db`, resolvido pelo DNS interno da rede Docker.

**O que acontece se eu remover o container do banco?**
Os dados não são perdidos, porque ficam no volume `pgdata`.

**O `init.sql` roda toda vez?**
Não. Só quando o diretório de dados está vazio (primeira inicialização).

**Qual a diferença entre `down` e `down -v`?**
`down` remove containers e rede, mas mantém o volume. `down -v` remove também o volume e apaga os dados.

**Por que `EXPOSE 3000` se o Compose já mapeia a porta?**
`EXPOSE` documenta a porta da imagem; o `ports:` do Compose é que publica no host.

---

Pronto! Com este arquivo e o vídeo, dá para entender e apresentar o trabalho tranquilamente.
