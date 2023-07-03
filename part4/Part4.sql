CREATE INDEX tweets_author_id ON tweets USING hash (author_id);
CREATE INDEX tweets_parent_id ON tweets USING hash (parent_id);

CREATE INDEX ht_tweets ON tweet_hashtags USING hash (tweet_id);
CREATE INDEX ht_hashtags ON tweet_hashtags USING hash (hashtag_id);

CREATE INDEX mentions_tweets ON tweet_mentions USING hash (tweet_id);
CREATE INDEX mentions_account ON tweet_mentions USING hash (account_id);

CREATE INDEX tweets_id ON public.tweets USING hash (id);
CREATE INDEX accounts_id ON public.accounts USING hash (id);
CREATE INDEX mentions_id ON public.tweet_mentions USING hash (id);
CREATE INDEX th_id ON public.tweet_hashtags USING hash (id);
CREATE INDEX hashtags_id ON public.hashtags USING hash (id);


-- ***************** MIGRATION  *****************************

-- *** 1. Migrate Tweets

-- we will work multiple times with extreme tweets only
-- materialized view instead of where condition
create MATERIALIZED VIEW extreme_tweets AS
select id,
       content,
       location,
       retweet_count,
       favorite_count,
       happened_at,
       author_id,
       country_id,
       parent_id
from tweets
where extreme_sentiment is TRUE;

-- check in small

select *
from (select t.id                                               as _id,
             t.content,
             t.favorite_count,
             t.retweet_count,
             t.favorite_count,
             t.happened_at,
             t.parent_id                                        as parent_tweet,

             (select row_to_json(author.*)
              from (select name, screen_name
                    from accounts
                    where t.author_id = accounts.id) as author) as author,

             (select array_to_json(array_agg(hasttags.value))
              from (select value
                    from hashtags
                             right join tweet_hashtags th on hashtags.id = th.hashtag_id
                    where t.id = th.tweet_id
                    limit 10) as hasttags)                      as hashtags,

             (select row_to_json(country_sq)
              from (select c.name, c.code
                    from countries c
                    where t.country_id = c.id) as country_sq)   as country,

             (select array_to_json(array_agg(mentions))
              from (select a.id, screen_name, name
                    from tweet_mentions tm
                             left join accounts a on tm.account_id = a.id
                    where t.id = tm.tweet_id
                    limit 10) as mentions)                      as mentions

      from extreme_tweets t
      limit 10) as et
limit 10;

-- export to json
explain
-- copy (
select row_to_json(et)
from (select t.id                                               as _id,
             t.content,
             t.favorite_count,
             t.retweet_count,
             t.favorite_count,
             t.happened_at,
             t.parent_id                                        as parent_tweet,

             (select row_to_json(author.*)
              from (select name, screen_name
                    from accounts
                    where t.author_id = accounts.id) as author) as author,

             (select array_to_json(array_agg(hasttags.value))
              from (select value
                    from hashtags
                             right join tweet_hashtags th on hashtags.id = th.hashtag_id
                    where t.id = th.tweet_id) as hasttags)      as hashtags,

             (select row_to_json(country_sq)
              from (select c.name, c.code
                    from countries c
                    where t.country_id = c.id) as country_sq)   as country,

             (select array_to_json(array_agg(mentions))
              from (select a.id, screen_name, name
                    from tweet_mentions tm
                             left join accounts a on tm.account_id = a.id
                    where t.id = tm.tweet_id) as mentions)      as mentions

      from extreme_tweets t) as et
;
--     )
--     TO STDOUT with (FORMAT text, HEADER FALSE);

-- *** 1. Migrate Account

-- check in small
select row_to_json(a.*)
from (select *
      from accounts) as a
limit 10;

-- to json
copy (
    select row_to_json(a.*)
    from (select accounts.*
          from accounts
                   inner join extreme_tweets et on et.author_id = accounts.id
         ) as a)
    TO STDOUT with (FORMAT text, HEADER FALSE);

select *
from extreme_tweets
where parent_id is not null;

-- *** Migrate to Elastic search

select row_to_json(metadata)
from (select row_to_json(metadata_values) as index
      from (
               select 'products' as _index,
                      '300'      as _id)
               as metadata_values) as metadata;

select row_to_json(et) as tweets
from (select t.id,
             t.favorite_count,
             t.retweet_count
      from tweets t) as et
limit 2;


select et, tw
from (select t.id,
             t.favorite_count,
             t.retweet_count
      from tweets t) as et
         left join (select 'products' as _index,
                           id         as _id
                    from tweets) as tw on tw._id = et.id
