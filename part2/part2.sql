SELECT tablename, indexname, indexdef
FROM pg_indexes
WHERE schemaname = 'public'
  AND tablename = 'tweets'
ORDER BY tablename, indexname;


-- 1. Vyhľadajte v accounts screen_name s presnou hodnotou ‘realDonaldTrump’ a analyzujte
-- daný select. Akú metódu vám vybral plánovač a prečo - odôvodnite prečo sa rozhodol tak
-- ako sa rozhodol?

explain analyse
select screen_name
from accounts
where screen_name = 'realDonaldTrump';

-- 2. Koľko workerov pracovalo na danom selecte a na čo slúžia? Zdvihnite počet workerov a
-- povedzte ako to ovplyvňuje čas. Je tam nejaký strop? Ak áno, prečo? Od čoho to závisí?

SET max_parallel_workers_per_gather to 2;
SHOW max_parallel_workers;
SHOW max_parallel_workers_per_gather;

-- 3. Vytvorte btree index nad screen_name a pozrite ako sa zmenil čas a porovnajte výstup
-- oproti požiadavke bez indexu. Potrebuje plánovač v tejto požiadavke viac workerov? Čo
-- ovplyvnilo zásadnú zmenu času?

CREATE INDEX if not exists accounts_screen_name_bt ON accounts USING btree (screen_name);

explain analyse
select screen_name
from accounts
where screen_name = 'realDonaldTrump';

DROP INDEX if exists accounts_screen_name_bt;

-- 4. Vyberte používateľov, ktorý majú followers_count väčší, rovný ako 100 a zároveň menší,
-- rovný 200. Je správanie rovnaké v prvej úlohe? Je správanie rovnaké ako v tretej úlohe?
-- Prečo?

explain analyse
select name, screen_name
from accounts
where followers_count >= 100
  and followers_count <= 200;

-- 5. Vytvorte index nad 4 úlohou a popíšte prácu s indexom. Čo je to Bitmap Index Scan a
-- prečo je tam Bitmap Heap Scan? Prečo je tam recheck condition?

CREATE INDEX if not exists followers_count_bt ON accounts (followers_count);
DROP INDEX if exists followers_count_bt;

explain analyse
select name, screen_name
from accounts
where followers_count >= 100
  and followers_count <= 200;

select count(followers_count)
from accounts;
select count(followers_count)
from accounts
where followers_count >= 100
  and followers_count <= 200;

-- 6. Vyberte používateľov, ktorí majú followers_count väčší, rovný ako 100 a zároveň menší,
-- rovný 1000? V čom je rozdiel, prečo?

explain analyse
select name, screen_name
from accounts
where followers_count >= 100
  and followers_count <= 1000;

select count(followers_count)
from accounts
where followers_count >= 100
  and followers_count <= 1000;

-- 7. Vytvorte daľšie 3 btree indexy na name, friends_count, a description a insertnite si svojho
-- používateľa (to je jedno aké dáta) do accounts. Koľko to trvalo? Dropnite indexy a spravte to
-- ešte raz. Prečo je tu rozdiel?

select name, friends_count, description
from accounts
limit 2;

EXPLAIN ANALYSE
INSERT INTO accounts (name, friends_count, description)
VALUES ('RandomName559755', '5789', 'My favourit account');

DELETE
FROM accounts
where name = 'RandomName559755';

CREATE INDEX accounts_name_bt ON accounts (name);
CREATE INDEX accounts_friends_count_bt ON accounts (friends_count);
CREATE INDEX accounts_description_bt ON accounts (description);

DROP INDEX accounts_name_bt;
DROP INDEX accounts_friends_count_bt;
DROP INDEX accounts_description_bt;

-- 8. Vytvorte btree index nad tweetami pre retweet_count a pre content. Porovnajte ich dĺžku
-- vytvárania. Prečo je tu taký rozdiel? Čím je ovplyvnená dĺžka vytvárania indexu a prečo?

CREATE INDEX tweets_retweet_count_bt ON tweets (retweet_count);
CREATE INDEX tweets_content_bt ON tweets (content);

DROP INDEX If exists tweets_retweet_count_bt;
DROP INDEX If exists tweets_content_bt;

select count(distinct content), count(distinct retweet_count)
from tweets;

-- 9. Porovnajte indexy pre retweet_count, content, followers_count, screen_name,... v čom
-- sa líšia a prečo (opíšte výstupné hodnoty pre všetky indexy)?

-- a.
create extension if not exists pageinspect;

