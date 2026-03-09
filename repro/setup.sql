-- =====================================================================
-- 1. EXTENSIONS & SCHEMAS
-- =====================================================================
CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS hstore;
CREATE EXTENSION IF NOT EXISTS pgrouting;
CREATE EXTENSION IF NOT EXISTS postgis_raster;

CREATE SCHEMA IF NOT EXISTS heightdata;
CREATE SCHEMA IF NOT EXISTS sidewalk;
CREATE SCHEMA IF NOT EXISTS nodes;
CREATE SCHEMA IF NOT EXISTS viz;

-- =====================================================================
-- 2. PREPARE RAW DATA
-- =====================================================================
-- Prepare OSM raw tables for consistent tag access and later joins.
-- Convert tag arrays to hstore so key/value lookups are uniform in SQL.


ALTER TABLE planet_osm_ways ADD COLUMN tags_h hstore;
UPDATE planet_osm_ways SET tags_h = hstore(tags);

ALTER TABLE planet_osm_point ADD COLUMN tags_h hstore;
UPDATE planet_osm_point SET tags_h = hstore(tags);

ALTER TABLE planet_osm_rels ADD COLUMN tags_h hstore;
UPDATE planet_osm_rels SET tags_h = hstore(tags);

-- Join OSM ways with routing topology
DROP TABLE IF EXISTS streets;
SELECT * INTO streets
FROM planet_osm_ways
LEFT JOIN ways ON planet_osm_ways.id = ways.osm_id;

-- Clip streets to the Graz border
DROP TABLE IF EXISTS streets_graz;
CREATE TABLE streets_graz AS
SELECT DISTINCT s.*
FROM streets AS s
LEFT JOIN graz_border ON ST_Intersects(s.the_geom, graz_border.geom)
WHERE ST_Within(s.the_geom, graz_border.geom);

-- Parse width and incline from tags into numeric columns
ALTER TABLE streets_graz ADD COLUMN width_float double precision;
ALTER TABLE streets_graz ADD COLUMN incline_float double precision;

UPDATE streets_graz
SET width_float = TRIM(REGEXP_REPLACE(tags_h -> 'width', '[[:alpha:]\s ]', '', 'g'))::numeric;

UPDATE streets_graz
SET incline_float = ABS(REGEXP_REPLACE(tags_h -> 'incline', '[%°]', '', 'g')::numeric)
WHERE tags_h -> 'incline' NOT IN ('up', 'down');

-- =====================================================================
-- 3. ELEVATION PROCESSING
-- =====================================================================
-- Vectorize DEM raster into elevation polygons (computationally intensive)
DROP TABLE IF EXISTS heightdata.graz_dem_vector_square;
CREATE TABLE heightdata.graz_dem_vector_square AS
SELECT (ST_DumpAsPolygons(b.rast)).val elevation,
       (ST_DumpAsPolygons(b.rast)).geom geom
FROM heightdata.graz_dem b;

ALTER TABLE heightdata.graz_dem_vector_square ADD COLUMN id SERIAL PRIMARY KEY;
CREATE INDEX graz_dem_vector_square_gix ON heightdata.graz_dem_vector_square USING GIST (geom);

-- Break streets into individual line segments for elevation sampling
DROP TABLE IF EXISTS heightdata.streets_graz_dumpsegments;
CREATE TABLE heightdata.streets_graz_dumpsegments AS
SELECT (ST_DumpSegments(the_geom)).geom geom, streets_graz.*
FROM streets_graz;

ALTER TABLE heightdata.streets_graz_dumpsegments ADD COLUMN geom_32633 geometry;
UPDATE heightdata.streets_graz_dumpsegments SET geom_32633 = ST_Transform(geom, 32633);
CREATE INDEX graz_street_32633_index ON heightdata.streets_graz_dumpsegments USING GIST (geom_32633);

-- Sample elevation at start/end of each segment via correlated subqueries
DROP TABLE IF EXISTS heightdata.streets_clipped_dumpsegments_new;
CREATE TABLE heightdata.streets_clipped_dumpsegments_new AS
SELECT DISTINCT s.*,
    (SELECT belevv.elevation FROM heightdata.graz_dem_vector_square belevv
     WHERE ST_Intersects(st_startpoint(s.geom_32633), belevv.geom)) AS elv_start,
    (SELECT belevv.elevation FROM heightdata.graz_dem_vector_square belevv
     WHERE ST_Intersects(st_endpoint(s.geom_32633), belevv.geom))   AS elv_end