limit 2;

select (
           select to_json(final)
           from (select favorite_count, retweet_count) as final) as tweets,
       json_build_object('index',
                         (select to_json(sq)
                          from (
                                   select 'products' as _index,
                                          id         as _id
                               ) as sq))                         as metadata
from (select t.id,
             t.favorite_count,
             t.retweet_count
      from tweets t) as et
limit 2;

-- export to json
-- copy (
select row_to_json(et) as tweets
from (select t.id                                               as _id,
             t.content,
             t.favorite_count,
             t.retweet_count,
             t.favorite_count,
             t.happened_at,
             t.parent_id                                        as parent_tweet,

             (select row_to_json(author.*)
              from (select id, name, screen_name, description, statuses_count
                    from accounts
                    where t.author_id = accounts.id) as author) as author,

             (select array_to_json(array_agg(hasttags.value))
              from (select value
                    from hashtags
                             right join tweet_hashtags th on hashtags.id = th.hashtag_id
                    where t.id = th.tweet_id) as hasttags)      as hashtags,

--                  (select row_to_json(country_sq)
--                   from (select c.name, c.code
--                         from countries c
--                         where t.country_id = c.id) as country_sq)   as country,

             (select array_to_json(array_agg(mentions))
              from (select a.id, screen_name, name
                    from tweet_mentions tm
                             left join accounts a on tm.account_id = a.id
                    where t.id = tm.tweet_id) as mentions)      as mentions

      from extreme_tweets t) as et

limit 2;
;
--     )
--     TO STDOUT with (FORMAT text, HEADER FALSE);

select count(id)
from tweets;

select count(et)
from (select t.id                                               as _id,
             t.content,
             t.favorite_count,
             t.retweet_count,
             t.favorite_count,
             t.happened_at,
             t.parent_id                                        as parent_tweet,

             (select row_to_json(author.*)
              from (select id, name, screen_name, description, followers_count, statuses_count
                    from accounts
                    where t.author_id = accounts.id) as author) as author,

             (select array_to_json(array_agg(hasttags.value))
              from (select value
                    from hashtags
                             right join tweet_hashtags th on hashtags.id = th.hashtag_id
                    where t.id = th.tweet_id) as hasttags)      as hashtags,


             (select array_to_json(array_agg(mentions))
              from (select a.id, screen_name, name
                    from tweet_mentions tm
                             left join accounts a on tm.account_id = a.id
                    where t.id = tm.tweet_id) as mentions)      as mentions

      from tweets t) as et
limit 20;

select count(et)
from (select t.id                                               as _id,
             t.content,
             t.favorite_count,
             t.retweet_count,
             t.favorite_count,
             t.happened_at,
             t.parent_id                                        as parent_tweet

             (select row_to_json(author.*)
              from (select id, name, screen_name, description
                    from accounts
                    where t.author_id = accounts.id) as author) as author

             (select array_to_json(array_agg(hasttags.value))
              from (select value
                    from hashtags
                             right join tweet_hashtags th on hashtags.id = th.hashtag_id
                    where t.id = th.tweet_id) as hasttags)      as hashtags


             (select array_to_json(array_agg(mentions))
              from (select a.id, screen_name, name
                    from tweet_mentions tm
                             left join accounts a on tm.account_id = a.id
                    where t.id = tm.tweet_id) as mentions)      as mentions

      from extreme_tweets t) as et;




  select row_to_json(et)
    from (select t.id                                               as _id,
                 t.content,
                 t.favorite_count,
                 t.retweet_count,
                 t.favorite_count,
                 t.happened_at,
                 t.parent_id                                        as parent_tweet,

                 (select row_to_json(author.*)
                  from (select id,  name, screen_name, description, followers_count, statuses_count
                        from accounts
                        where t.author_id = accounts.id) as author) as author,

                 (select array_to_json(array_agg(hasttags.value))
                  from (select value
                        from hashtags
                                 right join tweet_hashtags th on hashtags.id = th.hashtag_id
                        where t.id = th.tweet_id) as hasttags)      as hashtags,


                 (select array_to_json(array_agg(mentions))
                  from (select a.id, screen_name, name
                        from tweet_mentions tm
                                 left join accounts a on tm.account_id = a.id
                        where t.id = tm.tweet_id) as mentions)      as mentions

          from tweets t
        inner join tweet_mentions on t.id = tweet_mentions.tweet_id) as et
limit 50 offset 30976050 ;

