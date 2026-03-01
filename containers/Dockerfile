FROM postgis/postgis:16-3.4

# Avoid interactive prompts
ENV DEBIAN_FRONTEND=noninteractive

# Step 0: Install required system packages
RUN apt-get update && apt-get install -y --no-install-recommends \
    postgresql-16-pgrouting \
    osm2pgsql \
    osm2pgrouting \
    postgresql-contrib \
    postgis \
    python3-pip \
    python3-venv \
    python3-dev \
    libpq-dev \
    gdal-bin \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Install uv for Python package management
COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /bin/

# Set up work directory
WORKDIR /work

# Pre-install core requirements for Graz pipeline
# Note: We install them globally in the container using uv
RUN uv pip install --system --no-cache \
    sqlalchemy \
    psycopg2-binary \
    matplotlib \
    pandas \
    geopandas \
    numpy \
    seaborn \
    shapely \
    scipy \
    wordcloud \
    earthpy \
    rasterio \
    contextily \
    mapclassify \
    rtree \
    pyogrio \
    geoalchemy2 \
    "setuptools<70.0.0" \
    jupyter \
    nbconvert

# Environment variables matching author defaults
ENV POSTGRES_PASSWORD=admin
ENV POSTGRES_DB=OSM
