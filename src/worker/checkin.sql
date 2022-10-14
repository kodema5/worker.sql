\if :{?worker_checkin_sql}
\else
\set worker_checkin_sql true

-- a worker checks-in
-- future:
-- worker to pass statistics for worker-selection

\ir assign.sql

-- "register" automatically checks in
-- if to add stats, may need to update "register" too
--
create type worker.checkin_it as (
    id  text
);

create function worker.checkin(
    req worker.checkin_it
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
            checkin_tz = current_timestamp,
            checkout_tz = null
        where id = req.id
        returning *
        into w;

    call worker.assign();

    return w;
end;
$$;

create function worker.checkin(
    req jsonb
)
    returns _worker.worker
    language sql
    security definer
as $$
    select worker.checkin(
        jsonb_populate_record(
            null::worker.checkin_it,
            req))
$$;

create function worker.web_checkin(
    req jsonb
)
    returns jsonb
    language sql
    security definer
as $$
    select to_jsonb(worker.checkin(req))
$$;

\endif