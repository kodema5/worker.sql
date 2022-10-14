\if :{?worker_start_sql}
\else
\set worker_start_sql true

-- called when worker start a task

create type worker.start_it as (
    id  text,
    worker_id text
);

create function worker.start (
    it worker.start_it
)
    returns _worker.task
    language plpgsql
    security definer
as $$
declare
    t _worker.task;
begin
    update _worker.task
        set started_tz = current_timestamp
    where id = it.id
    and worker_id = it.worker_id
    returning * into t;

    if t is null then
        raise exception 'worker.start.invalid_task';
    end if;
    return t;
end;
$$;

create function worker.start(
    req jsonb
)
    returns _worker.task
    language sql
    security definer
as $$
    select worker.start(
        jsonb_populate_record(
            null::worker.start_it,
            req))
$$;

create function worker.web_start(
    req jsonb
)
    returns jsonb
    language sql
    security definer
as $$
    select to_jsonb(worker.start(req))
$$;

\endif
