\if :{?worker_sql}
\else
\set worker_sql true

-- tracks pg's listeners for tasks

\ir util/export.web_fn_t.sql

\if :test
\if :local
drop schema if exists _worker cascade;
\endif
\endif
create schema if not exists _worker;
drop schema if exists worker cascade;
create schema if not exists worker;

-- workers
--
create table if not exists _worker.worker (
    id text
        default md5(gen_random_uuid()::text)
        primary key,
    name text unique not null,
    checkin_int int default 5000, -- in ms

    channel_id text,
    commands text[],

    checkin_tz timestamp with time zone,
    checkout_tz timestamp with time zone
);

-- registers a worker
--
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
    insert into _worker.worker (name, commands)
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
            checkin_tz = current_timestamp -- automatically checks-in
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
    select worker.register(jsonb_populate_record(null::worker.register_it, req))
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


-- tasks
--
create table if not exists _worker.task (
    id text
        default md5(gen_random_uuid()::text)
        primary key,
    created_tz timestamp with time zone default current_timestamp,
    cmd text,
    arg jsonb default null,

    assigned_tz timestamp with time zone,
    worker_id text,
    started_tz timestamp with time zone,


    done_tz timestamp with time zone,
    data jsonb default null,
    error jsonb default null,

    callback_fn regproc,
    context jsonb default '{}'::jsonb,
    called_back_tz timestamp with time zone

);


-- selects a worker based on task
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


-- assign work
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
        if w.id is not null
        then
            update _worker.task
            set worker_id = w.id,
                assigned_tz = current_timestamp
            where id = t.id;

            -- notify worker of task
            perform pg_notify(
                w.channel_id,
                to_jsonb(t)::text
            );
        end if;
    end loop;
end;
$$;


-- creates a new task
--
create type worker.task_it as (
    cmd text,
    arg jsonb,
    callback_fn regproc,
    context jsonb
);

create function worker.task (
    it worker.task_it
)
    returns _worker.task
    language plpgsql
    security definer
as $$
declare
    t _worker.task;
begin
    insert into _worker.task (
        cmd, arg,
        callback_fn, context
    )
    values (
        it.cmd, it.arg,
        it.callback_fn, it.context
    )
    returning * into t;

    call worker.assign();

    select * into t
    from _worker.task
    where id = t.id;

    return t;
end;
$$;

call util.export(util.web_fn_t('worker.task(worker.task_it)'));


\ir worker/checkin.sql
\ir worker/checkout.sql
\ir worker/callback.sql
\ir worker/done.sql
\ir worker/start.sql
\ir worker/wait.sql

\endif
