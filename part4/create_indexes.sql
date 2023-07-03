CREATE INDEX tweets_author_id ON tweets USING hash (author_id);
CREATE INDEX tweets_parent_id ON tweets USING hash (parent_id);

CREATE INDEX ht_tweets ON tweet_hashtags USING hash (tweet_id);
CREATE INDEX ht_hashtags ON tweet_hashtags USING hash (hashtag_id);

CREATE INDEX mentions_tweets ON tweet_mentions USING hash (tweet_id);
CREATE INDEX mentions_account ON tweet_mentions USING hash (account_id);