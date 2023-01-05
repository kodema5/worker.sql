// deno run -A --unstable --watch worker.js

import { config } from "https://deno.land/x/dotenv/mod.ts"
import { parse } from "https://deno.land/std@0.134.0/flags/mod.ts";

let ConfigFlags = {
    p: 'PORT',
    debug: 'PGDEBUG',
    n: 'NAME',
}

let Config = Object.assign(
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
let sql = postgres({
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

let Cmd = {}

let Worker = {}

let clear = (obj) => {
    for (let key in obj) {
        delete obj[key];
    }
    return obj
}

let checkin = Cmd.checkin = async () => {
    try {
        console.log('> checkin', new Date())
        let d = {
            id: Worker.id,
        }
        let s = `select worker.web_checkin('${
            JSON.stringify(d)
        }'::jsonb) as x`

        let r = (await sql.unsafe(s))?.[0]?.x
        if (!r || !r.id) {
            console.log('> unable to checkin, re-registering')
            await register()
        }
    } catch(_) {
        console.log('> unable to checkin, re-registering')
        await register()
    }
}

let register = Cmd.register = async () => {
    console.log('> register', Config.NAME)
    console.log('> register', Object.keys(Cmd))
    if (Worker.listener) {
        await Worker.listener.unlisten()
    }
    if (Worker.checkinInt) {
        clearInterval(Worker.checkinInt)
        delete Worker.checkinInt
    }

    try {
        let d = {
            name: Config.NAME,
            commands: Object.keys(Cmd).sort(),
        }
        let s = `select worker.web_register('${
            JSON.stringify(d)
        }'::jsonb) as x`

        Object.assign(clear(Worker), (await sql.unsafe(s))?.[0]?.x || {})



    } catch(e) {
        console.log('> register error', e.message)
        console.log('> will retry.')

        setTimeout(() => {
            register()
        }, 15000)
        return
    }

    console.log(`> listening to ${Worker.channel_id}`)

    Worker.listener = await sql.listen(Worker.channel_id, work)

    try {
        checkin()
    } catch(e) {
        console.log('> checkin error', e.message)
    }
    if (Worker.checkin_int) {
        Worker.checkinInt = setInterval(() => {
            try {
                checkin()
            } catch(e) {
                console.log('> checkin error', e.message)
            }
        }, Worker.checkin_int)
    }
}

let work = async (p) => {
    let { cmd, id, arg } = JSON.parse(p)
    let fn = Cmd[cmd]
    if (!fn) {
        console.log(`-- unrecognized cmd: ${cmd}`)
        return
    }

    if (!id) {
        await fn(arg)
        return
    }

    try {
        let s = `select worker.web_start('${
            JSON.stringify({id, worker_id:Worker.id})
        }'::jsonb) as x`
        await sql.unsafe(s)

    } catch(err) {
        console.log(`-- ${cmd} start error: ${err.message}`)
        return
    }

    let data, error
    try {
        data = await fn(arg)
    } catch(err) {
        error = err.message
        console.log(`-- ${cmd} work error: ${error}`)
    }

    try {
        let s = `select worker.web_done('${
            JSON.stringify({id, data, error})
        }'::jsonb) as x`
        await sql.unsafe(s)
    } catch(err) {
        console.log(`-- ${cmd} done error: ${err.message}`)

    }
}


let shutdown = Cmd.shutdown = async () => {
    console.log('> shutting down')
    if (Worker.checkinInt) {
        clearInterval(Worker.checkinInt)
    }

    try {
        let s = `select worker.web_checkout('${
            JSON.stringify({id: Worker.id})
        }'::jsonb) as x`
        await sql.unsafe(s)

    } catch(err) {
        console.log(`-- checkout: ${err.message}`)
    }

    await sql.end({timeout: 5})
}


import { ajax as ajax_ } from 'https://raw.githubusercontent.com/kodema5/ajax.js/main/mod.js'

let ajax = Cmd.ajax = async (arg) => {
    console.log('-- ajax', arg)
    return await ajax_(arg)
}

let echo = Cmd.echo = async (arg) => {
    console.log('> echo', arg)
    return Object.assign({echo:true}, arg)
}

register()