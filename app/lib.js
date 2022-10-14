import { config } from "https://deno.land/x/dotenv/mod.ts"
import { parse } from "https://deno.land/std@0.134.0/flags/mod.ts";

let ConfigFlags = {
    p: 'PORT',
    debug: 'PGDEBUG',
    n: 'NAME',
}

export let Config = Object.assign(
    // application default values
    //
    {
        NAME: new URL('', import.meta.url).pathname + '-' + Deno.pid,
        PORT: 8080,             // listens to

        PGHOST: 'localhost',    // pg connections
        PGPORT: 5432,
        PGDATABASE: 'web',
        PGUSER: 'web',
        PGPASSWORD: 'rei',
        PGPOOLSIZE: 10,
        PGIDLE_TIMEOUT: 0,      // in s
        PGCONNECT_TIMEOUT: 30,  // in s
    },

    // read from .env / .env.defaults
    //
    config(),

    // command line arguments
    //
    Object.entries(parse(Deno.args))
        .map( ([k,v]) => ({
            [ConfigFlags[k] || k.toUpperCase().replaceAll('-','_')] : v
        }))
        .reduce((x,a) => Object.assign(x,a), {})
)


import postgres from 'https://deno.land/x/postgresjs/mod.js'
export let sql = postgres({
    host: Config.PGHOST,
    port: Config.PGPORT,
    user: Config.PGUSER,
    pass: Config.PGPASSWORD,
    database: Config.PGDATABASE,

    max: Config.PGPOOLSIZE,
    idle_timeout: Config.PGIDLE_TIMEOUT,
    connect_timeout: Config.PGCONNECT_TIMEOUT,

    onnotice: (msg) => console.log(msg.severity, msg.message),
})

export let Cmd = {}