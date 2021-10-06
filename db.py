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

# ************** CONNECTION **********************************************

engine = None


def open_db_connection():
    logging.debug('Opening DB connection')
    global engine
    engine = sqlalchemy.create_engine('postgresql+psycopg2://kate:bNp2Crvxrbwz@192.168.0.31:54320/pdt2021_tweets', )


def close_db_connection():
    logging.debug('Closing DB connection')
    global engine
    engine.dispose()


# ****** GENERAL QUERIES *************************************************

# ****** Column ****
def column_exists(column: str, table='tweets'):
    with engine.connect() as conn:
        result = conn.execute(
            f"""SELECT column_name FROM information_schema.columns 
            WHERE table_name = '{table}' and column_name = '{column}'""").fetchone()
        return result is not None


def add_column(column, table='tweets', dt='bool'):
    with engine.connect() as conn:
        conn.execute(f'ALTER TABLE {table} ADD COLUMN IF NOT EXISTS {column} {dt}')


def copy_column(column_name, src_table, dst_table, on='id'):
    with engine.connect() as conn:
        conn.execute(
            f"""update {dst_table} as dst 
            set {column_name} = src.{column_name} 
            from {src_table} as src where src.{on} = dst.{on}""")


# ****** Table ****

def table_exists(table_name):
    with engine.connect() as conn:
        result = conn.execute(
            f"""SELECT EXISTS (
               SELECT FROM information_schema.tables
               WHERE  table_name   = '{table_name}'
               );""").fetchone()
        return result


def create_table(table_name, schema, pk='id'):
    schema = schema + f', PRIMARY KEY({id})'
    with engine.connect() as conn:
        conn.execute(
            f"""CREATE TABLE IF NOT EXISTS {table_name}( {schema},  PRIMARY KEY({pk})""")


def delete_table(table_name):
    with engine.connect() as conn:
        conn.execute(
            f"""DROP TABLE IF EXISTS {table_name}""")


def get_table_scheme(table_name) -> str:
    """Return table schema columns name: datatype"""
    """ Returns list of column name and its datatype """
    with engine.connect() as conn:
        schema = conn.execute(
            f"""SELECT column_name, data_type
                FROM information_schema.columns
                WHERE table_name = '{table_name}';""").fetchall()
    schema = [f'{col[0]} {col[1]}' for col in schema]
    schema = ', '.join(schema)
    return schema


# ****** Views ****


def create_mat_view(view_name, query):
    with engine.connect() as conn:
        conn.execute(
            f"CREATE MATERIALIZED VIEW if not exists {view_name} as {query}")


def mat_view_exists(view_name):
    with engine.connect() as conn:
        conn.execute(
            f"select exists(select from pg_matviews where matviewname = '{view_name}');")


def mat_view_update(view_name):
    with engine.connect() as conn:
        conn.execute(
            f"REFRESH MATERIALIZED VIEW {view_name}")


# ****** CONSPIRACY SPECIFIC QUERIES *************************************************
def iterable_to_sql_lower_array(hashtags):
    hashtags = [f"'{h.lower}'" for h in hashtags]
    array = ', '.join(hashtags)
    return f'({array})'


def get_tweets_to_df(columns: str, hashtags, chunksize, limit=None) -> Union[Iterator]:
    hashtags = iterable_to_sql_lower_array(hashtags)
    query_text = f"""
      select {columns} from 
        (select id from hashtags
          where LOWER(value) in {hashtags}) 
         as hashtags_filter
         inner join tweet_hashtags th on hashtags_filter.id = th.hashtag_id
         inner join tweets t on th.tweet_id = t.id"""

    if limit is not None:
        query_text = query_text + f' limit {limit}'

    return pd.read_sql_query(query_text, con=engine, chunksize=chunksize)


def df_to_table(df, table_name, if_exists):
    df.to_sql(table_name, con=engine, if_exists=if_exists)


def create_mat_view_from_tweets(view_name, hashtags: tuple):
    hashtags = iterable_to_sql_lower_array(hashtags)

    query = f"""select t.* from 
                (SELECT id from hashtags
                  where LOWER(valuer) in {hashtags} ) as hashtags_filter
                inner join tweet_hashtags th on hashtags_filter.id = th.hashtag_id
                inner join tweets t on th.tweet_id = t.id;"""

    with engine.connect() as conn:
        conn.execute(f"CREATE MATERIALIZED VIEW if not exists {view_name} as {query}")
