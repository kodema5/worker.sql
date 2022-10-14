import { checkin, } from './checkin.js'
import { Cmd, Config, sql } from './lib.js'
import { work } from './work.js'

export let Worker = {}

let clear = (obj) => {
    for (let key in obj) {
        delete obj[key];
    }
    return obj
}

export let register = async () => {
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

        setTimeout(() => {
            register()
        }, 15000)
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

Cmd.register = register