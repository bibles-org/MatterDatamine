require ecs
require DngNet
require game.utils.team
require game.events.events_game
require game.es.item_equip_common
require game.events.events_active_matter
require game.es.equipment_generator_common
require game.es.level_common


def clear_resbases(team : int)
  let playerTeam = team
  query() <| $ [es(REQUIRE=respbase)] (var team : int&)
    if team == playerTeam
      team = TEAM_UNASSIGNED


[es(tag=server, REQUIRE=playerIsBot, after=raid_player_extracted)]
def bot_player_extracted(evt : CmdExtractFromBattlefieldServer; eid : EntityId; team : int)
  clear_resbases(team)
  destroyEntity(eid)


[es(tag=server, REQUIRE=playerIsBot, after=raid_player_killed)]
def bot_player_killed(evt : EventEntityDied; possessedByPlr : EntityId; team : int)
  clear_resbases(team)
  destroyEntity(possessedByPlr) //TODO wait for ragdoll to die


[es(tag=server, REQUIRE=bot_squad_leader, on_appear)]
def bot_make_self_squad_leader(evt : Event; eid aka this_eid : EntityId; team aka this_team : int)
  query() <| $ [es(REQUIRE=bot_squad_leader, REQUIRE_NOT=deadEntity)] (team : int; eid : EntityId)
    if team != this_team || eid == this_eid
      return

    removeSubTemplate(eid, "bot_squad_leader")


[es(tag=server, REQUIRE=bot_squad_leader, on_event=EventEntityDied, on_disappear)]
def bot_pass_leadership_to_teammate(evt : Event; eid aka this_eid : EntityId; team aka this_team : int)
  removeSubTemplate(eid, "bot_squad_leader")

  let hasAnotherLeader = find_query() <| $ [es(REQUIRE=bot_squad_leader, REQUIRE_NOT=deadEntity)] (team : int; eid : EntityId)
    if team != this_team || eid == this_eid
      return false
    return true

  if hasAnotherLeader
    return

  find_query() <| $ [es(REQUIRE_NOT=deadEntity, REQUIRE=am_militant)] (team : int; eid : EntityId)
    if team != this_team || eid == this_eid
      return false

    addSubTemplate(eid, "bot_squad_leader")
    return true


[es(tag=server, on_appear)]
def give_bot_initial_equip(evt : Event;
                           eid : EntityId;
                           equipped_bot__equipmentGeneratorName : string;
                           equipped_bot__equipmentGeneratorCorruptionChance : float;
                           human_inventory__maxVolume : float)
  let loadItemsBlk = $ <| (equipment : Array)
    load_items(equipment, eid)
  var seed = int(get_session_id() + uint64(uint(eid)))
  generate_loadout(
    equipped_bot__equipmentGeneratorName,
    equipped_bot__equipmentGeneratorCorruptionChance,
    human_inventory__maxVolume,
    true /*is_fill_inventories*/,
    seed,
    loadItemsBlk)