FROM heightdata.streets_graz_dumpsegments s, heightdata.graz_dem_vector_square belevv
WHERE (ST_Intersects(st_startpoint(s.geom_32633), belevv.geom)
    OR ST_Intersects(st_endpoint(s.geom_32633), belevv.geom));

-- Compute slope as percentage from elevation difference
ALTER TABLE heightdata.streets_clipped_dumpsegments_new ADD COLUMN slope_length double precision;
UPDATE heightdata.streets_clipped_dumpsegments_new s
SET slope_length = ABS(s.elv_end - s.elv_start) / st_length(s.geom_32633) * 100;

CREATE INDEX streets_clipped_dumpsegments_new_index
    ON heightdata.streets_clipped_dumpsegments_new USING GIST (geom_32633);

-- Aggregate slope per street: average and maximum
DROP TABLE IF EXISTS heightdata.graz_elvation_avg_slope;
CREATE TABLE heightdata.graz_elvation_avg_slope AS
SELECT s.gid, AVG(s.slope_length) AS slope FROM heightdata.streets_clipped_dumpsegments_new s GROUP BY s.gid;

DROP TABLE IF EXISTS heightdata.graz_elvation_max_slope;
CREATE TABLE heightdata.graz_elvation_max_slope AS
SELECT s.gid, MAX(s.slope_length) AS slope FROM heightdata.streets_clipped_dumpsegments_new s GROUP BY s.gid;

-- =====================================================================
-- 4. VERTEX ELEVATION
-- =====================================================================
-- Enrich routing vertices with DEM elevation for node-level queries
ALTER TABLE ways_vertices_pgr ADD COLUMN geom_32633 geometry;
UPDATE ways_vertices_pgr SET geom_32633 = ST_Transform(the_geom, 32633);
CREATE INDEX ways_vertices_pgr_geom_32633_index ON ways_vertices_pgr USING GIST (geom_32633);

DROP TABLE IF EXISTS ways_vertices_pgr_elevation;
CREATE TABLE ways_vertices_pgr_elevation AS
SELECT DISTINCT ON (ways_vertices_pgr.id) ways_vertices_pgr.*, belevv.elevation AS elevation
FROM ways_vertices_pgr, heightdata.graz_dem_vector_square belevv
WHERE ST_Intersects(geom_32633, belevv.geom);

-- =====================================================================
-- 5. BASE ROUTING GRAPH
-- =====================================================================
-- Join streets with max slope
DROP TABLE IF EXISTS graz_pgr;
CREATE TABLE graz_pgr AS
SELECT s.*, s_e.slope
FROM heightdata.graz_elvation_max_slope s_e
LEFT JOIN streets_graz s ON s.gid = s_e.gid;

-- Join streets with average slope
DROP TABLE IF EXISTS graz_pgr_avg_slope;
CREATE TABLE graz_pgr_avg_slope AS
SELECT s.*, s_e.slope
FROM heightdata.graz_elvation_avg_slope s_e
LEFT JOIN streets_graz s ON s.gid = s_e.gid;

-- Add projected geometry for spatial proximity queries
ALTER TABLE graz_pgr ADD COLUMN geom_3857 geometry;
UPDATE graz_pgr SET geom_3857 = ST_Transform(the_geom, 3857);
CREATE INDEX graz_pgr_index ON graz_pgr USING GIST (geom_3857);

-- Placeholder columns for kerb data (filled in step 6)
ALTER TABLE graz_pgr
    ADD COLUMN node_tag    hstore,
    ADD COLUMN node_osm_id BIGINT,
    ADD COLUMN node_geom   geometry,
    ADD COLUMN distance    double precision;

-- =====================================================================
-- 6. NODES & KERB INTEGRATION
-- =====================================================================
-- Extract all OSM nodes within Graz border
DROP TABLE IF EXISTS nodes.all_nodes_graz;
CREATE TABLE nodes.all_nodes_graz AS
SELECT DISTINCT s.osm_id, ST_Transform(way, 4326) AS the_geom, s.tags_h
FROM planet_osm_point s, graz_border g
WHERE ST_Within(ST_Transform(way, 4326), g.geom);

