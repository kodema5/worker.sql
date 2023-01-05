\if :{?worker_checkin_sql}
\else
\set worker_checkin_sql true

-- a worker checks-in if any task
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

call util.export(util.web_fn_t('worker.checkin(worker.checkin_it)'));

\endif