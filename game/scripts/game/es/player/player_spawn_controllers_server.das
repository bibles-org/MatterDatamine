require app
require ecs
require net
require DngNet
require game.events.events_game
require game.events.player_events
require DagorSystem
require game.events.events_active_matter


def player_spawn_controller_print_log(text)
  print("[Spawn Controller] {text}")


def is_player_spawn_controller_default_exists()
  return find_query() <| $ [es(REQUIRE=player_spawn_controller_default)] () => true


[es(tag=server, REQUIRE=player)]
def player_spawn_controller_default_request_replication(evt : CmdPlayerSpawnRequestReplication;
                                                        eid : EntityId;
                                                        var clientNetFlags : int&)
  if !is_player_spawn_controller_default_exists()
    player_spawn_controller_print_log("eid={eid} clientNetFlags={clientNetFlags} player_spawn_controller_default does not exists - nothing to do")
    return

  player_spawn_controller_print_log("eid={eid} clientNetFlags={clientNetFlags} adding player to net scope")
  clientNetFlags |= int(ClientNetFlags.CNF_REPLICATE_PHYS_ACTORS)
  sendEventImmediate(eid, CmdAddDefaultEntitiesInNetScopeForPlayer())

  send_net_event(eid, CmdPlayerSpawnRequestReplicationResponse())