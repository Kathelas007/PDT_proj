
copy (
    select row_to_json(et)
    from (select t.id                                               as _id,
                 t.content,
                 t.favorite_count,
                 t.retweet_count,
                 t.favorite_count,
                 t.happened_at,
                 t.parent_id                                        as parent_tweet,

                 (select row_to_json(author.*)
                  from (select id, name, screen_name
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
    )
    TO STDOUT with (FORMAT text, HEADER FALSE);
