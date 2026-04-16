select table_name from information_schema.tables where table_schema = 'public';


--1: determine types of spatial data and srid in imported tables

SELECT
	f_table_schema as SCHEMA,
	f_table_name as TABLE_NAME,
	f_geometry_column as geometry_column,
	type as geometry_type,
	srid,
	coord_dimension as dimension
from geometry_columns
WHERE f_table_name LIKE '10m_physical%'
	AND f_table_schema = 'public'
ORDER BY f_table_name;

--2: detarmine atributive columns

SELECT
	TABLE_NAME,
	string_agg(column_name, ', ' ORDER BY ordinal_position) as attribute_columns
FROM information_schema.columns
WHERE table_schema = 'public'
	and "table_name" like '10m_physical%'
	and udt_name not in ('geometry','geography','raster')
GROUP BY TABLE_NAME
ORDER BY TABLE_NAME;

--3: return descriptions of all spatial objects in WKT(Well-Known-Text) format
DO $$ 
DECLARE 
    r RECORD;
    wkt_sample TEXT;
BEGIN
    FOR r IN (
        SELECT table_schema, table_name 
        FROM information_schema.tables 
        WHERE table_name LIKE '10m_physical%' AND table_schema = 'public'
    ) LOOP
        EXECUTE format('SELECT ST_AsText(geom) FROM %I.%I LIMIT 1', r.table_schema, r.table_name) 
        INTO wkt_sample;
        
        RAISE NOTICE 'Table: % | WKT Sample: %', r.table_name, LEFT(wkt_sample, 100) || '...';
    END LOOP;
END $$;

--4: get interface of some two spatial objects

SELECT
    a.id AS bathy_id,
    b.id AS other_id,
    ST_AsText(ST_Intersection(a.geom, b.geom)) AS intersection_geom
FROM
    "public"."10m_physical—ne_10m_bathymetry_A_10000_shp" a 
JOIN
    "public"."10m_physical—ne_10m_bathymetry_B_9000_shp" b 
ON
    ST_Intersects(a.geom, b.geom)
WHERE
    NOT ST_IsEmpty(ST_Intersection(a.geom, b.geom));
    
    
--5: get top points of spatial objects

SELECT
    a.id AS object_id,
    (ST_DumpPoints(a.geom)).path[1] AS vertex_index,
    ST_X((ST_DumpPoints(a.geom)).geom) AS x_coord,
    ST_Y((ST_DumpPoints(a.geom)).geom) AS y_coord
FROM
    "public"."10m_physical—ne_10m_bathymetry_A_10000_shp" a 
WHERE	
    a.id = 1;
    
    
--6: fing a square of spatial objects

SELECT
	id,
	st_area(geom::geography) as area_sq_meters,
	st_area(geom::geography)/1000000 as area_sq_km
FROM
	"public"."10m_physical—ne_10m_bathymetry_A_10000_shp"
where
	id=1;
	

--7: create a spatial object as a dot, line and a polygon

SELECT ST_GeomFromText('POINT(-174.9 23.5)', 4326) AS created_point;

SELECT ST_GeomFromText('LINESTRING(-175.0 -23.7, -174.8 -23.4)', 4326) AS route_line;

SELECT ST_GeomFromText('POLYGON((-175.0 -23.7, -174.9 -23.7, -174.9 -23.6, -175.0 -23.6, -175.0 -23.7))', 4326) AS square_geom;


--8: find intersection between objects imported from qgis and previously created once

DO $$
DECLARE
    
    geoms geometry[] := ARRAY[
        ST_GeomFromText('POINT(-174.9 23.5)', 4326),
        ST_GeomFromText('LINESTRING(-175.0 -23.7, -174.8 -23.4)', 4326),
        ST_GeomFromText('POLYGON((-175.0 -23.7, -174.9 -23.7, -174.9 -23.6, -175.0 -23.6, -175.0 -23.7))', 4326)
    ];
   
    geom_names text[] := ARRAY['Point', 'Line', 'Polygon'];
    
    r RECORD;
    v_count integer;
    i integer;