-- Extract kerb nodes
DROP TABLE IF EXISTS nodes.kerb_all;
CREATE TABLE nodes.kerb_all AS
SELECT * FROM nodes.all_nodes_graz WHERE tags_h -> 'kerb' IS NOT NULL;

ALTER TABLE nodes.kerb_all ADD COLUMN geom_3857 geometry;
UPDATE nodes.kerb_all SET geom_3857 = ST_Transform(the_geom, 3857);
CREATE INDEX nodes_kerb_all_geom_3857_index ON nodes.kerb_all USING GIST (geom_3857);

-- Spatial join: nearest kerb node within 1m of each street edge
DROP TABLE IF EXISTS graz_pgrXkerbnodes1m_liii;
CREATE TABLE graz_pgrXkerbnodes1m_liii AS
SELECT DISTINCT ON (line.gid) line.id AS line_osm_id,
                              line.the_geom AS line_thegeom,
                              line.gid AS line_gid,
                              node.osm_id AS node_osm_id,
                              node.geom_3857 <-> line.geom_3857 AS distance,
                              node.tags_h AS node_tag
FROM nodes.kerb_all AS node, graz_pgr line
WHERE ST_DWithin(node.geom_3857, line.geom_3857, 1)
ORDER BY line.gid, node.geom_3857 <-> line.geom_3857;

ALTER TABLE graz_pgrXkerbnodes1m_liii ADD PRIMARY KEY (line_gid);
ALTER TABLE graz_pgr ADD PRIMARY KEY (gid);
ALTER TABLE graz_pgrXkerbnodes1m_liii ADD FOREIGN KEY (line_gid) REFERENCES graz_pgr (gid);

-- Propagate kerb info to the main graph
UPDATE graz_pgr AS maintable
SET node_tag = o.node_tag
FROM graz_pgrXkerbnodes1m_liii o
WHERE maintable.gid = o.line_gid;

-- =====================================================================
-- 7. SIDEWALK TABLES
-- =====================================================================
-- Streets tagged with sidewalk=*
DROP TABLE IF EXISTS sidewalk.graz_sidewalk;
CREATE TABLE sidewalk.graz_sidewalk AS
SELECT * FROM graz_pgr
WHERE tags_h ? 'sidewalk' AND tags_h -> 'sidewalk' NOT IN ('no');

-- Streets tagged as footways
DROP TABLE IF EXISTS sidewalk.graz_footway;
CREATE TABLE sidewalk.graz_footway AS
SELECT * FROM graz_pgr
WHERE tags_h -> 'highway' IN ('footway')
   OR tags_h -> 'footway' NOT IN ('no')
   OR tags_h -> 'foot' IN ('yes', 'designated', 'use_sidepath', 'permissive');

-- Pedestrian-accessible highway types
DROP TABLE IF EXISTS sidewalk.my_network;
CREATE TABLE sidewalk.my_network AS
SELECT * FROM graz_pgr
WHERE tags_h -> 'highway' IN ('living_street', 'pedestrian', 'residential', 'service', 'track', 'footway', 'cycleway', 'bridleway')
   OR tags_h -> 'footway' NOT IN ('no')
   AND tags_h -> 'footway' IS NOT NULL;

-- highway=footway + footway=sidewalk|crossing|etc.
DROP TABLE IF EXISTS sidewalk.highway_footwayxfootway_sidewalk;
CREATE TABLE sidewalk.highway_footwayxfootway_sidewalk AS
SELECT * FROM graz_pgr
WHERE tags_h -> 'highway' IN ('footway')
  AND tags_h -> 'footway' IN ('sidewalk', 'crossing', 'traffic_island', 'link', 'island', 'yes', 'path');

-- Deduplicated sidewalk layer (union of both tagging schemes, no spatial overlap)
DROP TABLE IF EXISTS sidewalk_unique;
CREATE TABLE sidewalk_unique AS
SELECT * FROM sidewalk.highway_footwayxfootway_sidewalk
UNION
SELECT aa.* FROM sidewalk.graz_sidewalk AS aa
WHERE aa.gid NOT IN (SELECT aa.gid
                     FROM sidewalk.highway_footwayxfootway_sidewalk AS bb
                     WHERE st_dwithin(st_transform(aa.the_geom, 3857), st_transform(bb.the_geom, 3857), 15)
                        OR ST_Intersects(st_transform(aa.the_geom, 3857), st_transform(bb.the_geom, 3857)));

