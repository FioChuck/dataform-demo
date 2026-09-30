FROM python:3.12-slim-bookworm

# Prevent Python from writing .pyc files and enable unbuffered logging
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1
ENV DEBIAN_FRONTEND=noninteractive
ENV SHELL=/bin/bash

# GCP Environment Variables
ENV PROJECT_ID="cf-data-analytics"
ENV PYTHONPATH=/app

# User creation configuration
ARG USERNAME=vscode
ARG USER_UID=1000
ARG USER_GID=$USER_UID

# Create non-root user with bash as default shell and grant passwordless sudo access
RUN groupadd --gid $USER_GID $USERNAME \
    && useradd --uid $USER_UID --gid $USER_GID -m -s /bin/bash $USERNAME \
    && apt-get update && apt-get install -y --no-install-recommends sudo \
    && echo $USERNAME ALL=\(root\) NOPASSWD:ALL > /etc/sudoers.d/$USERNAME \
    && chmod 0440 /etc/sudoers.d/$USERNAME \
    && rm -rf /var/lib/apt/lists/*

# Install System Dependencies, Google Cloud SDK (gcloud CLI), and Node.js for Dataform CLI
RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    curl \
    wget \
    procps \
    ca-certificates \
    gnupg \
    && mkdir -p /usr/share/keyrings \
    && curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | gpg --dearmor -o /usr/share/keyrings/cloud.google.gpg \
    && echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | tee -a /etc/apt/sources.list.d/google-cloud-sdk.list \
    && curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get update && apt-get install -y --no-install-recommends \
    google-cloud-cli \
    nodejs \
    && npm install -g @dataform/cli \
    && rm -rf /var/lib/apt/lists/*

# Install Starship Shell Prompt and configure for root and vscode users
RUN curl -sS https://starship.rs/install.sh | sh -s -- --yes \
    && echo 'eval "$(starship init bash)"' >> /root/.bashrc \
    && echo 'eval "$(starship init bash)"' >> /home/vscode/.bashrc

# Install Antigravity CLI (agy)
RUN curl -fsSL https://antigravity.google/cli/install.sh | bash -s -- --dir /usr/local/bin

# Set PYTHONPATH and Dataform CLI aliases in bashrc for interactive shells
RUN echo "export PYTHONPATH=/app:\$PYTHONPATH" >> /etc/bash.bashrc \
    && echo "alias df='dataform'" >> /etc/bash.bashrc \
    && echo "alias dfc='dataform compile'" >> /etc/bash.bashrc \
    && echo "alias dfr='dataform run'" >> /etc/bash.bashrc \
    && echo "alias dfd='dataform run --dry-run'" >> /etc/bash.bashrc \
    && echo "alias dft='dataform test'" >> /etc/bash.bashrc \
    && echo "alias dff='dataform format'" >> /etc/bash.bashrc

WORKDIR /app

# Install Python dependencies if requirements.txt exists
COPY requirements*.txt ./
RUN if [ -f requirements.txt ]; then \
        pip install --no-cache-dir --upgrade pip && \
        pip install --no-cache-dir -r requirements.txt; \
    fi

# Ensure proper permissions for vscode user and copy application code
COPY . .
RUN chown -R $USERNAME:$USERNAME /app

USER $USERNAME

# Default command
CMD ["/bin/bash"]
