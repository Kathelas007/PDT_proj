#!/usr/bin/python
import re
from typing import Union, Iterator

import pandas as pd
import configparser
import multiprocessing as mp
import multiprocesspandas
import emoji
import logging
from timeit import default_timer as timer

from vizualization import visualize
import db

import nltk

nltk.download('vader_lexicon')
from nltk.sentiment.vader import SentimentIntensityAnalyzer

# BillGAtes not in all

# todo mat_view_exists

conspiracy_teories = {'Deep_State': ('DeepstateVirus', 'DeepStateVaccine', 'DeepStateFauci',),
                      'Qanon': ('QAnon', 'MAGA', 'WWG1WGA',),
                      'New_world_order': ('Agenda21',),
                      'Virus_Chinese_lab': ('CCPVirus', 'ChinaLiedPeopleDied',),
                      'GLobal_Warming': ('ClimateChangeHoax', 'GlobalWarmingHoax',),
                      'COVID19_microchipping': ('SorosVirus', 'BillGAtes',),
                      'COVID19_5G': ('5GCoronavirus',),
                      'Moon_landing': ('MoonLandingHoax', 'moonhoax'),
                      'nine_eleven': ('911truth', '911insidejob',),
                      'Pizzagate': ('pizzaGateIsReal', 'PedoGateIsReal',),
                      'Chemtrails': ('Chemtrails',),
                      'FlatEarth': ('flatEarth',),
                      'Illuminati': ('illuminati',),
                      'Reptilian': ('reptilians',)}

sid = SentimentIntensityAnalyzer()
mention_retweet_pattern_re = re.compile(r'(?<!\w)(RT )?(@[\w]{1,20}(?!\w))')
hashtag_pattern_re = re.compile(r'(?<!\w)(#[\w]{1,20})')
emoji_pattern_re = re.compile(emoji.get_emoji_regexp())


def remove_ignored_from_contend(contend: str):
    """
    Remove mentions, hashtags, retweets and emojis from string
    :param contend: input string
    :return: cleaned input
    """

    contend = re.sub(mention_retweet_pattern_re, '', contend)
    contend = re.sub(emoji_pattern_re, '', contend)
    contend = re.sub(hashtag_pattern_re, '', contend)

    return contend


def count_compound(contend):
    global sid

    contend = remove_ignored_from_contend(contend)
    compound = sid.polarity_scores(contend)['compound']

    if (compound < -0.5) or (compound > 0.5):
        return True
    else:
        return False


def get_all_conspiracy_hashtags(conspiracies):
    new_hts = ()
    for consp_hts in conspiracies.values():
        new_hts = new_hts + consp_hts

    return new_hts


def create_tmp_sentiment_table(tmp_table_name, sentiment_col):
    logging.debug('Creating sentiment in tmp table')
    hashtags = get_all_conspiracy_hashtags(conspiracy_teories)
    for tweet_chunk_df in db.get_all_tweets_to_df(columns=['id', 'content'], hashtags=hashtags,
                                                  chunksize=2_000_000):
        compound = tweet_chunk_df['content'].apply_parallel(count_compound, num_processes=mp.cpu_count())
        tweet_chunk_df[sentiment_col] = compound
        new_table = tweet_chunk_df[['id', sentiment_col]].set_index('id')
        db.df_to_table(new_table, tmp_table_name, if_exists='append')

        logging.debug(f'{len(tweet_chunk_df)} rows processed.')


def add_extreme_sentiment():
    extreme_col_name = 'extreme_sentiment'

    if db.column_exists('extreme_sentiment'):
        logging.info('Sentiment already counted. Skipping')
        return

    tmp_table = 'tmp_ex_sen'
    s = timer()
    create_tmp_sentiment_table(tmp_table, extreme_col_name)
    e = timer()

    logging.debug(f'Creating sentiment lasted: {e - s}')

    db.add_column(extreme_col_name)

    logging.debug('Copy sentiment to tweet table', )
    s = timer()
    db.copy_column(extreme_col_name, tmp_table, 'tweets')
    e = timer()
    logging.debug(f'Copying of sentiment lasted: {e - s}')

    # db.delete_table(tmp_table)


def create_tables_by_conspiracy():
    first_table = list(conspiracy_teories.keys())[0]
    if db.mat_view_exists(first_table):
        logging.debug('Conspiracy tables already exists. Skipping')
        for conspiracy_name, _ in conspiracy_teories.items():
            db.mat_view_update(conspiracy_name)

    else:
        for conspiracy_name, hashtags in conspiracy_teories.items():
            db.create_mat_view_from_tweets(conspiracy_name, hashtags)


def main():
    db.open_db_connection()

    # add_extreme_sentiment()
    # create_tables_by_conspiracy()
    visualize(conspiracy_teories)

    db.close_db_connection()


if __name__ == "__main__":
    logging.basicConfig(level=logging.DEBUG)

    s = timer()
    main()
    e = timer()
    logging.debug(f'Program lasted {e - s}')
