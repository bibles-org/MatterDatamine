require app
require ecs
require ecs.common
require DngNet
require player
require game.events.events
require game.events.events_game
require game.events.events_active_matter
require game.es.level_common
require game.es.nexus_common
require game.es.level_common


def are_all_players_from_one_team(player_list : EidList)
  if empty(player_list)
    return true

  let team = get_int(player_list[0], "team") ?? TEAM_UNASSIGNED
  for i in range(1, length(player_list))
    if get_int(player_list[i], "team") ?? TEAM_UNASSIGNED != team
      return false
  return true


[es(tag=server, on_appear)]
def nexus_game_controller_on_appear(evt : Event;
                                    var nexus_game_controller__spawnController : EntityId&)
  find_query() <| $ [es(REQUIRE=nexus_spawn_controller)] (eid : EntityId)
    nexus_game_controller__spawnController = eid
    return true


[es(tag=server, REQUIRE=nexus_spawn_controller, on_appear)]
def nexus_game_controller_on_spawn_controller_appear(evt : Event;
                                                     eid : EntityId)
  find_query() <| $ [es] (var nexus_game_controller__spawnController : EntityId&)
    nexus_game_controller__spawnController = eid
    return true


[es(tag=server, before=player_team_selection_in_raid, on_event=EventOnPlayerConnected, REQUIRE=nexus_player)]
def nexus_battle_assign_team(evt : Event;
                             eid aka player_eid : EntityId;
                             groupId aka player_groupId : int64;
                             var team : int&)
  if team != TEAM_UNASSIGNED
    return

  if !is_nexus_mode()
    return

  var groupTeam = TEAM_UNASSIGNED
  let hasGroupmates = find_query() <| $ [es] (team : int; groupId aka other_groupId : int64; eid aka other_eid : EntityId)
    if other_groupId == player_groupId && other_eid != player_eid
      groupTeam = team
      return true
    return false

  if hasGroupmates
    team = groupTeam
    return

  var teams <- { int(NexusTeam.FIRST) => 0, int(NexusTeam.SECOND) => 0 }
  query() <| $ [es(REQUIRE=player)] (eid aka other_player_eid : EntityId; team aka other_player_team : int)
    if other_player_eid == player_eid || other_player_team == TEAM_UNASSIGNED
      return
    get(teams, other_player_team) <| $(var count : int&)
      count += 1
  if teams.get_value(int(NexusTeam.FIRST)) > teams.get_value(int(NexusTeam.SECOND))
    team = int(NexusTeam.SECOND)
  else
    team = int(NexusTeam.FIRST)


[es(tag=server, after=player_team_selection_in_raid, on_event=EventOnPlayerConnected, REQUIRE=nexus_player)]
def nexus_battle_allow_replication_on_connect(evt : Event;
                                              eid : EntityId;
                                              var clientNetFlags : int&)
  clientNetFlags |= int(ClientNetFlags.CNF_REPLICATE_PHYS_ACTORS)
  sendEventImmediate(eid, CmdAddDefaultEntitiesInNetScopeForPlayer())


[es(tag=gameClient, on_appear)]
def nexus_show_effect_on_militant_appear(evt : Event;
                                         transform : float3x4;
                                         nexus_militant__onAppearEffect : string;
                                         teleportation__fxOffset : float3 = float3(0.0))
  createEntity(nexus_militant__onAppearEffect) <| $(init)
    var tm = transform
    tm[3] = tm * teleportation__fxOffset
    set(init, "transform", tm)
