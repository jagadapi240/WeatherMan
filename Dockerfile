# Step 1: Build stage with Node 16 (works with old react-scripts/webpack)
FROM node:16-alpine AS build

WORKDIR /app

COPY package*.json ./
RUN npm install

COPY . .

# Build the production bundle (creates build/ folder)
RUN npm run build

# Step 2: Run stage (Nginx)
FROM nginx:alpine

COPY --from=build /app/build/ /usr/share/nginx/html/

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
