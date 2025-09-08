require ecs
require ecs.common
require game.events.events_game
require danetlibs.dm.dm_events
require game.utils.team
require game.es.truce_common


[es(tag=server, on_appear, before=server_start_player_preparing)]
def create_initial_teams(evt : Event; am_teams__xenos, am_teams__encounter : string)
  //sync - to avoid issues with ids
  print("[TEAM] Created initial teams.")
  if !empty(am_teams__xenos)
    createEntitySync(am_teams__xenos) <| $(init)
      init |> set("team__id", 1)
  if !empty(am_teams__encounter)
    createEntitySync(am_teams__encounter) <| $(init)
      init |> set("team__id", 3)


//Regarding EventTeamMemberLeave:
//Do not remove player from team when disconnected because they may rejoin.
//We should not add new players into this team.
//The disconnected person should still occupy the spot


[es(on_disappear, tag=server, REQUIRE=player)]
def remove_player_from_team_on_destroyed(evt : Event; eid : EntityId; team : int)
  find_query() <| $ [es] (team__id : int; var team__memberEids : EidList)
    if team__id == team
      let idx = team__memberEids |> find_index(eid)
      if idx != -1
        team__memberEids |> erase(idx)
      return true
    return false


[es(tag=server, REQUIRE_NOT=victimDoesntBreakTruce)]
def break_truce_on_ff(evt : CmdApplyDamage;
                      eid : EntityId;
                      truce_id aka victim_truce_id : int)
  if evt.offender == eid || victim_truce_id == TRUCE_UNASSIGNED
    return
  query(evt.offender) <| $ [es] (truce_id aka offender_truce_id : int&)
    if offender_truce_id == TRUCE_UNASSIGNED || victim_truce_id == offender_truce_id
      return

    break_truce(victim_truce_id, offender_truce_id)


[es(tag=server, on_appear, REQUIRE=monstrified_human_conclude_truce_with_zone_on_appear)]
def monstrified_human_conclude_truce_with_zone_on_appear(evt : Event;
                                                         var truce_id : int&)
  if truce_id == TRUCE_UNASSIGNED
    truce_id = generate_truce_id()

  conclude_truce(truce_id, TRUCE_ZONE, true)


[es(tag=server, on_appear, REQUIRE=game_effect_conclude_truce_with_zone_on_appear)]
def game_effect_conclude_truce_with_zone_on_appear(evt : Event;
                                                   game_effect__attachedTo : EntityId)
  query(game_effect__attachedTo) <| $ [es] (var truce_id : int&)
    if truce_id == TRUCE_UNASSIGNED
      truce_id = generate_truce_id()

    conclude_truce(truce_id, TRUCE_ZONE, true)