\if :{?worker_register_sql}
\else
\set worker_register_sql true

-- registers a new worker
-- todo:
-- add initial statistics

create type worker.register_it as (
    name  text,
    commands text[]
);

create function worker.register(
    req worker.register_it
)
    returns _worker.worker
    language plpgsql
    security definer
as $$
declare
    w _worker.worker;
begin
    insert into _worker.worker (
        name,
        commands
    )
    values (
        req.name,
        req.commands
    )
    on conflict (name) do update
    set
        commands = excluded.commands
    returning * into w;

    update _worker.worker
        set
            channel_id = 'worker_' || w.id,
            -- automatically checks-in
            checkin_tz = current_timestamp
        where id = w.id
        returning * into w;

    return w;
end;
$$;

create function worker.register(
    req jsonb
)
    returns _worker.worker
    language sql
    security definer
as $$
    select worker.register(
        jsonb_populate_record(
            null::worker.register_it,
            req))
$$;

create function worker.web_register(
    req jsonb
)
    returns jsonb
    language sql
    security definer
as $$
    select to_jsonb(worker.register(req))
$$;

\endif