-- =====================================================================
-- 8. ROUTING NETWORKS
-- =====================================================================
-- Wheelchair-accessible network: strict filtering on surface, width, slope, kerbs
DROP TABLE IF EXISTS wheelchair_network;
CREATE TABLE wheelchair_network AS
SELECT *
FROM graz_pgr
WHERE (tags_h -> 'highway' IN
       ('footway', 'service', 'residential', 'path', 'cycleway', 'pedestrian', 'tertiary', 'unclassified',
        'living_street', 'secondary_link', 'tertiary_link') OR tags_h -> 'highway' IS NULL)
  AND (tags_h -> 'footway' IN ('sidewalk', 'crossing', 'traffic_island', 'link', 'island', 'yes', 'path', 'ramp') OR
       tags_h -> 'footway' IS NULL)
  AND (tags_h -> 'surface' IN
       ('asphalt', 'paved', 'paving_stones', 'ground', 'concrete', 'sett', 'cobblestone', 'cobblestone:flattened',
        'metal', 'asphalt;paving_stones', 'asphalt;cobblestone', 'concrete:plates', 'asphalt;concrete',
        'concrete:lanes', 'carpet', 'marble', 'metal_grid', 'grav', 'unhewn_cobblestone', 'pebblestone:lanes',
        'stainzerplatten') OR tags_h -> 'surface' IS NULL)
  AND (tags_h -> 'smoothness' IN ('excellent', 'good', 'intermediate') OR tags_h -> 'smoothness' IS NULL)
  AND (tags_h -> 'sidewalk' IN ('both', 'separate', 'right', 'left', 'explicit', 'yes', 'seperate;marked') OR
       tags_h -> 'sidewalk' IS NULL)
  AND (tags_h -> 'sidewalk:left' IN ('separate', 'yes') OR tags_h -> 'sidewalk:right' IS NULL)
  AND (tags_h -> 'sidewalk:right' IN ('separate', 'yes') OR tags_h -> 'sidewalk:right' IS NULL)
  AND (REGEXP_REPLACE(tags_h -> 'sidewalk:width', '[[:alpha:]\s ]', '', 'g')::numeric > 1.5 OR
       tags_h -> 'sidewalk:right:width' IS NULL)
  AND (tags_h -> 'sidewalk:surface' IN ('both', 'separate', 'right', 'left', 'explicit', 'yes', 'seperate;marked') OR
       tags_h -> 'sidewalk:right:surface' IS NULL)
  AND (tags_h -> 'sidewalk:smoothness' IN ('both', 'separate', 'right', 'left', 'explicit', 'yes', 'seperate;marked') OR
       tags_h -> 'sidewalk:right:smoothness' IS NULL)
  AND (REGEXP_REPLACE(tags_h -> 'sidewalk:incline', '[[:alpha:]\s ]', '', 'g')::numeric < 10 OR
       tags_h -> 'sidewalk:right:incline' IS NULL)
  AND (tags_h -> 'access' IN ('yes', 'permissive', 'destination', 'designated', 'service', 'discouraged') OR
       tags_h -> 'access' IS NULL)
  AND (tags_h -> 'wheelchair' IN ('yes', 'limited', 'designated') OR tags_h -> 'wheelchair' IS NULL)
  AND (tags_h -> 'foot' IN ('yes', 'designated', 'permissive', 'official', 'residents') OR tags_h -> 'foot' IS NULL)
  AND (incline_float < 6 OR incline_float IS NULL)
  AND (tags_h -> 'barrier' NOT IN ('fence', 'wall', 'railing', 'log', 'kerb', 'handrail') OR
       tags_h -> 'barrier' IS NULL)
  AND (node_tag -> 'kerb' IN ('flush', 'lowered', 'no') OR node_tag -> 'kerb' IS NULL)
  AND (width_float > 1.5 OR width_float IS NULL)
  AND (slope < 10 OR slope IS NULL);

