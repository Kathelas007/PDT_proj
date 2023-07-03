CREATE INDEX IF NOT EXISTS tweets_author_id ON tweets USING hash (author_id);
CREATE INDEX IF NOT EXISTS tweets_parent_id ON tweets USING hash (parent_id);

CREATE INDEX IF NOT EXISTS ht_tweets ON tweet_hashtags USING hash (tweet_id);
CREATE INDEX IF NOT EXISTS  ht_hashtags ON tweet_hashtags USING hash (hashtag_id);

CREATE INDEX IF NOT EXISTS  mentions_tweets ON tweet_mentions USING hash (tweet_id);
CREATE INDEX IF NOT EXISTS  mentions_account ON tweet_mentions USING hash (account_id);

CREATE INDEX IF NOT EXISTS  tweets_id ON public.tweets USING hash (id);
CREATE INDEX IF NOT EXISTS  accounts_id ON public.accounts USING hash (id);
CREATE INDEX IF NOT EXISTS  mentions_id ON public.tweet_mentions USING hash (id);
CREATE INDEX IF NOT EXISTS  th_id ON public.tweet_hashtags USING hash (id);
CREATE INDEX IF NOT EXISTS  hashtags_id ON public.hashtags USING hash (id);
