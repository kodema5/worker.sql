\if :test
\if :local
drop schema if exists _worker cascade;
\endif
\endif
create schema if not exists _worker;

create table if not exists _worker.worker (
    id text
        default md5(uuid_generate_v4()::text)
        primary key,
    name text unique not null,
    checkin_int int default 5000,
    channel_id text,
    commands text[],

    checkin_tz timestamp with time zone,
    checkout_tz timestamp with time zone
);

create table if not exists _worker.task (
    id text
        default md5(uuid_generate_v4()::text)
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
