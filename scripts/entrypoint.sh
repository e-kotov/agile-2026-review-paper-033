#!/bin/bash
set -e

# entrypoint.sh: Initializes and starts PostgreSQL in-session for reproduction runs.
# This works in both Docker and Apptainer/Singularity.

export PGDATA="${PGDATA:-/work/pgdata}"
export PGDATABASE="${PGDATABASE:-OSM}"
export PGUSER="${PGUSER:-postgres}"
export PGPASSWORD="${PGPASSWORD:-admin}"
export PGPORT="${PGPORT:-5432}"

# Initialize database if needed
if [ ! -d "$PGDATA/base" ]; then
    echo "Initializing new database cluster in $PGDATA..."
    initdb -D "$PGDATA" --username="$PGUSER" --pwfile=<(echo "$PGPASSWORD") --auth=scram-sha-256
    
    # Configure Postgres to allow local connections without password for ease of reproduction
    echo "host all all 127.0.0.1/32 trust" >> "$PGDATA/pg_hba.conf"
    echo "local all all trust" >> "$PGDATA/pg_hba.conf"
    echo "listen_addresses = '127.0.0.1'" >> "$PGDATA/postgresql.conf"
    echo "port = $PGPORT" >> "$PGDATA/postgresql.conf"
    echo "unix_socket_directories = '/tmp'" >> "$PGDATA/postgresql.conf"
fi

# Start Postgres in the background
echo "Starting PostgreSQL on port $PGPORT..."
pg_ctl -D "$PGDATA" -l "$PGDATA/logfile" start

# Wait for Postgres to be ready
until pg_isready -h localhost -p "$PGPORT"; do
  echo "Waiting for database to start..."
  sleep 2
done

# Create target database if it doesn't exist
if ! psql -h localhost -p "$PGPORT" -U "$PGUSER" -lqt | cut -d \| -f 1 | grep -qw "$PGDATABASE"; then
    echo "Creating database $PGDATABASE..."
    createdb -h localhost -p "$PGPORT" -U "$PGUSER" "$PGDATABASE"
fi

# If arguments are provided, execute them (e.g., run-setup.sh), then shutdown
if [ "$#" -gt 0 ]; then
    echo "Executing command: $@"
    "$@"
    exit_code=$?
    
    echo "Stopping PostgreSQL..."
    pg_ctl -D "$PGDATA" stop
    exit $exit_code
fi

# If no arguments, keep the database running (useful for interactive debug)
echo "PostgreSQL is running. Press Ctrl+C to stop."
trap 'pg_ctl -D "$PGDATA" stop; exit 0' SIGINT SIGTERM
tail -f "$PGDATA/logfile"
