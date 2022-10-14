\if :{?worker_checkout_sql}
\else
\set worker_checkout_sql true

-- a worker checks-out

\ir assign.sql

create type worker.checkout_it as (
    id  text
);

create function worker.checkout(
    req worker.checkout_it
)
    returns _worker.worker
    language plpgsql
    security definer
as $$
declare
    w _worker.worker;
begin
    update _worker.worker
        set
            checkout_tz = current_timestamp,
            checkin_tz = null
        where id = req.id
        returning *
        into w;

    call worker.assign();

    return w;
end;
$$;

create function worker.checkout(
    req jsonb
)
    returns _worker.worker
    language sql
    security definer
as $$
    select worker.checkout(
        jsonb_populate_record(
            null::worker.checkout_it,
            req))
$$;

create function worker.web_checkout(
    req jsonb
)
    returns jsonb
    language sql
    security definer
as $$
    select to_jsonb(worker.checkout(req))
$$;

\endif