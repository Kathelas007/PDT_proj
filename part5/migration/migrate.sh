bulk_size=60000
import_size=0
create_json=false
global_offset=0
query_file="tweets_to_json.sql"
tmp_query_file=${query_file}".tmp"

help() {
  echo "Importer from PostgresSQL to ElasticSearch"
  echo "	-h		help"
  echo "	-s=import_size number of rows imported"
  echo "	-b=bulk_size	size of bulks that will be imported, default 1000000"
  echo "  -o=offset star import from offset number"
  echo "	-j		do not import directly, but create backup json file"
}

prepare_for_import() {
  # load postgres passwords
  source pg_password || true

  # create indexes
  psql -U kate -h spodlesny.eu -p 54320 -d pdt2021_tweets -f ./create_indexes.sql
}

set_limit_offset() {
  cat $query_file | sed "s/limitnumber/${1}/g" | sed "s/offsetnumber/${2}/g" >${tmp_query_file}
}

migrate() {
  if [[ $import_size -eq 0 ]]; then
    import_size=31976050
  fi

  max_limit=$(($import_size - 1))
  for i in $(seq $global_offset $bulk_size $max_limit); do
    echo "${i}, $bulk_size, $max_limit"
    set_limit_offset $bulk_size $i

    if [ "$create_json" = true ]; then
      sample_json="tweets_sample_${bulk_size}_${i}.json"

      if [ ! -f "$sample_json" ]; then
        psql -U kate -h spodlesny.eu -p 54320 -d pdt2021_tweets -f ${tmp_query_file} | sed 's/\\\\/\\/g' | ./split_json.py >${sample_json} && printf "*** Json file ${sample_json} created.\n"
      fi

      curl -H 'Content-Type: application/x-ndjson' -XPOST 'localhost:9200/_bulk' --data-binary @${sample_json}
      printf "\n\n*** Json ${i} imported\n"

    else
      psql -U kate -h spodlesny.eu -p 54320 -d pdt2021_tweets -f ${tmp_query_file} | sed 's/\\\\/\\/g' | ./split_json.py | curl -H 'Content-Type: application/x-ndjson' -XPOST 'localhost:9200/_bulk' --data-binary @-
      printf "\n*** Rows ${i} - $(($i + $bulk_size - 1)) imported\n\n"
    fi

  done

}

## ******************** MAIN *************************

while getopts "hs:b:o:j" flag; do
  case "${flag}" in
  h | \?) help ;;
  s) import_size=${OPTARG} ;;
  b) bulk_size=${OPTARG} ;;
  o) global_offset=${OPTARG} ;;
  j) create_json=true ;;
  esac
done

prepare_for_import

# run migration
migrate
