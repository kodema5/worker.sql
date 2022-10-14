import { Cmd } from './lib.js'
import { ajax as ajax_ } from 'https://raw.githubusercontent.com/kodema5/ajax.js/main/mod.js'

export let ajax = async (arg) => {
    console.log('-- ajax', arg)
    return await ajax_(arg)
}
Cmd.ajax = ajax