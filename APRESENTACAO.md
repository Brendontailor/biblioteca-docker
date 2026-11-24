# Apresentação Prática — Biblioteca Comunitária em Docker

**Disciplina:** Computação em Nuvem — Laboratório Docker
**Projeto escolhido:** 02-biblioteca (Biblioteca Comunitária)
**Infraestrutura:** Node.js 20 + Express + PostgreSQL 16 + Docker Compose

---

## 1. O que foi feito

O sistema já vinha pronto (API REST, interface web e script SQL). O trabalho foi
criar apenas os três arquivos de infraestrutura:

| Arquivo | Função |
|---|---|
| `Dockerfile` | Constrói a imagem personalizada da aplicação Node.js |
| `.dockerignore` | Evita que arquivos desnecessários entrem no contexto de build |
| `compose.yaml` | Define os dois serviços, a rede, o volume, as portas e a ordem de subida |

Nenhum arquivo do sistema original foi alterado.

---

## 2. Arquitetura

```
                         Navegador
                  http://localhost:3000
                             |
                             | 3000:3000 (publicado no host)
                             v
        +--------------------------------------+
        |  biblioteca-app                      |
        |  Node.js 20-alpine + Express         |
        |  imagem: 02-biblioteca-app            |
        |  DB_HOST=db                           |
        +--------------------------------------+
                             |
                             | rede bridge: 02-biblioteca_biblioteca-net
                             | nome do serviço "db" (resolução DNS interna)
                             | TCP 5432
                             v
        +--------------------------------------+
        |  biblioteca-db                       |
        |  postgres:16-alpine                  |
        |  POSTGRES_DB=laboratorio             |
        |  POSTGRES_USER=appuser               |
        +--------------------------------------+
                    |                    |
                    |                    | ./database/init.sql -> /docker-entrypoint-initdb.d/init.sql (ro)
                    |                    | executado só no primeiro start (volume vazio)
                    v
        volume nomeado: 02-biblioteca_pgdata
        montado em /var/lib/postgresql/data
```

**Pontos-chave para explicar:**

- São **dois containers**: um com a API e outro com o banco.
- A aplicação **não usa IP fixo**. Ela conecta em `db`, que é o nome do serviço no
  Compose. O Docker mantém um DNS interno na rede bridge e resolve `db` para o IP
  do container (no teste: `172.18.0.2`).
- O banco **não publica porta para o host**. Só a API é exposta na porta 3000.
- O volume nomeado `pgdata` guarda os dados fora do container. Por isso,
  `docker compose down` (sem `-v`) remove container e rede, mas **não apaga os dados**.

---

## 3. Explicação dos arquivos

### 3.1 Dockerfile

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

| Linha | Por que foi feita |
|---|---|
| `FROM node:20-alpine` | Imagem base oficial do Node.js. A variante `alpine` é menor e mais leve. |
| `WORKDIR /app` | Define o diretório de trabalho dentro da imagem; todos os `COPY` e comandos caem nele. |
| `COPY package.json ./` | Copia primeiro só o `package.json`. Assim, se o código mudar, a camada de instalação das dependências é reaproveitada do cache (build mais rápido). |
| `RUN npm install --omit=dev` | Instala apenas `express`, `pg` e `dotenv`, que são as dependências de produção. O `npm cache clean` reduz o tamanho da imagem. |
| `COPY . .` | Copia o resto da aplicação (`server.js`, `config.json`, `public/`, `database/`). |
| `ENV PORT=3000` | Valor padrão da porta; o Compose pode sobrescrever. |
| `EXPOSE 3000` | Documenta a porta que a aplicação escuta dentro do container. |
| `CMD ["npm", "start"]` | Executa o script `start` do `package.json`, que roda `node server.js`. |

### 3.2 .dockerignore

Exclui `node_modules`, `.env`, `.git`, `README.md`, `Dockerfile`, `compose.yaml`,
logs e arquivos temporários. Sem isso, as dependências locais (se existissem) e
arquivos desnecessários seriam enviados no contexto de build e poderiam sobrescrever
o que foi instalado dentro da imagem.

### 3.3 compose.yaml

- **`db`**: imagem `postgres:16-alpine`, banco `laboratorio`, usuário `appuser` e senha
  definidos nas variáveis `POSTGRES_*`. Monta o volume `pgdata` e o script `init.sql`
  em `/docker-entrypoint-initdb.d/` como **somente leitura** (`:ro`).
