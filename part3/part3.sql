-- 1. stiahnite a importujte si dataset pre Open Street mapy z
-- http://download.freemap.sk/slovakia.osm/slovakia.osm.pbf do novej DB

select distinct st_srid(shape)
from kraj_0;

select distinct st_srid(way)
from planet_osm_polygon;

select * from raster_columns limit 10;

CREATE INDEX polygon_gist ON planet_osm_polygon USING GIST (way);


-- 2. zistite aké kraje sú na Slovensku (planet_osm_polygon, admin_level = ‘4’) a vypíšte
-- ich súradnice ako text s longitude a latitude.

select name, ST_X(center) AS longitude, ST_Y(center) AS latitude
from (select st_centroid(st_transform(way, 4326)) as center, name
      from planet_osm_polygon
      where admin_level = '4')
         as kraj;


-- 3. zoraďte kraje podľa ich veľkosti (st_area). Veľkosť vypočítajte pomocou vhodnej
-- funkcie a zobrazte v km^2 v SRID 4326.

select name, round(CAST(st_area(st_transform(way, 4326), True) / 1000000 as numeric), 2) as area
from planet_osm_polygon
where admin_level = '4'
order by area desc;


-- 4. pridajte si dom, kde bývate ako polygón (nájdite si súradnice napr. cez google maps)
-- do planet_osm_polygon (znova pozor na súradnicový systém). Výsledok zobrazte na
-- mape.

insert into planet_osm_polygon(name, way)
VALUES ('HomeLamac', st_transform(st_geometryfromtext(
                                          'POLYGON((17.0475554 48.19529379989072,17.0475962 48.19519249989075,17.047604799999995 48.19516939989074,17.0476362 48.19509129989077,17.0478294 48.19512599989077,17.0478263 48.195134799890766,17.047887199999998 48.19514689989076,17.047805599999997 48.19534819989071,17.0476106 48.19531329989072,17.0476146 48.19530459989071,17.0475554 48.19529379989072))',
                                          4326), 3857));

select st_transform(way, 4326) from planet_osm_polygon
where name = 'HomeLamac';

-- check insertion
select name
from planet_osm_polygon
where st_contains(st_transform(way, 4326), st_geometryfromtext('POINT(17.04779972521799 48.19521100579525)', 4326));

-- chek size of house
select name, round(CAST(st_area(st_transform(way, 4326), True) as numeric), 2) as area
from planet_osm_polygon
where name = 'HomeLamac';

-- 5. zistite v akom kraji je váš dom.

select name
from planet_osm_polygon
where admin_level = '4'
  and st_contains(way, (select way from planet_osm_polygon where name = 'HomeLamac'));

-- 6. pridajte si do planet_osm_point vašu aktuálnu polohu (pozor na súradnicový
-- systém). Výsledok zobrazte na mape.


insert into planet_osm_point(name, way)
VALUES ('CurrentPosition',
        st_transform(st_geometryfromtext('POINT(17.04779972521799 48.19521100579525)', 4326), 3857));

select st_transform(way, 4326) from planet_osm_point
where name = 'CurrentPosition';

-- 7. zistite či ste doma - či je vaša poloha v rámci vášho bývania.

select st_contains(home.way, position.way) from ( select way from planet_osm_polygon
    where name = 'HomeLamac') as home
cross join planet_osm_point as position
    where name = 'CurrentPosition';

