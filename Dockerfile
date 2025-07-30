FROM node:18-alpine

# Install system dependencies
RUN apk add --no-cache \
    git \
    curl \
    bash \
    vim \
    nano \
    openssh-client \
    python3 \
    py3-pip \
    build-base \
    ca-certificates \
    jq

# Set working directory to existing node user's home
WORKDIR /home/node

# Install Claude Code
RUN npm install -g @anthropic-ai/claude-code

# Install additional development tools
RUN npm install -g \
    typescript \
    ts-node \
    nodemon \
    prettier \
    eslint

# Install gemini-cli
RUN npm install -g @google/gemini-cli

# Create necessary directories for node user
RUN mkdir -p /home/node/.claude \
             /home/node/.config \
             /home/node/.ssh \
             /home/node/logs

# Copy claude-loop script
COPY claude-loop.sh /usr/local/bin/claude-loop
RUN chmod +x /usr/local/bin/claude-loop

# Set ownership of node user directories
RUN chown -R node:node /home/node

# Switch to node user
USER node

RUN curl -fsSL https://bun.sh/install | bash

# Set environment variables for Claude Code
ENV TERM=xterm-256color
ENV COLORTERM=truecolor
ENV NODE_ENV=development
ENV PATH="/home/node/.bun/bin:$PATH"

# Default command
CMD ["claude"]
