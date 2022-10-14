\if :{?worker_callback_sql}
\else
\set worker_callback_sql true

-- execute callback of a completed task

create procedure  worker.callback (
    t _worker.task
)
    language plpgsql
    security definer
as $$
begin
    if t.done_tz is null then
        raise exception 'worker.callback.yet_done';
    end if;

    if t.callback_fn is null then
        return;
    end if;

    execute format(
        'select %s(%L::jsonb, %L::jsonb, %L::jsonb)',
        t.callback_fn,
        '{}'::jsonb,

        t.data, t.error
    );

    update _worker.task
    set called_back_tz = clock_timestamp()
    where id = t.id;

exception
    when others then
        raise warning 'worker.callback.error %', sqlerrm;
        null;
end;
$$;

\endif