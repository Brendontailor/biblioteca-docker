# Imagem base leve com Node.js 20 (LTS)
FROM node:20-alpine

# Diretorio de trabalho dentro do container
WORKDIR /app

# Copia primeiro apenas o package.json para aproveitar o cache de camadas
COPY package.json ./

# Instala somente as dependencias de producao (express, pg e dotenv)
RUN npm install --omit=dev && npm cache clean --force

# Copia o codigo-fonte da aplicacao (frontend, server.js, config, SQL)
COPY . .

# Variaveis de ambiente padrao (podem ser sobrescritas pelo compose)
ENV PORT=3000
ENV NODE_ENV=production

# Porta em que a API escuta dentro do container
EXPOSE 3000

# Comando de inicializacao definido no package.json: node server.js
CMD ["npm", "start"]
