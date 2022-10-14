import { Worker, } from './register.js'
import { Cmd, sql } from './lib.js'

export let work = async (p) => {
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