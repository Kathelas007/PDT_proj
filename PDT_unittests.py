import unittest

from main import remove_ignored_from_contend as ric
from main import get_all_conspiracy_hashtags as sh


class RIC(unittest.TestCase):

    def test_retweet(self):
        self.assertEqual(ric("RT @EdehAlexi: So suddenly the same ..."),
                         ': So suddenly the same ...')
        self.assertEqual(ric("ROBERT @EdehAlexi: So suddenly the same ..."),
                         'ROBERT : So suddenly the same ...')

    def test_mention(self):
        self.assertEqual(ric("this@nop, this @yes"), 'this@nop, this ')
        self.assertEqual(ric("name@gmail.com"), 'name@gmail.com')

    def test_username(self):
        self.assertEqual(ric("too @long_user_name_to_be_valid_as_user_name_by_twitter_account"),
                         'too @long_user_name_to_be_valid_as_user_name_by_twitter_account')
        self.assertEqual(ric("name@gmail.com"), 'name@gmail.com')

    def test_emoji(self):
        self.assertEqual(ric("smajlik 😁"), 'smajlik')
        self.assertEqual(ric('twitter new emoji 😶‍🌫️ ❤️‍🩹'), 'twitter new emoji  ')

    def test_ht(self):
        self.assertEqual(ric("my #ht "), 'my  ')


class CH(unittest.TestCase):
    def test_lower(self):
        self.assertEqual(sh({'a': ('A', 'b')}), ('a', 'b'))

    def test_str_tuple(self):
        self.assertEqual(sh({'a': ('t', 'T'), 'str': ('str',)}), ('a', 'b', 'str'))


if __name__ == '__main__':
    unittest.main()
