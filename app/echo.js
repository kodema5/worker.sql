import { Cmd } from './lib.js'

export let echo = async (arg) => {
    console.log('> echo', arg)
    return Object.assign({echo:true}, arg)
}
Cmd.echo = echo