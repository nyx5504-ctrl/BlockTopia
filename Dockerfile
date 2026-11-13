FROM node:22-alpine
WORKDIR /app
COPY Backend/package.json ./
RUN npm install --omit=dev
COPY Backend/ ./
ENV NODE_ENV=production
EXPOSE 8787
CMD ["node","servers/index.js"]
