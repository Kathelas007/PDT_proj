#!/usr/bin/python

import pandas as pd
import seaborn as sns
from matplotlib import pyplot as plt
import pdfkit as pdk

import db


def set_ticks_density(tick_lables, density=10):
    for ind, label in enumerate(tick_lables):
        if ind % density == 0:
            label.set_visible(True)
        else:
            label.set_visible(False)


def multiple_cross_join(data: dict):
    all_df = [pd.DataFrame({name: column}) for name, column in data.items()]

    all_df_iter = iter(all_df)
    cross_df = next(all_df_iter)

    for df in all_df_iter:
        cross_df = cross_df.merge(df, how='cross')

    return cross_df


def extreme_ration_table(df: pd.DataFrame, ):
    df.loc[:, 'date'] = df.loc[:, 'date'].dt.date

    df = df[['normal', 'extreme', 'date']].groupby('date').sum().reset_index()
    df['tweet_count'] = df['normal'] + df['extreme']

    df.rename(columns={'normal': 'tweet_neutral_count', 'extreme': 'tweet_extreme_count', 'date': 'week'}, inplace=True)
    df.to_markdown('./doc/extreme_tweet_cnt.md')


def extreme_ration_plot(df: pd.DataFrame):
    cross_df = multiple_cross_join(
        {'teory': df['teory'].unique(), 'year': df['year'].unique(), 'week': [w for w in range(1, 53)]})

    df = cross_df.join(df.set_index(['teory', 'year', 'week']), on=['teory', 'year', 'week'], how='left').fillna(0)

    # extreme_cnt_per_week_df = df[['extreme', 'date']].groupby('date').sum().reset_index()
    # extreme_cnt_per_week_df.rename(columns={'extreme': 'extreme_week_sum'}, inplace=True)
    #
    # df = df.merge(extreme_cnt_per_week_df.set_index('date'), on='date', how='left')

    df['rate'] = 100 * df['extreme'] / df['extreme_week_sum']
    df.fillna(0, inplace=True)

    sns.set_style('darkgrid')

    fig = plt.figure()
    ax = fig.subplots()
    sns.lineplot(data=df, x='date', y='rate', hue='teory')
    # ax.set(ylabel="počet", xlabel='')
    ax.set_title('Poměr ??')
    ax.tick_params(axis='x', labelrotation=18)

    plt.show()
    plt.close()

    return 'a'


def extreme_ration(teories: list):
    df = db.get_extreme_teories_by_week(teories)

    df.rename({'weekly': 'week'}, axis=1, inplace=True)
    df = df.astype({'year': 'int32', 'week': 'int32', 'count': 'int32', 'extreme_sentiment': 'bool', 'teory': 'str'})

    df.sort_values(by=['year', 'week'], axis=0, inplace=True)

    df = df.pivot(index=['year', 'week', 'teory'], columns='extreme_sentiment', values='count')
    df.fillna(0, inplace=True)
    df = df.rename(columns={True: 'extreme', False: 'normal'}).astype({'extreme': 'int32', 'normal': 'int32'})
    df.reset_index(inplace=True)

    formatted_date = df['year'] * 1000 + df['week'] * 10 + 0
    df['date'] = pd.to_datetime(formatted_date, format='%Y%W%w')

    # extreme_ration_plot(df)
    extreme_ration_table(df)


def active_accounts(teories):
    tables = [f'    \n\n###{teory}   \n\n' + db.get_extreme_accounts(teory).set_index('id').to_markdown()
              for teory in teories]

    with open('./doc/extreme_accounts.md', 'w') as fd:
        fd.write('  \n'.join(tables))


def extreme_hashtags(teories):
    tables = [f'    \n\n###{teory}   \n\n' + db.get_extreme_hashtags(teory).set_index('hashtag').to_markdown()
              for teory in teories]

    with open('./doc/extreme_hashtags.md', 'w') as fd:
        fd.write('  \n'.join(tables))


def visualize(conspiracy_teories: dict):
    teories_only = [*conspiracy_teories.keys()]

    extreme_ration(teories_only)
    active_accounts(teories_only)
    extreme_hashtags(conspiracy_teories)
