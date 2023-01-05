\if :{?worker_done_sql}
\else
\set worker_done_sql true

-- called when worker complete a task

\ir callback.sql

create type worker.done_it as (
    id  text,
    data jsonb,
    error jsonb
);

create type worker.done_t as (
    status text
);

create function worker.done(
    req worker.done_it
)
    returns _worker.task
    language plpgsql
    security definer
as $$
declare
    r worker.done_t;
    t _worker.task;
    f regproc;
begin

    update _worker.task set
        done_tz = current_timestamp,
        data = req.data,
        error = req.error
    where id = req.id
    and started_tz is not null
    returning * into t;

    if t is null then
        raise exception 'worker.done unable to find task';
    end if;

    call worker.callback(t);

    return t;
end;
$$;

call util.export(util.web_fn_t('worker.done(worker.done_it)'));

\endif