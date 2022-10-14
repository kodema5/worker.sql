\if :{?worker_assign_sql}
\else
\set worker_assign_sql true

-- assign tasks
-- todo:
-- order of priority


\ir worker.sql

create procedure  worker.assign ()
    language plpgsql
    security definer
as $$
declare
    t _worker.task;
    w _worker.worker;
begin
    for t in (
        select *
        from _worker.task
        where worker_id is null -- unassigned
        or ( -- not started
            current_timestamp + '5s'::interval > assigned_tz
            and started_tz is null
        )
    ) loop
        w = worker.worker(t);
        if w.id is not null then

            update _worker.task
            set worker_id = w.id,
                assigned_tz = current_timestamp
            where id = t.id;

            perform pg_notify(
                w.channel_id,
                to_jsonb(t)::text
            );
        end if;
    end loop;
end;
$$;

\endif