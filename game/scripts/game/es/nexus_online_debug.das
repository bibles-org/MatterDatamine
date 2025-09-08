options no_aot

require ecs
require app
require strings
require game.events.events_active_matter
require game.es.net_console_macro
require game.utils.debug_bots


[net_console_cmd(name="bots.add")]
def nexus_add_bots_cmd(number : int = 2)
  broadcastEvent(CmdNexusAddBots(number = number))