-- b.
(select 'accounts_screen_name_bt' as name, * from bt_metap('accounts_screen_name_bt'))
UNION ALL
(select 'followers_count_bt' as name, * from bt_metap('followers_count_bt'))
UNION ALL
(select 'accounts_name_bt' as name, * from bt_metap('accounts_name_bt'))
UNION ALL
(select 'accounts_friends_count_bt' as name, * from bt_metap('accounts_friends_count_bt'))
UNION ALL
(select 'accounts_description_bt' as name, * from bt_metap('accounts_description_bt'))
UNION ALL
(select 'tweets_retweet_count_bt' as name, * from bt_metap('tweets_retweet_count_bt'))
UNION ALL
(select 'tweets_content_bt' as name, * from bt_metap('tweets_content_bt'));

-- c.
(select 'accounts_screen_name_bt' as name, type, live_items, dead_items, avg_item_size, page_size, free_size
 from bt_page_stats('accounts_screen_name_bt', 1000))
UNION ALL
(select 'followers_count_bt' as name, type, live_items, dead_items, avg_item_size, page_size, free_size
 from bt_page_stats('followers_count_bt', 1000))
UNION ALL
(select 'accounts_name_bt' as name, type, live_items, dead_items, avg_item_size, page_size, free_size
 from bt_page_stats('accounts_name_bt', 1000))
UNION ALL
(select 'accounts_friends_count_bt' as name, type, live_items, dead_items, avg_item_size, page_size, free_size
 from bt_page_stats('accounts_friends_count_bt', 1000))
UNION ALL
(select 'accounts_description_bt' as name, type, live_items, dead_items, avg_item_size, page_size, free_size
 from bt_page_stats('accounts_description_bt', 1000))
UNION ALL
(select 'tweets_retweet_count_bt' as name, type, live_items, dead_items, avg_item_size, page_size, free_size
 from bt_page_stats('tweets_retweet_count_bt', 1000))
UNION ALL
(select 'tweets_content_bt' as name, type, live_items, dead_items, avg_item_size, page_size, free_size
 from bt_page_stats('tweets_content_bt', 1000));

-- d.
(select 'accounts_screen_name_bt' as name, * from bt_page_items('accounts_screen_name_bt', 1) limit 5)
UNION ALL
(select 'followers_count_bt' as name, * from bt_page_items('followers_count_bt', 1) limit 5)
UNION ALL
(select 'accounts_name_bt' as name, * from bt_page_items('accounts_name_bt', 1) limit 5)
UNION ALL
(select 'accounts_friends_count_bt' as name, * from bt_page_items('accounts_friends_count_bt', 1) limit 5)
UNION ALL
(select 'accounts_description_bt' as name, * from bt_page_items('accounts_description_bt', 1) limit 5)
UNION ALL
(select 'tweets_retweet_count_bt' as name, * from bt_page_items('tweets_retweet_count_bt', 1) limit 5)
UNION ALL
(select 'tweets_content_bt' as name, * from bt_page_items('tweets_content_bt', 1) limit 5);

-- 10. Vyhľadajte v tweets.content meno „Gates“ na ľubovoľnom mieste a porovnajte výsledok
-- po tom, ako content naindexujete pomocou btree. V čom je rozdiel a prečo?

CREATE INDEX if not exists tweets_content_bt ON tweets (content);
DROP INDEX if exists tweets_content_bt;

explain analyse
select content
from tweets
where content like '%Gates%';

-- 11. Vyhľadajte tweet, ktorý začína “The Cabel and Deep State”. Použil sa index?

explain analyse
select content
from tweets
where content like 'The Cabel and Deep State%';

-- 12. Teraz naindexujte content tak, aby sa použil btree index a zhodnoťte prečo sa pred tým
-- nad “The Cabel and Deep State” nepoužil. Použije sa teraz na „Gates“ na ľubovoľnom
-- mieste? Zdôvodnite použitie alebo nepoužitie indexu?

CREATE INDEX if not exists tweets_content_bt ON tweets (content text_pattern_ops);
DROP INDEX if exists tweets_content_bt;

explain analyse
select content
from tweets
where content like 'The Cabel and Deep State%';

explain analyse
select content
from tweets
where content like '%Gates%';


-- 13. Vytvorte nový btree index, tak aby ste pomocou neho vedeli vyhľadať tweet, ktorý konči
-- reťazcom „idiot #QAnon“ kde nezáleží na tom ako to napíšete. Popíšte čo jednotlivé funkcie
-- robia.

CREATE INDEX reverse_tweets_content_bt ON tweets (reverse(content) text_pattern_ops);