-- 8. zistite ako ďaleko sa nachádzate od FIIT (name = 'Fakulta informatiky a informačných
-- technológií STU'). Pozor na správny súradnicový systém – vzdialenosť musí byť
-- skutočná.

select  st_distance(st_transform(school.way, 4326), st_transform(position.way, 4326) , true) /1000 as distance
from (select way from planet_osm_polygon
    where name = 'Fakulta informatiky a informačných technológií STU') as school
cross join planet_osm_point as position
    where name = 'CurrentPosition';

-- 9. Stiahnite si QGIS a vyplotujte kraje a váš dom z úlohy 2 na mape - napr. červenou
-- čiarou.

select st_buffer(ST_Transform(way, 5514), 1) as home
from "public"."planet_osm_polygon"
where name = 'HomeLamac';

select st_transform(way, 5514)
from "public"."planet_osm_polygon"
where admin_level = '4';

-- 10. Zistite súradnice centroidu (ťažiska) plošne najmenšieho okresu (vo výsledku
-- nezabudnite uviesť aj EPSG kód súradnicového systému).

select name, st_area(st_transform(way, 4326), true) as comp_area, st_astext(st_centroid(st_transform(way, 4326)))
from planet_osm_polygon
where admin_level = '4'
order by comp_area limit 1;

-- 11. Vytvorte priestorovú tabuľku všetkých úsekov ciest, ktorých vzdialenosť od
-- vzájomnej hranice okresov Malacky a Pezinok je menšia ako 10 km.

-- step 1
select ST_Transform(way, 5514) from planet_osm_polygon
where name = 'okres Pezinok';

-- step 2
select ST_Transform(way, 5514) from planet_osm_polygon
where name = 'okres Malacky';

-- step 3
select st_intersection(pesinok.p_way, malacky.m_way) as i_way from
	(select st_transform(way, 4326) as p_way from planet_osm_polygon
		where name = 'okres Pezinok') as pesinok
	cross join
	(select st_transform(way, 4326) as m_way from planet_osm_polygon
		where name = 'okres Malacky') as malacky;

-- final
select st_transform(road.way, 4326) as r_way from planet_osm_roads as road
cross join
(select st_intersection(pesinok.p_way, malacky.m_way)as i_way from
	(select st_transform(way, 4326) as p_way from planet_osm_polygon
		where name = 'okres Pezinok') as pesinok
	cross join
	(select st_transform(way, 4326) as m_way from planet_osm_polygon
		where name = 'okres Malacky') as malacky) as pesonok_malacky_intersection
where st_distance(st_transform(road.way, 4326), pesonok_malacky_intersection.i_way) < 10000;


-- 12. Jedným dopytom zistite číslo a názov katastrálneho územia (z dát ZBGIS,
-- https://www.geoportal.sk/sk/zbgis_smd/na-stiahnutie/), v ktorom sa nachádza
-- najdlhší úsek cesty (z dát OSM) v okrese, v ktorom bývate.

-- longest road in okres Bratislava IV
select st_transform(roads.way, 5514) from (select way from planet_osm_roads
    where ref is not null and
          boundary is null) as roads
cross join (
    select way from planet_osm_polygon
    where name = 'okres Bratislava IV') as okres
where st_contains(okres.way, roads.way)
order by st_length(st_transform(roads.way, 4326), true) desc limit 1;

-- final
select nm5, idn5 from ku_0

cross join

(select roads.way from (select way from planet_osm_roads
    where ref is not null and
          boundary is null) as roads
cross join (
    select way from planet_osm_polygon
    where name = 'okres Bratislava IV') as okres
where st_contains(okres.way, roads.way)
order by st_length(st_transform(roads.way, 4326), true) desc limit 1) as road_final

where ST_Intersects(st_transform(ku_0.shape, 4326), st_transform(road_final.way, 4326));


-- 13. Vytvorte oblasť Okolie_Bratislavy, ktorá bude zahŕňať zónu do 20 km od Bratislavy,
-- ale nebude zahŕňať oblasť Bratislavy (Bratislava I až Bratislava V) a bude len na území
-- Slovenska. Zistite jej výmeru.

select
st_transform(
	st_difference(
		st_intersection(
			st_buffer(bratislava.way, 20000),
			slovensko.way),
		bratislava.way)
, 4326)
from( select st_transform(way, 5514) as way
    from planet_osm_polygon
    where name = 'Bratislava' and
          admin_level = '6') bratislava
cross join
    (select st_transform(way, 5514) as way from planet_osm_polygon
        where name = 'Slovensko') as slovensko;

