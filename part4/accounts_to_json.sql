copy (
    select row_to_json(a.*)
    from (select accounts.*
          from accounts
        inner join extreme_tweets et on et.author_id = accounts.id
        ) as a)
    TO STDOUT with (FORMAT text, HEADER FALSE);
