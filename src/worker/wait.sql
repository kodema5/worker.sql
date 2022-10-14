\if :{?worker_wait_sql}
\else
\set worker_wait_sql true

create function worker.wait(
    task_id text,
    timeout double precision default 0.01
)
    returns _worker.task
    language plpgsql security definer
as $$
declare
    t _worker.task;
    n int = 0;
    sleep_int double precision = 0.01; -- (per doc, 0.01 is typical sleep interval)
    max_n int = timeout / sleep_int;
begin
    -- raise warning '--- worker.wait %', task_id;
    loop
        select * into t
        from _worker.task
        where id=task_id
        and done_tz is not null;

        if t is not null then
            return t;
        end if;

        n = n + 1;
        if n>max_n then
            raise exception 'worker.wait.timeout';
        end if;

        perform pg_sleep(sleep_int);
    end loop;
end;
$$;

create function worker.wait(
    t _worker.task,
    timeout double precision default 0.01
)
    returns _worker.task
    language sql security definer
as $$
    select worker.wait(t.id, timeout)
$$;

\endif