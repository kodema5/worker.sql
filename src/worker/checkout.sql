\if :{?worker_checkout_sql}
\else
\set worker_checkout_sql true

-- a worker checks-out temporarily

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

call util.export(util.web_fn_t('worker.checkout(worker.checkout_it)'));

\endif