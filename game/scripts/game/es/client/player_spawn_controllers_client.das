require app
require ecs
require net
require game.events.events_game
require game.events.player_events
require game.events.events_active_matter
require player
require replay
require game.es.client.postfx_fade_common
require game.events
require DngNet
require DagorSystem
require DagorMath
require game.es.client.player_spawn_controller_common

def player_spawn_controller_print_log(text)
  print("[Spawn Controller] {text}")


[es(tag=gameClient, on_appear)]
def player_spawn_controller_default_appear(evt : Event;
                                           player_spawn_controller_default__fadeInColor : E3DCOLOR)
  player_spawn_controller_print_log("appear")

  if !is_replay_playing()
    postfx_fade_immediate(float4(Color4(player_spawn_controller_default__fadeInColor)))


[es(tag=gameClient, REQUIRE=player)]
def player_spawn_controller_default_respawn_request(evt : PlayerRequestCustomRespawnInWorld;
                                                    is_local : bool;
                                                    clientNetFlags : int)
  if !is_local
    return

  player_spawn_controller_print_log("player_spawn_controller_default_respawn_request")
  find_query() <| $ [es] (var player_spawn_controller_default__state : int&)
    let isFirstSpawn = (clientNetFlags & int(ClientNetFlags.CNF_SPAWNED_AT_LEAST_ONCE)) == 0

    if isFirstSpawn
      player_spawn_controller_print_log("first spawn -> FADE")
      player_spawn_controller_default__state = int(PlayerSpawnControllerDefaultState.FADE)
    else
      player_spawn_controller_print_log("reconnect -> DONE")
      postfx_fadeout(0.5)
      send_net_event(get_local_player_eid(), PlayerRequestSpawnInWorld())
      player_spawn_controller_default__state = int(PlayerSpawnControllerDefaultState.DONE)

    return true


[es(tag=gameClient, track=player_spawn_controller_default__state)]
def player_spawn_controller_track_state(evt : Event;
                                        player_spawn_controller_default__state : int;
                                        player_spawn_controller_default__spawnDelay : float;
                                        player_spawn_controller_default__fadeInColorDefault : E3DCOLOR;
                                        var player_spawn_controller_default__spawnAt : float&)
  player_spawn_controller_print_log("state={player_spawn_controller_default__state}")

  if player_spawn_controller_default__state == int(PlayerSpawnControllerDefaultState.FADE)
    postfx_fade_start(float4(Color4(player_spawn_controller_default__fadeInColorDefault)), 0.7)
  elif player_spawn_controller_default__state == int(PlayerSpawnControllerDefaultState.REQUEST_REPLICATION)
    send_net_event(get_local_player_eid(), CmdPlayerSpawnRequestReplication())
  elif player_spawn_controller_default__state == int(PlayerSpawnControllerDefaultState.DELAY)
    // Wait for the phys actors replication
    player_spawn_controller_default__spawnAt = get_sync_time() + player_spawn_controller_default__spawnDelay


[es(tag=gameClient)]
def player_spawn_controller_fade_change_color_finished(evt : EventPostFxFadeFinished;
                                                       var player_spawn_controller_default__state : int&)
  if evt.layerNameHash != POSTFX_FADE_DEFAULT_LAYER
    return

  player_spawn_controller_print_log("player_spawn_controller_fade_change_color_finished, state={player_spawn_controller_default__state}")
  if player_spawn_controller_default__state == int(PlayerSpawnControllerDefaultState.FADE)
    player_spawn_controller_print_log("FADE -> REQUEST_REPLICATION")
    player_spawn_controller_default__state = int(PlayerSpawnControllerDefaultState.REQUEST_REPLICATION)


[es(tag=gameClient, REQUIRE=player)]
def player_spawn_controller_default_request_replication_response(evt : CmdPlayerSpawnRequestReplicationResponse;
                                                                 is_local : bool)
  if !is_local
    return

  player_spawn_controller_print_log("player_spawn_controller_default_request_replication_response")
  find_query() <| $ [es] (var player_spawn_controller_default__state : int&)
    if player_spawn_controller_default__state == int(PlayerSpawnControllerDefaultState.REQUEST_REPLICATION)
      player_spawn_controller_print_log("REQUEST_REPLICATION -> DELAY")
      player_spawn_controller_default__state = int(PlayerSpawnControllerDefaultState.DELAY)
    return true


[es(tag=gameClient, no_order)]
def player_spawn_controller_default_update(act : ParallelUpdateFrameDelayed;
                                           var player_spawn_controller_default__state : int&;
                                           var player_spawn_controller_default__spawnAt : float&;
                                           var player_spawn_controller_default__spawnFramesLeft : int&)
  if player_spawn_controller_default__state == int(PlayerSpawnControllerDefaultState.DELAY)
    if player_spawn_controller_default__spawnAt > 0.0 && act.curTime >= player_spawn_controller_default__spawnAt
      // Delay by timer and by frames count is still very unreliable.
      // Perhaps we can find out in some other way that
      // the replication of phys actors has completed?
      if player_spawn_controller_default__spawnFramesLeft-- > 0
        return

      player_spawn_controller_default__spawnAt = 0.0

      player_spawn_controller_print_log("player_spawn_controller_default_update finished -> DONE")
      send_net_event(get_local_player_eid(), PlayerRequestSpawnInWorld())
      player_spawn_controller_default__state = int(PlayerSpawnControllerDefaultState.DONE)