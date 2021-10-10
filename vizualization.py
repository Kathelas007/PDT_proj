#!/usr/bin/python

import pandas as pd
import seaborn as sns
from matplotlib import pyplot as plt
import pdfkit as pdk

import db


def multiple_cross_join(data: dict):
    """Merges multiple pandas dataframes by crossjoin"""
    all_df = [pd.DataFrame({name: column}) for name, column in data.items()]

    all_df_iter = iter(all_df)
    cross_df = next(all_df_iter)

    for df in all_df_iter:
        cross_df = cross_df.merge(df, how='cross')

    return cross_df


def extreme_ration_table(df: pd.DataFrame):
    """
    Task number 4 - table
    Get table of extreme, neutral and total count of conspiracy theories for every.
    """
    formatted_date = df['year'] * 1000 + df['week'] * 10 + 0
    df['date'] = pd.to_datetime(formatted_date, format='%Y%W%w')

    df.loc[:, 'date'] = df.loc[:, 'date'].dt.date

    df = df[['normal', 'extreme', 'date']].groupby('date').sum().reset_index()
    df['tweet_count'] = df['normal'] + df['extreme']

    df.rename(columns={'normal': 'tweet_neutral_count', 'extreme': 'tweet_extreme_count', 'date': 'week'}, inplace=True)
    df.to_markdown('./doc/extreme_tweet_cnt.md')


def extreme_ration_plot(df: pd.DataFrame, teories: list):
    """
    Task number 4 - plot
    Plot extreme / normal ration of conspiraci theories by week
    """

    # fill empty dates
    cross_df = multiple_cross_join(
        {'teory': df['teory'].unique(), 'year': df['year'].unique(), 'week': [w for w in range(1, 53)]})
    df = df.join(cross_df.set_index(['teory', 'year', 'week']), on=['teory', 'year', 'week'], how='right').fillna(0)

    # add formatted date
    formatted_date = df['year'] * 1000 + df['week'] * 10 + 0
    df['date'] = pd.to_datetime(formatted_date, format='%Y%W%w')
    df = df.sort_values(['year', 'week'])

    # extreme cnt
    extreme_cnt_per_week_df = df[['extreme', 'date']].groupby('date').sum().reset_index()
    extreme_cnt_per_week_df.rename(columns={'extreme': 'extreme_week_sum'}, inplace=True)
    df = df.merge(extreme_cnt_per_week_df.set_index('date'), on='date', how='left')

    # total cnt
    df['total'] = df['extreme'] + df['normal']

    # extreme rate
    df['rate'] = 100 * df['extreme'] / df['total']
    df.fillna(0, inplace=True)

    # filter relevant date
    min_date = df.sort_values(['date']).loc[df['total'] > 0, 'date'].iloc[0]
    max_date = df.sort_values(['date'], ascending=False).loc[df['total'] > 0, 'date'].iloc[0]
    df = df.loc[(df['date'] >= min_date) & (df['date'] <= max_date)]

    sns.set_style('darkgrid')

    fig, axes = plt.subplots(2, 1, figsize=(8.27, 11.69))
    fig.suptitle("Conpiracy tweets", fontsize=14, fontweight='bold')
    axes = axes.flatten()

    # plot total extreme count
    sns.lineplot(data=df, x='date', y='extreme', hue='teory', ax=axes[0])
    axes[0].set_title('Count of tweets with extreme sentiment by theory')
    axes[0].set_yscale("log")

    # plot rate
    sns.lineplot(data=df, x='date', y='rate', hue='teory', ax=axes[1])
    axes[1].set_title('Extreme / neutral sentiment rate by theory')
    axes[1].set_yscale("log")
    axes[1].legend([])

    plt.show()
    plt.close()

    return 'a'


def extreme_ration(teories: list):
    """ Task number 4 """
    df = db.get_extreme_teories_by_week(teories)

    df.rename({'weekly': 'week'}, axis=1, inplace=True)
    df = df.astype({'year': 'int32', 'week': 'int32', 'count': 'int32', 'extreme_sentiment': 'bool', 'teory': 'str'})

    df.sort_values(by=['year', 'week'], axis=0, inplace=True)

    df = df.pivot(index=['year', 'week', 'teory'], columns='extreme_sentiment', values='count')
    df.fillna(0, inplace=True)
    df = df.rename(columns={True: 'extreme', False: 'normal'}).astype({'extreme': 'int32', 'normal': 'int32'})
    df.reset_index(inplace=True)

    extreme_ration_plot(df, teories)
    extreme_ration_table(df)


def active_accounts(teories):
    """ Task number 5 """

    tables = [f'    \n\n###{teory}   \n\n' + db.get_extreme_accounts(teory).set_index('id').to_markdown()
              for teory in teories]

    with open('./doc/extreme_accounts.md', 'w') as fd:
        fd.write('  \n'.join(tables))


def extreme_hashtags(teories):
    """ Task number 6 """

    tables = [f'    \n\n###{teory}   \n\n' + db.get_extreme_hashtags(teory).set_index('hashtag').to_markdown()
              for teory in teories]

    with open('./doc/extreme_hashtags.md', 'w') as fd:
        fd.write('  \n'.join(tables))


def visualize(conspiracy_teories: dict):
    teories_only = [*conspiracy_teories.keys()]

    extreme_ration(teories_only)
    # active_accounts(teories_only)
    # extreme_hashtags(conspiracy_teories)
