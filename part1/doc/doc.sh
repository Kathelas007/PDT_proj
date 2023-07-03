#!/usr/bin/env bash

doc='doc.md'
rm -rf $doc || true

echo -e "# PDT tweets analysis - part 1  \n\n" > $doc
echo -e "* repo link: [github class](https://github.com/FIIT-DBS/zadanie-pdt-Kathelas007)  " >> $doc
echo -e "* author: Kateřina Mušková  " >> $doc

echo -e "\n  \n\n## Task 4  \n\n" >> $doc
echo -e "![](../img/tweet_plot.jpg)  \n" >> $doc
cat ./extreme_tweet_cnt.md >> $doc 

echo -e "\n  \n\n## Task 5  \n\n" >> $doc
cat ./extreme_accounts.md >> $doc 

echo -e "\n  \n\n## Task 6  \n\n" >> $doc
cat ./extreme_hashtags.md >> $doc