explain analyse
select content
from tweets
where content like reverse('%idiot #QAnon');

-- 14. Nájdite účty, ktoré majú follower_count menší ako 10 a friends_count väčší ako 1000 a
-- výsledok zoraďte podľa statuses_count. Následne spravte jednoduché indexy a popíšte
-- ktoré má a ktoré nemá zmysel robiť a prečo.

explain analyse
select name
from accounts
where followers_count < 10
  and friends_count > 1000
order by statuses_count;

create index accounts_followers_count_bt on accounts (followers_count);
create index accounts_friends_count_bt on accounts (friends_count);
create index accounts_statuses_count_bt on accounts (statuses_count);

drop index if exists accounts_followers_count_bt;
drop index if exists accounts_friends_count_bt;
drop index if exists accounts_statuses_count_bt;

-- 15. Na predošlú query spravte zložený index a porovnajte výsledok s tým, keď sú indexy
-- separátne. Výsledok zdôvodnite.

create index accounts_followers_friends_count_bt on accounts (followers_count, friends_count);
drop index accounts_followers_friends_count_bt;


-- 16. Upravte query tak, aby bol follower_count menší ako 1000 a friends_count väčší ako
-- 1000. V čom je rozdiel a prečo?
explain analyse
select name
from accounts
where followers_count < 1000
  and friends_count > 1000
order by statuses_count;

-- 17. Vytvorte vhodný index pre vyhľadávanie písmen bez kontextu nad screen_name v
-- accounts. Porovnajte výsledok pre vyhľadanie presne ‘realDonaldTrump’ voči btree indexu?
-- Ktorý index sa vybral a prečo? Následne vyhľadajte v texte screen_name ‘ldonaldt‘ a
-- porovnajte výsledky. Aký index sa vybral a prečo?

create index if not exists accounts_screen_name_hash on accounts using hash (screen_name);
CREATE INDEX if not exists accounts_screen_name_bt ON accounts USING btree (screen_name);

drop index accounts_screen_name_hash;
drop index accounts_screen_name_bt;

explain analyse
select screen_name
from accounts
where screen_name = 'ldonaldt';

-- 18. Vytvorte query pre slová "John" a "Oliver" pomocou FTS (tsvector a tsquery) v angličtine
-- v stĺpcoch tweets.content, accounts.decription a accounts.name, kde slová sa môžu
-- nachádzať v prvom, druhom ALEBO treťom stĺpci. Teda vyhovujúci záznam je ak aspoň jeden
-- stĺpec má „match“. Výsledky zoraďte podľa retweet_count zostupne. Pre túto query
-- vytvorte vhodné indexy tak, aby sa nepoužil ani raz sekvenčný scan (správna query dobehne
-- rádovo v milisekundách, max sekundách na super starých PC). Zdôvodnite čo je problém s
-- OR podmienkou a prečo AND je v poriadku pri joine.

ALTER TABLE tweets
    ADD COLUMN content_vector TSVECTOR;

ALTER TABLE accounts
    ADD COLUMN description_vector TSVECTOR;

ALTER TABLE accounts
    ADD COLUMN name_vector TSVECTOR;

ALTER TABLE accounts
    ADD COLUMN name_description_vector TSVECTOR;


UPDATE tweets
SET content_vector = to_tsvector('english', content);

UPDATE accounts
SET description_vector = to_tsvector('english', description);

UPDATE accounts
SET name_vector = to_tsvector('english', name);

UPDATE accounts
SET name_description_vector = to_tsvector('english', name || ' ' || description);

commit;

create extension unaccent;
CREATE EXTENSION pg_trgm;
CREATE EXTENSION btree_gin;

set maintenance_work_mem TO "20GB";

CREATE INDEX tweets_contenet_gin ON tweets USING gin (to_tsvector('english', content));
CREATE INDEX accounts_name_descriptoin_gin ON accounts USING gin (to_tsvector('english', name || ' ' || description));

CREATE INDEX tweets_contenet_gin2 ON tweets USING gin (content_vector);
CREATE INDEX accounts_name_descriptoin_gin2 ON accounts USING gin (name_description_vector);

SELECT t.content, a.description, a.name
FROM accounts a
         join tweets t on a.id = t.author_id
WHERE t.content_vector @@ to_tsquery('John & Oliver')
   or a.name_description_vector @@ to_tsquery('John & Oliver');

select count(content)
from tweets
where to_tsvector('english', content) @@ to_tsquery('John & Oliver');

select description
from accounts
where to_tsvector('english', description || ' ' || name) @@ to_tsquery('John & Oliver');

