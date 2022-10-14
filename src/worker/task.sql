\if :{?worker_task_sql}
\else
\set worker_task_sql true

-- server creates a new task

\ir assign.sql

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

create function worker.task(
    req jsonb
)
    returns _worker.task
    language sql
    security definer
as $$
    select worker.task(
        jsonb_populate_record(
            null::worker.task_it,
            req))
$$;

create function worker.web_task(
    req jsonb
)
    returns jsonb
    language sql
    security definer
as $$
    select to_jsonb(worker.task(req))
$$;

\endif