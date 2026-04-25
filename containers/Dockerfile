FROM postgres:16.13

# Avoid interactive prompts
ENV DEBIAN_FRONTEND=noninteractive

# Step 0: Install required system packages
RUN apt-get update && apt-get install -y --no-install-recommends \
    postgresql-16-postgis-3 \
    postgresql-16-pgrouting \
    osm2pgsql \
    osm2pgrouting \
    gdal-bin \
    python3-pip \
    python3-venv \
    python3-dev \
    libpq-dev \
    ca-certificates \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Install uv for Python package management
COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /bin/

# Install specific Python version
RUN uv python install 3.14.3

# Set up virtual environment
RUN uv venv /opt/venv --python 3.14.3
ENV PATH="/opt/venv/bin:$PATH"

# Set up work directory
WORKDIR /work

# Copy and install requirements
COPY containers/requirements.txt /work/requirements.txt
RUN uv pip install --no-cache -r /work/requirements.txt

# Environment variables matching author defaults
ENV POSTGRES_PASSWORD=admin
ENV POSTGRES_DB=OSM
