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

connection = None
engine = None


def open_db_connection():
    config = configparser.ConfigParser()
    config.read('db.ini')
    postgres = config['POSTGRES']

    logging.debug('Opening DB connection')
    global connection
    global engine
    engine = sqlalchemy.create_engine(
        f"postgresql+psycopg2://{postgres['name']}:{postgres['password']}@{postgres['server']}:{postgres['port']}/{postgres['database']}", )

    connection = engine.connect()


def close_db_connection():
    logging.debug('Closing DB connection')
    global connection
    global connection

    connection.close()
    engine.dispose()


# ****** GENERAL QUERIES *************************************************

# ****** Column ****
def column_exists(column: str, table='tweets'):
    result = connection.execute(
        f"""SELECT column_name FROM information_schema.columns 
        WHERE table_name = '{table}' and column_name = '{column}'""").fetchone()
    return result is not None


def add_column(column, table='tweets', dt='bool'):
    connection.execute(f'ALTER TABLE {table} ADD COLUMN IF NOT EXISTS {column} {dt}')


def copy_column(column_name, src_table, dst_table, on='id'):
    connection.execute(
        f"""update {dst_table} as dst 
        set dst.{column_name} = src.{column_name} 
        from {src_table} as src where src.{on} = dst.{on}""")
    print(
        f"""update {dst_table} as dst 
                set dst.{column_name} = src.{column_name} 
                from {src_table} as src where src.{on} = dst.{on}""")


# ****** Table ****

def table_exists(table_name):
    result = connection.execute(
        f"""SELECT EXISTS (
           SELECT FROM information_schema.tables
           WHERE  table_name   = '{table_name}'
           );""").fetchone()
    return result


def create_table(table_name, schema, pk='id'):
    schema = schema + f', PRIMARY KEY({id})'
    connection.execute(
        f"""CREATE TABLE IF NOT EXISTS {table_name}( {schema},  PRIMARY KEY({pk})""")


def delete_table(table_name):
    connection.execute(
        f"""DROP TABLE IF EXISTS {table_name}""")


def get_table_scheme(table_name) -> str:
    """Return table schema columns name: datatype"""
    schema = connection.execute(
        f"""SELECT column_name, data_type
            FROM information_schema.columns
            WHERE table_name = '{table_name}';""").fetchall()
    schema = [f'{col[0]} {col[1]}' for col in schema]
    schema = ', '.join(schema)
    return schema


# ****** Views ****


def create_mat_view(view_name, query):
    connection.execute(
        f"CREATE MATERIALIZED VIEW if not exists {view_name} as {query}")


def mat_view_exists(view_name):
    return connection.execute(
        f"select exists(select from pg_matviews where matviewname = '{view_name}');").fetchone()


def mat_view_update(view_name):
    connection.execute(
        f"REFRESH MATERIALIZED VIEW {view_name}")


# ****** Others ****

def general_query(query, fetch='fetchone'):
    result = connection.execute(query)

    if fetch == 'fetchone':
        return result.fetchone()[0]
    elif fetch == 'fetchall':
        return result.fetchall()
    else:
        raise ValueError('Bad argument. Fetch can be "fetchone" or "fetchall"')


# ****** PANDAS QUERIES ************************************************************
def pandas_select(query):
    return pd.read_sql_query(query, con=engine)


def df_to_table(df, table_name, if_exists):
    df.to_sql(table_name, con=connection, if_exists=if_exists)


# ****** SPECIFIC QUERIES ***********************************************
def iterable_to_sql_lower_array(hashtags):
    hashtags = [f"'{h.lower()}'" for h in hashtags]
    array = ', '.join(hashtags)
    return f'({array})'


def get_all_tweets_to_df(columns: list, hashtags, chunksize, limit=None) -> Union[Iterator]:
    columns = ', '.join([f't.{c}' for c in columns])
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


def create_mat_view_from_tweets(view_name, hashtags: tuple):
    hashtags = iterable_to_sql_lower_array(hashtags)

    query = f"""select t.* from 
                (SELECT id from hashtags
                  where LOWER(value) in {hashtags} ) as hashtags_filter
                inner join tweet_hashtags th on hashtags_filter.id = th.hashtag_id
                inner join tweets t on th.tweet_id = t.id;"""

    connection.execute(f"CREATE MATERIALIZED VIEW if not exists {view_name} as {query}")


def get_extreme_teories_by_week(teories):
    query = """SELECT date_part('year', happened_at::date) as year,
           date_part('week', happened_at::date) AS weekly,
           COUNT(id), extreme_sentiment
            FROM {}
            GROUP BY year, weekly, extreme_sentiment
            ORDER BY year, weekly;"""

    all_df = [pandas_select(query.format(teory)).reset_index(drop=True) for teory in teories]
    for df, teory in zip(all_df, teories):
        df['teory'] = teory

    df = pd.concat(all_df)

    return df


def get_extreme_accounts(teory):
    query = """
    select ac.id, ac.name, ac.screen_name, count(ct.id) as tweet_count
    from (select id, author_id
          from {}
          where extreme_sentiment is true) as ct
             inner join accounts as ac on ct.author_id = ac.id
    group by ac.id, ac.name, ac.screen_name
    order by tweet_count DESC
    limit 10;"""

    return pandas_select(query.format(teory))


def get_extreme_hashtags(teory):
    query = f"""
    select count(ct.id) as count, ht.value as hashtag from {teory} as ct
    left join tweet_hashtags as th on th.tweet_id = ct.id
    left join hashtags as ht on ht.id = th.hashtag_id
    group by ht.value
    order by count DESC
    limit 10;"""

    return pandas_select(query.format(teory))