-- Pedestrian network: looser filtering (no surface/slope/kerb constraints)
DROP TABLE IF EXISTS pedestrian_network;
CREATE TABLE pedestrian_network AS
SELECT *
FROM graz_pgr
WHERE (tags_h -> 'highway' IN
       ('footway', 'service', 'residential', 'path', 'cycleway', 'pedestrian', 'tertiary', 'unclassified',
        'living_street', 'secondary_link', 'tertiary_link') OR tags_h -> 'highway' IS NULL)
    AND (tags_h -> 'footway' IN ('sidewalk', 'crossing', 'traffic_island', 'link', 'island', 'yes', 'path', 'ramp') OR
         tags_h -> 'footway' IS NULL)
    AND (tags_h -> 'sidewalk' IN ('both', 'separate', 'right', 'left', 'explicit', 'yes', 'seperate;marked') OR
         tags_h -> 'sidewalk' IS NULL)
    AND (tags_h -> 'sidewalk:left' IN ('separate', 'yes') OR tags_h -> 'sidewalk:right' IS NULL)
    AND (tags_h -> 'sidewalk:right' IN ('separate', 'yes') OR tags_h -> 'sidewalk:right' IS NULL)
    AND (tags_h -> 'access' IN ('yes', 'permissive', 'destination', 'designated', 'service', 'discouraged') OR
         tags_h -> 'access' IS NULL)
    AND (tags_h -> 'foot' IN ('yes', 'designated', 'permissive', 'official', 'residents') OR tags_h -> 'foot' IS NULL)
    OR (tags_h -> 'sidewalk' IN ('no') AND tags_h -> 'foot' IN ('yes') OR tags_h -> 'sidewalk' IS NULL OR
       tags_h -> 'foot' IS NULL);

-- =====================================================================
-- 9. VISUALIZATION
-- =====================================================================
-- Clip hex grid to Graz border
DROP TABLE IF EXISTS viz.graz_hex;
CREATE TABLE viz.graz_hex AS
SELECT hex500.*
FROM hex500, graz_border
WHERE ST_Within(hex500.geom, graz_border.geom);

-- Count steps per hex cell
DROP TABLE IF EXISTS viz.hex_steps;
CREATE TABLE viz.hex_steps AS
SELECT COUNT(p) AS count_steps, g.geom AS the_geom
FROM viz.graz_hex g
LEFT OUTER JOIN (SELECT * FROM graz_pgr WHERE tags_h -> 'highway' IN ('steps')) AS p
    ON ST_Intersects(g.geom, p.the_geom)
GROUP BY g.geom, g.id
ORDER BY count_steps DESC;

-- Count kerbs per hex cell
DROP TABLE IF EXISTS viz.hex_kurbs;
CREATE TABLE viz.hex_kurbs AS
SELECT COUNT(p) AS count_kerbs, g.geom AS the_geom
FROM viz.graz_hex g
LEFT OUTER JOIN (SELECT * FROM nodes.all_nodes_graz WHERE tags_h -> 'kerb' IS NOT NULL) AS p
    ON ST_Intersects(g.geom, p.the_geom)
GROUP BY g.geom, g.id
ORDER BY count_kerbs DESC;

-- Full street network union
DROP TABLE IF EXISTS viz.graz_pgr_union;
CREATE TABLE viz.graz_pgr_union AS
SELECT st_union(the_geom) AS the_geom FROM graz_pgr;

-- Street network union clipped to inner districts
-- [REPRO PATCH] DROP TABLE IF EXISTS viz.graz_pgr_union_inner;
-- [REPRO PATCH] CREATE TABLE viz.graz_pgr_union_inner AS
-- [REPRO PATCH] SELECT st_union(the_geom) AS the_geom
-- [REPRO PATCH] FROM graz_pgr, innerenbezirke
-- [REPRO PATCH] WHERE st_within(graz_pgr.the_geom, innerenbezirke.geom);