BEGIN
    RAISE NOTICE '--- Searching for intersections ---';

    
    FOR r IN 
        SELECT table_schema, table_name, column_name
        FROM information_schema.columns
        WHERE table_name LIKE '10m_physical%' 
          AND udt_name = 'geometry' 
    LOOP
    
        FOR i IN 1..3 LOOP
            EXECUTE format('SELECT count(*) FROM %I.%I WHERE ST_Intersects(%I, $1)', 
                           r.table_schema, r.table_name, r.column_name)
            INTO v_count
            USING geoms[i];

            IF v_count > 0 THEN
                RAISE NOTICE 'Spatial object [%]: found % intersections with table %', 
                             geom_names[i], v_count, r.table_name;
            END IF;
        END LOOP;
    END LOOP;

    RAISE NOTICE '---Search complete ---';
END $$;

--9: demonstrate spatial objects indexsation

DO $$
DECLARE
    rec RECORD;
BEGIN
    FOR rec IN 
        SELECT table_name, column_name 
        FROM information_schema.columns 
        WHERE table_name LIKE '10m_physical%' 
          AND udt_name = 'geometry'
    LOOP
        IF NOT EXISTS (
            SELECT 1 FROM pg_class c
            JOIN pg_index i ON c.oid = i.indexrelid
            JOIN pg_attribute a ON a.attrelid = c.oid
            WHERE c.relname = 'idx_' || rec.table_name || '_gist'
        ) THEN
            EXECUTE format('CREATE INDEX %I ON %I USING GIST (%I)', 
                'idx_' || rec.table_name || '_gist', 
                rec.table_name, 
                rec.column_name);
            
            RAISE NOTICE 'Index created for table: %', rec.table_name;
        END IF;
    END LOOP;
END $$;

EXPLAIN ANALYZE
SELECT * 
FROM "public"."10m_physical—ne_10m_lakes_europe_shp"
WHERE ST_Intersects(geom, ST_GeomFromText('POINT(30 50)', 4326));


--10: stored procedure for finding point's intersection with spatial objects

CREATE OR REPLACE FUNCTION find_containing_physical_object(lon DOUBLE PRECISION, lat DOUBLE PRECISION)
RETURNS TABLE (
    source_table TEXT,
    object_id TEXT,
    object_name TEXT,
    geom_wkt TEXT
) AS $$
DECLARE
    target_point GEOMETRY;
    rec RECORD;
    id_col TEXT;
    name_col TEXT;
BEGIN
    target_point := ST_SetSRID(ST_MakePoint(lon, lat), 4326);

    FOR rec IN 
        SELECT table_name, column_name 
        FROM information_schema.columns 
        WHERE table_name LIKE '10m_physical%' 
          AND udt_name = 'geometry'
    LOOP
       
        SELECT column_name INTO id_col 
        FROM information_schema.columns 
        WHERE table_name = rec.table_name 
          AND column_name IN ('gid', 'id', 'fid')
        LIMIT 1;

        
        SELECT column_name INTO name_col 
        FROM information_schema.columns 
        WHERE table_name = rec.table_name 
          AND column_name IN ('name', 'name_en', 'label')
        LIMIT 1;

       
        RETURN QUERY EXECUTE format(
            'SELECT %L::text, %s::text, %s::text, ST_AsText(%I) ' ||
            'FROM %I ' ||
            'WHERE ST_Intersects(%I, %L) ' ||
            'LIMIT 1',
            rec.table_name, 
            COALESCE(id_col, '''-1'''), 
            COALESCE(name_col, '''Unknown'''), 
            rec.column_name, 
            rec.table_name, 
            rec.column_name, 
            target_point
        );
    END LOOP;
END;
$$ LANGUAGE plpgsql;

SELECT * FROM find_containing_physical_object(37.61, 55.75);