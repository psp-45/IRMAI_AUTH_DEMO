# --- Build Stage ---
# Use an official Node.js runtime as a parent image
FROM node:18-alpine AS builder

# Set the working directory in the container
WORKDIR /usr/src/app

# Copy package.json and package-lock.json (or yarn.lock)
# Using package*.json ensures both files are copied if they exist
COPY package*.json ./

# Install all dependencies (including devDependencies needed for build)
RUN npm install

# Copy the rest of the application code
COPY . .

# If you have a build step (e.g., TypeScript compilation), add it here
# Make sure your build output goes to a known directory (e.g., 'dist')
RUN npm run build 

# --- Production Stage ---
FROM node:18-alpine AS production

# Set NODE_ENV environment variable
ENV NODE_ENV=production

# Set the working directory
WORKDIR /usr/src/app

# Copy package.json and package-lock.json for production dependencies
COPY package*.json ./

# Install *only* production dependencies using npm ci for reliability
RUN npm ci --omit=dev

# Copy application code and build artifacts (if any) from the builder stage
COPY --from=builder /usr/src/app .

# FIX: Set correct ownership for the non-root user
RUN chown -R node:node /usr/src/app
 
# Optional but safer: prevent others from writing
RUN chmod -R 755 /usr/src/app

# Expose the port the app runs on
EXPOSE 8080

# Create and switch to a non-root user for security
USER node

# Define the command to run the application
CMD [ "npm", "run", "preview" ]