- **`healthcheck`**: roda `pg_isready` a cada 5 segundos. O serviço `app` espera o banco
  ficar `healthy` antes de iniciar (`depends_on: condition: service_healthy`). Isso
  evita o erro clássico de a API subir antes do PostgreSQL aceitar conexões.
- **`app`**: faz o build do `Dockerfile`, recebe as variáveis `DB_*`, publica
  `3000:3000` e entra na mesma rede `biblioteca-net`.
- **`volumes:`** e **`networks:`** na raiz declaram o volume nomeado e a rede bridge.

> **Diferença importante:** `POSTGRES_*` configura a imagem do PostgreSQL; `DB_*`
> configura a aplicação Node.js. São dois conjuntos distintos que precisam combinar
> (mesmo usuário, senha e nome de banco).

---

## 4. Roteiro de apresentação (passo a passo)

### Passo 1 — Subir a aplicação

```bash
cd ~/02-biblioteca
docker compose up -d --build
```

Mostrar na tela: download das imagens, build em 10 etapas, criação da rede e do
volume, containers `biblioteca-db` e `biblioteca-app` iniciados. O `healthy` do banco
aparece antes do app começar.

### Passo 2 — Verificar os serviços

```bash
docker compose ps
```

Resultado esperado:

```
NAME             IMAGE                SERVICE   STATUS                    PORTS
biblioteca-app   02-biblioteca-app    app       Up ...                    0.0.0.0:3000->3000/tcp
biblioteca-db    postgres:16-alpine   db        Up ... (healthy)          5432/tcp
```

Explicar que o banco está sem porta publicada: só a API é acessível de fora.

### Passo 3 — Abrir a aplicação

```bash
curl http://localhost:3000/api/health
```

Resultado: `{"status":"ok","database":"conectado"}`

Abrir `http://localhost:3000` no navegador. A interface mostra os três livros que
vieram do `init.sql`: Dom Casmurro, O Cortiço e Vidas Secas.

### Passo 4 — Testar o CRUD

Pelo navegador (ou pelo terminal):

```bash
# Cadastrar
curl -X POST http://localhost:3000/api/itens -H 'Content-Type: application/json' \
  -d '{"titulo":"Docker na Pratica","autor":"Equipe de Laboratorio","genero":"Tecnologia","ano":2026}'

# Listar
curl http://localhost:3000/api/itens

# Atualizar (usar o id retornado no cadastro)
curl -X PUT http://localhost:3000/api/itens/4 -H 'Content-Type: application/json' \
  -d '{"titulo":"Docker na Pratica - 2a edicao","autor":"Equipe de Laboratorio","genero":"Tecnologia","ano":2026}'

# Excluir
curl -X DELETE http://localhost:3000/api/itens/4
```

Resultados obtidos no teste: cadastro retornou `id: 4`, edição retornou o registro
alterado, exclusão retornou `HTTP 204` e a lista voltou aos três livros iniciais.

### Passo 5 — Mostrar rede, volumes e imagens

```bash
docker network ls
docker network inspect 02-biblioteca_biblioteca-net
docker volume ls
docker images
docker ps
```

O que destacar:

- Rede `02-biblioteca_biblioteca-net`, driver `bridge`.
- No `inspect`, os dois containers aparecem conectados: `biblioteca-db` em
  `172.18.0.2/16` e `biblioteca-app` em `172.18.0.3/16`.
- Volume `02-biblioteca_pgdata` (driver `local`).
- Imagem `02-biblioteca-app` criada a partir do Dockerfile.

### Passo 6 — Testar a persistência (obrigatório)

```bash
# 1) cadastre um livro novo
curl -X POST http://localhost:3000/api/itens -H 'Content-Type: application/json' \
  -d '{"titulo":"Persistencia Comprovada","autor":"Teste de Volume","genero":"Tecnologia","ano":2026}'

# 2) remova containers e rede (SEM -v!)
docker compose down

# 3) recrie
docker compose up -d

# 4) confira
curl http://localhost:3000/api/itens
```

Resultado obtido: o livro "Persistencia Comprovada" (id 5) continuou na lista depois
do `down` e do `up`. Isso prova que o volume nomeado funcionou.

