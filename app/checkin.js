
import { Worker, register, } from './register.js'
import { Cmd, sql } from './lib.js'

export let checkin = async () => {
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

Cmd.checkin = checkin