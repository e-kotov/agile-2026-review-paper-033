FROM ghcr.io/osgeo/gdal:ubuntu-small-3.11.5

# Avoid interactive prompts
ENV DEBIAN_FRONTEND=noninteractive

# Step 0: Install basic dependencies for adding repos
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    gnupg2 \
    lsb-release \
    && rm -rf /var/lib/apt/lists/*

# Step 1: Add PostgreSQL APT repository
RUN curl -fsSL https://www.postgresql.org/media/keys/ACCC4CF8.asc | gpg --dearmor -o /etc/apt/trusted.gpg.d/postgresql.gpg \
    && echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list

# Step 2: Install required system packages
# PostgreSQL 16.x (guaranteed 16.13+ via pgdg), PostGIS, pgRouting, osm2pgsql, osm2pgrouting
RUN apt-get update && apt-get install -y --no-install-recommends \
    postgresql-16 \
    postgresql-16-postgis-3 \
    postgresql-16-pgrouting \
    postgis \
    osm2pgsql \
    osm2pgrouting \
    python3-pip \
    python3-venv \
    python3-dev \
    libpq-dev \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Add Postgres binaries to PATH
ENV PATH="/usr/lib/postgresql/16/bin:$PATH"

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

# The official Postgres image uses the 'postgres' user. 
# Ubuntu's apt-get install postgresql-16 creates this user.
# We ensure the data directory is accessible (if not using the default)
# and run as postgres where possible, though entrypoint.sh may need root for setup.
