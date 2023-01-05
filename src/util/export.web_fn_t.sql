\if :{?util_export_web_fn_t_sql}
\else
\set util_export_web_fn_t_sql true

create schema if not exists util;

-- to craete a schema.web_fun(type_it(jsonb)) web-api
--
drop type if exists util.web_fn_t cascade;
create type util.web_fn_t as (
    sch text,
    fun text,
    args text[],
    arg_f text, -- if req should be passed through a func ex: auth.auth
    prefix text
);

create or replace function util.web_fn_t (
    p oid,
    arg_f text default current_setting('app.default_auth_function', 't'),
    prefix text default 'web_'
)
    returns util.web_fn_t
    language sql
    security definer
    stable
as $$
    select (
        ns.nspname,
        pr.proname,
        (
            select array_agg(trim(t))
            from unnest(string_to_array((oidvectortypes(proargtypes)), ',')) t
        ),
        arg_f,
        prefix
    )::util.web_fn_t
    from pg_catalog.pg_proc pr
    join pg_catalog.pg_namespace ns on ns.oid = pr.pronamespace
    where pr.oid = p::oid;
$$;

create or replace function util.web_fn_t (
    p text,
    arg_f text default current_setting('app.default_auth_function', 't'),
    prefix text default 'web_'
)
    returns util.web_fn_t
    language sql
    security definer
    stable
as $$
    select util.web_fn_t(p::regprocedure::oid, arg_f, prefix)
$$;

create or replace procedure util.export (
    it util.web_fn_t
)
    language plpgsql
    security definer
as $$
declare
    src text;
    arg text;
    arg_f_text text;
begin
    if cardinality(it.args) <> 1
    then
        raise warning 'util.export: % has >1 argument', it.sch || '.' || it.fun;
    end if;

    if it.arg_f is not null then
        arg_f_text = format('%s(req)', it.arg_f);
    else
        -- raise warning '%', format('util.export arg_f is empty for %s(jsonb)', it.args[1]);
        arg_f_text = 'req';
    end if;

    -- check if argument
    declare
        a regprocedure;
    begin
        a = (it.args[1] || '(jsonb)')::regprocedure;
        arg = format('%s(%s)', it.args[1], arg_f_text);
    exception
    when others then
        -- raise warning '%', format('util.export %s(jsonb) not found; using default jsonb_populate_record', it.args[1]);
        arg = format( 'jsonb_populate_record(null::%s, %s)', it.args[1], arg_f_text);
    end;

    src = format(
        'create or replace function %I.%I(req jsonb) '
        'returns jsonb '
        'language sql '
        'security definer '
        'as $web_fn$ '
            'select to_jsonb(%I.%I(%s)) '
        '$web_fn$',
    it.sch,
    it.prefix || it.fun,
    it.sch,
    it.fun,
    arg);

    execute src;
end;
$$;

create or replace procedure util.export (
    fns util.web_fn_t[]
)
    language plpgsql
    security definer
as $$
declare
    fn util.web_fn_t;
begin
    foreach fn in array fns
    loop
        call util.export(fn);
    end loop;
end;
$$;

\endif
