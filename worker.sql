\if :{?worker_sql}
\else
\set worker_sql true

\ir src/_worker/index.sql

\ir src/worker/index.sql

\if :test
    create function tests.echo_then(
        this jsonb,
        data jsonb,
        error jsonb default null
    )
        returns void
        language plpgsql
    as $$
    begin
        raise warning '----echo this %', this;
        raise warning '----echo data %', data;
        raise warning '----echo error %', error;
    end;
    $$;

    create function tests.test_worker() returns setof text language plpgsql as $$
    declare
        w jsonb;
        t jsonb;
        s jsonb;
        d jsonb;
        a jsonb;
    begin
        w = worker.web_register(jsonb_build_object(
            'name', 'worker-1',
            'commands', array['echo', 'then']
        ));
        -- raise warning '---register %', jsonb_pretty(w);
        return next ok(w['id'] is not null, 'register worker');

        t = worker.web_task(jsonb_build_object(
            'cmd', 'echo',
            'arg', jsonb_build_object('time', current_timestamp),
            'callback_fn', 'tests.echo_then',
            'context', '{"a":101}'::jsonb
        ));
        -- raise warning '---task %', jsonb_pretty(t);
        return next ok(t['id'] is not null, 'create a task');

        s = worker.web_start(jsonb_build_object(
            'worker_id', w['id'],
            'id', t['id']
        ));
        -- raise warning '---start %', jsonb_pretty(s);
        return next ok(t['started_tz'] is not null, 'start a task');

        d = worker.web_done(jsonb_build_object(
            'id', t['id'],
            'data', jsonb_build_object('hello', 'world')
        ));
        -- raise warning '---done %', jsonb_pretty(d);
        return next ok(t['done_tz'] is not null, 'complete a task');

        a = worker.web_checkout(jsonb_build_object(
            'id', w['id']
        ));
        -- raise warning '---checkout %', jsonb_pretty(a);
        return next ok(a['checkout_tz'] is not null, 'checkout');

    end;
    $$;

\endif

\endif