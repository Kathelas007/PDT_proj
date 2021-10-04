#!/usr/bin/python
import re
from typing import Union, Iterator

import pandas as pd
import sqlalchemy
import configparser
import multiprocessing as mp
import multiprocesspandas
import emoji
import logging

from timeit import default_timer as timer

import nltk

nltk.download('vader_lexicon')
from nltk.sentiment.vader import SentimentIntensityAnalyzer

# BillGAtes not in all

conspiracy_teories = {'Deep State': ('DeepstateVirus', 'DeepStateVaccine', 'DeepStateFauci',),
                      'Qanon': ('QAnon', 'MAGA', 'WWG1WGA',),
                      'New world order': ('Agenda21',),
                      'The virus escaped from a Chinese lab': ('CCPVirus', 'ChinaLiedPeopleDied',),
                      'GLobal Warming is HOAX': ('ClimateChangeHoax', 'GlobalWarmingHoax',),
                      'COVID19 and microchipping': ('SorosVirus', 'BillGAtes',),
                      'COVID19 is preaded by 5G': ('5GCoronavirus',),
                      'Moon landing is fake': ('MoonLandingHoax', 'moonhoax'),
                      '9/11 was inside job': ('911truth', '911insidejob',),
                      'Pizzagate conspiracy theory': ('pizzaGateIsReal', 'PedoGateIsReal',),
                      'Chemtrails': ('Chemtrails',),
                      'FlatEarth': ('flatEarth',),
                      'Illuminati': ('illuminati',),
                      'Reptilian conspiracy theory': ('reptilians',)}
engine = None


def open_db_connection():
    logging.debug('Opening DB connection')
    global engine
    engine = sqlalchemy.create_engine('postgresql+psycopg2://kate:bNp2Crvxrbwz@spodlesny.eu:54320/pdt2021_tweets', )


def close_db_connection():
    logging.debug('Closing DB connection')
    global engine
    engine.dispose()


sid = SentimentIntensityAnalyzer()
mention_retweet_pattern_re = re.compile(r'(?<!\w)(RT )?(@[\w]{1,20}(?!\w))')
hashtag_pattern_re = re.compile(r'(?<!\w)(#[\w]{1,20})')
emoji_pattern_re = re.compile(emoji.get_emoji_regexp())


def remove_ignored_from_contend(contend: str):
    """
    Remove mentions, hashtags, retweets and emojis from string
    :param contend: input string
    :return: cleaned input

    >>> remove_ignored_from_contend("RT @EdehAlexi: So suddenly the same ...")
    ': So suddenly the same ...'
    >>> remove_ignored_from_contend("ROBERT @EdehAlexi: So suddenly the same ...")
    'ROBERT : So suddenly the same ...'
    >>> remove_ignored_from_contend("this@nop, this @yes")
    'this@nop, this '
    >>> remove_ignored_from_contend("name@gmail.com")
    'name@gmail.com'
    >>> remove_ignored_from_contend("too @long_user_name_to_be_valid_as_user_name_by_twitter_account")
    'too @long_user_name_to_be_valid_as_user_name_by_twitter_account'
    >>> remove_ignored_from_contend("smajlik 😁")
    'smajlik '
    >>> remove_ignored_from_contend('twitter new emoji 😶‍🌫️ ❤️‍🩹')
    'twitter new emoji  '
    >>> remove_ignored_from_contend('my #ht ')
    'my  '
    """

    contend = re.sub(mention_retweet_pattern_re, '', contend)
    contend = re.sub(emoji_pattern_re, '', contend)
    contend = re.sub(hashtag_pattern_re, '', contend)

    return contend


def column_exists(column: str, table='tweets'):
    with engine.connect() as conn:
        result = conn.execute(
            f"""SELECT column_name FROM information_schema.columns 
            WHERE table_name = '{table}' and column_name = '{column}'""").fetchone()
        return result is not None


def add_column(column, table='tweets', dt='bool'):
    with engine.connect() as conn:
        conn.execute(f'ALTER TABLE {table} ADD COLUMN IF NOT EXISTS {column} {dt}')


def count_compound(contend):
    global sid

    contend = remove_ignored_from_contend(contend)
    compound = sid.polarity_scores(contend)['compound']

    if (compound < -0.5) or (compound > 0.5):
        return True
    else:
        return False


def get_pd_select_conspiracy_iter(table, columns: str, chunksize, limit=None) -> Union[Iterator]:
    query_text = """
      select t.id, t.content from 
        (select id from hashtags
          where value in ('DeepStateVaccine', 'DeepStateFauci', 'QAnon', 'Agenda21', 'CCPVirus', 'ClimateChangeHoax',
                          'GlobalWarmingHoax', 'ChinaLiedPeopleDied', 'SorosVirus', '5GCoronavirus', 'MAGA', 'WWG1WGA', 
                          'Chemtrails',  'flatEarth', 'MoonLandingHoax', 'moonhoax', 'illuminati', 'pizzaGateIsReal',
                          'PedoGateIsReal', '911truth', '911insidejob', 'reptilians')) 
         as hashtags_filter
         inner join tweet_hashtags th on hashtags_filter.id = th.hashtag_id
         inner join tweets t on th.tweet_id = t.id"""

    if limit is not None:
        query_text = query_text + f' limit {limit}'

    return pd.read_sql_query(query_text, con=engine, chunksize=chunksize)


def create_tmp_sentiment_table(tmp_table_name, sentiment_col):
    logging.debug('Creating sentiment in tmp table')
    for tweet_chunk_df in get_pd_select_conspiracy_iter(table='tweets', columns='id, content', chunksize=1_000_000,
                                                        limit=1_000_000):
        compound = tweet_chunk_df['content'].apply_parallel(count_compound, num_processes=mp.cpu_count())
        tweet_chunk_df[sentiment_col] = compound
        new_table = tweet_chunk_df[['id', sentiment_col]].set_index('id')
        new_table.to_sql(tmp_table_name, con=engine, if_exists='append')


def copy_column(column_name, src_table, dst_table, on='id'):
    with engine.connect() as conn:
        conn.execute(
            f"""update {dst_table} as dst 
            set {column_name} = src.{column_name} 
            from {src_table} as src where src.{on} = dst.{on}""")


def delete_table(table_name):
    with engine.connect() as conn:
        conn.execute(
            f"""DROP TABLE IF EXISTS {table_name}""")


def add_extreme_sentiment():
    extreme_col_name = 'extreme_sentiment'

    if column_exists('extreme_sentiment'):
        logging.info('Sentiment already counted. Skipping')
        return

    tmp_table = 'tmp_ex_sen'
    s = timer()
    create_tmp_sentiment_table(tmp_table, extreme_col_name)
    e = timer()

    logging.debug('Creating sentiment lasted: ', e - s)

    add_column(extreme_col_name)

    logging.debug('Copy sentiment to tweet table', e - s)
    s = timer()
    copy_column(extreme_col_name, tmp_table, 'tweets')
    e = timer()
    logging.debug('Copying of sentiment lasted: ', e - s)

    delete_table(tmp_table)


def create_tables_by_conspiracy():
    ...


def make_plots():
    ...


def main():
    open_db_connection()

    add_extreme_sentiment()
    create_tables_by_conspiracy()
    make_plots()

    close_db_connection()


if __name__ == "__main__":
    # import doctest
    # doctest.testmod()

    s = timer()
    main()
    e = timer()
    logging.debug(f'Program lasted {e - s}')
