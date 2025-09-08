require app
require ecs
require DngNet
require DagorSystem
require DagorDataBlock
require game.utils.team
require game.es.level_common
require game.events.player_events
require game.events.events_game
require game.events.events
require game.es.player.player_connect_common


[es(REQUIRE=player)]
def player_connected_save_times(evt : EventOnPlayerConnected;
                                var connectedAtTime : float&;
                                var startedAtTime : float&)
  if !evt.reconnected
    startedAtTime = get_sync_time()
  connectedAtTime = get_sync_time()
