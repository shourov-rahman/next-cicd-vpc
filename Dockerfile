# Stage 1: Base image with necessary tools and dependencies
FROM node:20-alpine as base

RUN apk add --no-cache libc6-compat

WORKDIR /app
COPY package*.json ./
EXPOSE 3000


# Stage 2: Build stage
FROM base as builder
WORKDIR /app
COPY . .

# Disable telemetry during the build.
ENV NEXT_TELEMETRY_DISABLED 1

# Install next globally
RUN npm install -g next

RUN npm run build


# Stage 3: Production image
FROM base as production
WORKDIR /app

# Set environment variables
ENV NODE_ENV=production

# Disable telemetry during the production
ENV NEXT_TELEMETRY_DISABLED 1

# Install production dependencies
RUN npm ci

# Create a non-root user
RUN addgroup -g 1001 -S nodejs
RUN adduser -S nextjs -u 1001
USER nextjs

# Copy necessary files from the builder stage
COPY --from=builder --chown=nextjs:nodejs /app/.next ./.next
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/package.json ./package.json
COPY --from=builder /app/public ./public

# Set the command to start the application
CMD npm start

# Stage 4: Development image
FROM base as dev
ENV NODE_ENV=development

# Install development dependencies
RUN npm install 

# Copy the entire project to the container
COPY . .

# Set the command to run the application in development mode
CMD npm run dev

# Stage-5: Server With Nginx
FROM nginx:1.23-alpine
WORKDIR /usr/share/nginx/html
RUN rm -rf *
COPY --from=builder /app/.next .
EXPOSE 80
ENTRYPOINT [ "nginx", "-g", "daemon off;" ]