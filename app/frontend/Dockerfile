FROM node:20-alpine

WORKDIR /app

COPY package.json ./

RUN npm install --production

COPY app.js ./
COPY public/ ./public/

EXPOSE 8080

CMD ["node", "app.js"]
