# load postgres passwords
source pg_password | true

# create indexes
psql -U kate -h spodlesny.eu  -p 54320 -d pdt2021_tweets -f  ./create_indexes.sql

# run migration

psql -U kate -h spodlesny.eu  -p 54320 -d pdt2021_tweets -f ./accounts_to_json.sql | sed 's/\\\\/\\/g' |  mongoimport --uri mongodb://10.119.0.6:27017/pdt2021_tweets -c accounts --drop --type json ;
echo "accounts json imported"

psql -U kate -h spodlesny.eu  -p 54320 -d pdt2021_tweets -f ./tweets_to_json.sql | sed 's/\\\\/\\/g'  | mongoimport --uri mongodb://10.119.0.6:27017/pdt2021_tweets -c tweets  --drop --type json ;
echo "tweets json imported";