> **Atenção:** não usar `docker compose down -v`. O `-v` remove os volumes nomeados e
> apagaria os dados — exatamente o que o teste de persistência quer evitar.

### Passo 7 — Logs e encerramento

```bash
docker compose logs
docker compose stop
docker compose start
docker compose down
```

Nos logs do banco, na segunda subida, aparece:
`PostgreSQL Database directory appears to contain a database;  Skipping initialization`.
Essa mensagem é a prova de que o `init.sql` **não** rodou de novo (ele só roda em
diretório de dados vazio) e que o volume foi reaproveitado.

---

## 5. Evidências reais coletadas

As saídas completas dos comandos estão no arquivo `evidencias.txt` ao lado deste
documento. A imagem `interface.png` mostra a aplicação em funcionamento no navegador,
com o registro "Persistencia Comprovada" visível na lista após a recriação dos containers.

Resumo:

| Verificação | Resultado |
|---|---|
| Build da imagem | `Successfully built` / `Successfully tagged 02-biblioteca-app:latest` |
| Healthcheck | `{"status":"ok","database":"conectado"}` |
| init.sql | 3 livros carregados na primeira inicialização |
| POST | HTTP 201, id 4 |  
| PUT | registro alterado retornado |
| DELETE | HTTP 204 |
| Rede | `02-biblioteca_biblioteca-net` (bridge), 2 containers conectados |
| Volume | `02-biblioteca_pgdata` |
| Persistência | registro id 5 sobreviveu ao `down` + `up` |
| Segunda subida | `Skipping initialization` no log do PostgreSQL |

---

## 6. Possíveis problemas e como resolver

| Sintoma | Causa provável | Solução |
|---|---|---|
| API retorna 503 | Banco ainda não estava pronto | Conferir `docker compose logs db` e o `healthcheck`; o `depends_on` já evita isso. |
| `ECONNREFUSED` / `getaddrinfo ENOTFOUND db` | `DB_HOST` como `localhost` dentro do container | Usar `DB_HOST=db` (nome do serviço). |
| Livros iniciais não aparecem | Volume antigo de outra atividade | Usar volume novo (remover o volume antigo antes) para que o `init.sql` rode. |
| `init.sql` não executa | Diretório de dados já populado | É o comportamento normal; limpar o volume apenas se quiser recriar o banco. |
| Porta 3000 ocupada | Outro processo usando a porta | Parar o processo ou trocar o mapeamento para `3001:3000`. |

---

## 7. Respostas para perguntas prováveis do professor

**Por que dois containers em vez de um?**
Para separar responsabilidades: a API é stateless e pode ser recriada sem afetar os
dados; o PostgreSQL é stateful e fica com o volume persistente.

**Como a API encontra o banco?**
Pelo nome do serviço `db`. O Docker oferece resolução DNS interna na rede bridge.

**O que acontece se eu removo o container do banco?**
Os dados não são perdidos, porque ficam no volume nomeado `pgdata`, montado em
`/var/lib/postgresql/data`.

**O script `init.sql` roda toda vez?**
Não. A imagem oficial do PostgreSQL executa scripts de `/docker-entrypoint-initdb.d/`
apenas quando o diretório de dados está vazio (primeira inicialização).

**Por que `EXPOSE 3000` se o Compose já mapeia a porta?**
`EXPOSE` documenta a porta da imagem; o mapeamento `ports:` no Compose é que publica
a porta no host.

**Por que `npm install --omit=dev`?**
Porque `express`, `pg` e `dotenv` são as únicas dependências necessárias em produção.
Isso deixa a imagem menor.

**Qual a diferença entre `docker compose down` e `down -v`?**
`down` remove containers e redes daquele projeto, mas mantém os volumes nomeados.
`down -v` também remove os volumes — por isso foi evitado no teste de persistência.

---

## 8. Comandos úteis para ter decorados

```bash
docker compose up -d --build   # constrói e sobe tudo
docker compose ps              # status dos serviços
docker images                  # lista imagens
docker ps                      # lista containers
docker network ls              # lista redes
docker network inspect 02-biblioteca_biblioteca-net
docker volume ls               # lista volumes
docker compose logs            # logs dos serviços
docker compose stop            # para sem remover
docker compose start           # inicia novamente
docker compose down            # remove containers e rede (mantém volume)
docker compose up -d           # recria a aplicação
```