-- =====================================================================
-- [REPRO PATCH] Restored graz_sidewalk_unique for Notebook 01
DROP TABLE IF EXISTS graz_sidewalk_unique;
CREATE TABLE graz_sidewalk_unique AS
WITH highway_footwayxfootway_sidewalk AS (
     SELECT *
     FROM graz_pgr
     WHERE tags_h -> 'highway' IN ('footway')
       AND tags_h -> 'footway' IN ('sidewalk')
),
sidewalk AS (
     SELECT *
     FROM graz_pgr
     WHERE tags_h ? 'sidewalk'
       AND tags_h -> 'sidewalk' NOT IN ('no')
)
SELECT * FROM highway_footwayxfootway_sidewalk
UNION
SELECT * FROM sidewalk AS aa
WHERE aa.gid NOT IN (
     SELECT aa.gid
     FROM highway_footwayxfootway_sidewalk AS bb
     WHERE st_dwithin(st_transform(aa.the_geom, 3857), st_transform(bb.the_geom, 3857), 15)
        OR ST_Intersects(st_transform(aa.the_geom, 3857), st_transform(bb.the_geom, 3857))
);


-- [REPRO PATCH] Skipping section due to missing Linz/Salzburg data
-- -- 10. COMPARISON (GRAZ / LINZ / SALZBURG)
-- -- =====================================================================
-- -- Preconditions: *_ways, *_pgr_ways, and *_border tables exist for all cities.
-- CREATE SCHEMA IF NOT EXISTS compare;
-- 
-- -- Add hstore tags to each city ways table.
-- ALTER TABLE graz_ways ADD COLUMN tags_h hstore;
-- ALTER TABLE linz_ways ADD COLUMN tags_h hstore;
-- ALTER TABLE salzburg_ways ADD COLUMN tags_h hstore;
-- 
-- UPDATE graz_ways SET tags_h = hstore(tags);
-- UPDATE linz_ways SET tags_h = hstore(tags);
-- UPDATE salzburg_ways SET tags_h = hstore(tags);
-- 
-- -- Join OSM ways with routing topology per city.
-- DROP TABLE IF EXISTS compare.streets_graz;
-- CREATE TABLE compare.streets_graz AS
-- SELECT *
-- FROM graz_ways
-- LEFT JOIN graz_pgr_ways ON graz_ways.id = graz_pgr_ways.osm_id;
-- 
-- DROP TABLE IF EXISTS compare.streets_linz;
-- CREATE TABLE compare.streets_linz AS
-- SELECT *
-- FROM linz_ways
-- LEFT JOIN linz_pgr_ways ON linz_ways.id = linz_pgr_ways.osm_id;
-- 
-- DROP TABLE IF EXISTS compare.streets_salzburg;
-- CREATE TABLE compare.streets_salzburg AS
-- SELECT *
-- FROM salzburg_ways
-- LEFT JOIN salzburg_pgr_ways ON salzburg_ways.id = salzburg_pgr_ways.osm_id;
-- 
-- -- Clip streets to city borders.
-- DROP TABLE IF EXISTS compare.graz_pgr;
-- CREATE TABLE compare.graz_pgr AS
-- SELECT DISTINCT s.*
-- FROM compare.streets_graz AS s
-- LEFT JOIN graz_border ON ST_Intersects(s.the_geom, graz_border.geom)
-- WHERE ST_Within(s.the_geom, graz_border.geom);
-- 
-- DROP TABLE IF EXISTS compare.linz_pgr;
-- CREATE TABLE compare.linz_pgr AS
-- SELECT DISTINCT s.*
-- FROM compare.streets_linz AS s
-- LEFT JOIN linz_border ON ST_Intersects(s.the_geom, linz_border.geom)
-- WHERE ST_Within(s.the_geom, linz_border.geom);
-- 
-- DROP TABLE IF EXISTS compare.salzburg_pgr;
-- CREATE TABLE compare.salzburg_pgr AS
-- SELECT DISTINCT s.*
-- FROM compare.streets_salzburg AS s
-- LEFT JOIN salzburg_border ON ST_Intersects(s.the_geom, salzburg_border.geom)
-- WHERE ST_Within(s.the_geom, salzburg_border.geom);
-- 
-- -- Sidewalk-unique layers per city.
-- DROP TABLE IF EXISTS compare.graz_sidewalk_unique;
-- CREATE TABLE compare.graz_sidewalk_unique AS
-- WITH highway_footwayxfootway_sidewalk AS (
--      SELECT *
--      FROM graz_pgr
--      WHERE tags_h -> 'highway' IN ('footway')
--        AND tags_h -> 'footway' IN ('sidewalk')
-- ),
-- sidewalk AS (
--      SELECT *
--      FROM graz_pgr
--      WHERE tags_h ? 'sidewalk'
--        AND tags_h -> 'sidewalk' NOT IN ('no')
-- )
-- SELECT * FROM highway_footwayxfootway_sidewalk
-- UNION
-- SELECT * FROM sidewalk AS aa
-- WHERE aa.gid NOT IN (
--      SELECT aa.gid
--      FROM highway_footwayxfootway_sidewalk AS bb
--      WHERE st_dwithin(st_transform(aa.the_geom, 3857), st_transform(bb.the_geom, 3857), 15)
--         OR ST_Intersects(st_transform(aa.the_geom, 3857), st_transform(bb.the_geom, 3857))
-- );
-- 
-- DROP TABLE IF EXISTS compare.linz_sidewalk_unique;
-- CREATE TABLE compare.linz_sidewalk_unique AS
-- WITH highway_footwayxfootway_sidewalk AS (
--      SELECT *
--      FROM compare.linz_pgr
--      WHERE tags_h -> 'highway' IN ('footway')
--        AND tags_h -> 'footway' IN ('sidewalk')
-- ),
-- sidewalk AS (
--      SELECT *
--      FROM compare.linz_pgr
--      WHERE tags_h ? 'sidewalk'
--        AND tags_h -> 'sidewalk' NOT IN ('no')
-- )
-- SELECT * FROM highway_footwayxfootway_sidewalk
-- UNION
-- SELECT * FROM sidewalk AS aa
-- WHERE aa.gid NOT IN (
--      SELECT aa.gid
--      FROM highway_footwayxfootway_sidewalk AS bb
--      WHERE st_dwithin(st_transform(aa.the_geom, 3857), st_transform(bb.the_geom, 3857), 15)
--         OR ST_Intersects(st_transform(aa.the_geom, 3857), st_transform(bb.the_geom, 3857))
-- );
-- 
-- DROP TABLE IF EXISTS compare.salzburg_sidewalk_unique;
-- CREATE TABLE compare.salzburg_sidewalk_unique AS
-- WITH highway_footwayxfootway_sidewalk AS (
--      SELECT *
--      FROM compare.salzburg_pgr
--      WHERE tags_h -> 'highway' IN ('footway')
--        AND tags_h -> 'footway' IN ('sidewalk')
-- ),
-- sidewalk AS (
--      SELECT *
--      FROM compare.salzburg_pgr
--      WHERE tags_h ? 'sidewalk'
--        AND tags_h -> 'sidewalk' NOT IN ('no')
-- )
-- SELECT * FROM highway_footwayxfootway_sidewalk
-- UNION
-- SELECT * FROM sidewalk AS aa
-- WHERE aa.gid NOT IN (
--      SELECT aa.gid
--      FROM highway_footwayxfootway_sidewalk AS bb
--      WHERE st_dwithin(st_transform(aa.the_geom, 3857), st_transform(bb.the_geom, 3857), 15)
--         OR ST_Intersects(st_transform(aa.the_geom, 3857), st_transform(bb.the_geom, 3857))
-- );
-- 
-- -- 3km buffer network extracts (Graz center coordinates as provided).
-- DROP TABLE IF EXISTS compare.graz_pgr_3km;
-- CREATE TABLE compare.graz_pgr_3km AS
-- SELECT *
-- FROM graz_pgr
-- WHERE st_within(
--      st_transform(the_geom, 3857),
--      st_buffer(st_transform(ST_SetSRID(st_point(15.438323, 47.072197), 4326), 3857), 3000, 'quad_segs=20')
-- );
-- 
-- DROP TABLE IF EXISTS compare.linz_pgr_3km;
-- CREATE TABLE compare.linz_pgr_3km AS
-- SELECT *
-- FROM compare.linz_pgr
-- WHERE st_within(
--      st_transform(the_geom, 3857),
--      st_buffer(st_transform(ST_SetSRID(st_point(15.438323, 47.072197), 4326), 3857), 3000, 'quad_segs=20')
-- );
-- 
-- DROP TABLE IF EXISTS compare.salzburg_pgr_3km;
-- CREATE TABLE compare.salzburg_pgr_3km AS
-- SELECT *
-- FROM compare.salzburg_pgr
-- WHERE st_within(
--      st_transform(the_geom, 3857),
--      st_buffer(st_transform(ST_SetSRID(st_point(15.438323, 47.072197), 4326), 3857), 3000, 'quad_segs=20')
-- );
-- 
-- -- Area summary per city border (km^2).
-- DROP TABLE IF EXISTS compare.city_area_km2;
-- CREATE TABLE compare.city_area_km2 AS
-- SELECT 'graz' AS city, st_area(graz_border.geom::geography) / 1000000 AS area_km2
-- UNION ALL
-- SELECT 'linz' AS city, st_area(linz_border.geom::geography) / 1000000 AS area_km2
-- UNION ALL
-- SELECT 'salzburg' AS city, st_area(salzburg_border.geom::geography) / 1000000 AS area_km2;
-- 
-- -- Summary counts and lengths for comparison outputs.
-- DROP TABLE IF EXISTS compare.summary_counts;
-- CREATE TABLE compare.summary_counts AS
-- SELECT 'total_edges_3km' AS metric,
--         (SELECT COUNT(*) FROM graz_pgr_3km) AS graz,
--         (SELECT COUNT(*) FROM compare.linz_pgr_3km) AS linz,
--         (SELECT COUNT(*) FROM compare.salzburg_pgr_3km) AS salzburg
-- UNION ALL
-- SELECT 'footway_edges_3km' AS metric,
--         (SELECT COUNT(*) FROM graz_pgr_3km WHERE tags_h -> 'highway' IN ('footway')),
--         (SELECT COUNT(*) FROM compare.linz_pgr_3km WHERE tags_h -> 'highway' IN ('footway')),
--         (SELECT COUNT(*) FROM compare.salzburg_pgr_3km WHERE tags_h -> 'highway' IN ('footway'))
-- UNION ALL
-- SELECT 'sidewalk_edges_3km' AS metric,
--         (SELECT COUNT(*) FROM graz_pgr_3km WHERE tags_h ? 'sidewalk'),
--         (SELECT COUNT(*) FROM compare.linz_pgr_3km WHERE tags_h ? 'sidewalk'),
--         (SELECT COUNT(*) FROM compare.salzburg_pgr_3km WHERE tags_h ? 'sidewalk')
-- UNION ALL
-- SELECT 'sidewalk_length_m_3km' AS metric,
--         (SELECT SUM(length_m) FROM graz_pgr_3km WHERE tags_h ? 'sidewalk'),
--         (SELECT SUM(length_m) FROM compare.linz_pgr_3km WHERE tags_h ? 'sidewalk'),
--         (SELECT SUM(length_m) FROM compare.salzburg_pgr_3km WHERE tags_h ? 'sidewalk')
-- UNION ALL
-- SELECT 'total_length_m_3km' AS metric,
--         (SELECT SUM(length_m) FROM graz_pgr_3km),
--         (SELECT SUM(length_m) FROM compare.linz_pgr_3km),
--         (SELECT SUM(length_m) FROM compare.salzburg_pgr_3km);
-- 
-- -- Sidewalk coverage percentage per city (sidewalk length / total length * 100).
-- DROP TABLE IF EXISTS compare.summary_percentages;
-- CREATE TABLE compare.summary_percentages AS
-- SELECT 'graz' AS city,
--         (SELECT SUM(length_m) FROM graz_pgr_3km WHERE tags_h ? 'sidewalk')
--         / NULLIF((SELECT SUM(length_m) FROM graz_pgr_3km), 0) * 100 AS sidewalk_pct
-- UNION ALL
-- SELECT 'linz' AS city,
--         (SELECT SUM(length_m) FROM compare.linz_pgr_3km WHERE tags_h ? 'sidewalk')
--         / NULLIF((SELECT SUM(length_m) FROM compare.linz_pgr_3km), 0) * 100 AS sidewalk_pct
-- UNION ALL
-- SELECT 'salzburg' AS city,
--         (SELECT SUM(length_m) FROM compare.salzburg_pgr_3km WHERE tags_h ? 'sidewalk')
--         / NULLIF((SELECT SUM(length_m) FROM compare.salzburg_pgr_3km), 0) * 100 AS sidewalk_pct;
