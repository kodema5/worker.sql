\if :{?worker_worker_sql}
\else
\set worker_worker_sql true

-- selects a worker for a task
--

create function worker.worker (
    t _worker.task
)
    returns _worker.worker
    language sql
    security definer
as $$
    select *
    from _worker.worker
    where t.cmd = any(commands)
    and checkin_tz is not null
$$;

\endif