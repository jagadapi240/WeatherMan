# Step 1: Build stage (Node) - optional but good practice
FROM node:18-alpine AS build

# Create app directory
WORKDIR /app

# Copy package files and install dependencies
COPY package*.json ./
RUN npm install

# Copy the rest of the app code
COPY . .

# Build the production bundle (creates build/ folder)
RUN npm run build

# Step 2: Run stage (Nginx)
FROM nginx:alpine

# Copy built static files from build stage to Nginx html directory
COPY --from=build /app/build/ /usr/share/nginx/html/

# Expose port 80 from the container
EXPOSE 80

# Nginx default command
CMD ["nginx", "-g", "daemon off;"]
