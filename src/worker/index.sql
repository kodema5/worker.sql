drop schema if exists worker cascade;
create schema worker;

\ir assign.sql
\ir register.sql
\ir checkin.sql
\ir checkout.sql
\ir worker.sql
\ir task.sql
\ir callback.sql
\ir done.sql
\ir start.sql
\ir wait.sql

create function worker.echo (
    this jsonb default null,
    data jsonb default null
)
    returns void
    language plpgsql
as $$
begin
    raise warning '> worker.echo this: %', jsonb_pretty(this);
    raise warning '> worker.echo data: %', jsonb_pretty(data);
end;
$$;
