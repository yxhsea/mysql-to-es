select id, name, create_time, update_time from goods where update_time > :sql_last_value
