-- psql -U web -d web -f examples.sql

drop schema if exists examples cascade;
create schema examples;

create table examples.http_bin_post (
    context jsonb,
    data jsonb
);

create function examples.http_bin_post (
    context_ jsonb,
    data_ jsonb,
    error_ jsonb default null
)
    returns boolean
    language plpgsql
as $$
begin
    insert into examples.http_bin_post (context, data) values (context_, data_);
    return true;
end;
$$;



-- select pg_sleep(20.0);
do $$
declare
    t jsonb;
begin
    begin
    t = worker.web_task(jsonb_build_object(
        'cmd', 'ajax',
        'arg', jsonb_build_object(
            'url', 'https://httpbin.org/post',
            'data', jsonb_build_object(
                'hello', 'ajax'
            )
        ),
        'callback_fn', 'examples.http_bin_post',
        'context', jsonb_build_object('test', 1)
    ));
    end;
    raise warning '---- we got %', t;
end;
$$;

select pg_sleep(2);

select * from examples.http_bin_post;
