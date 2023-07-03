#!/usr/bin/env python3

import sys
import json
import time

if __name__ == '__main__':
    for line in sys.stdin:
        data = json.loads(line)
        id_val = data.pop('_id', None)
        metadata = '{"index" : {"_index":"pdt2021_tweets","_id":"' + id_val + '"}}'
        print(metadata)
        print(json.dumps(data))