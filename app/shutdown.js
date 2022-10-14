import { Worker, } from './register.js'
import { Cmd, sql} from './lib.js'

export let shutdown = async () => {
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

Cmd.shutdown = shutdown