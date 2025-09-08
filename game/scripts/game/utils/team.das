module team shared
require ecs
require ecs.common
require app
require player public
require game.es.truce_common
require daslib/strings_boost


def is_hostile(truce_controller__masks : UInt64List;
               actor_team : int;
               actor_truce : int;
               actor_personal_enemies;
               target_eid : EntityId;
               target_team : int;
               target_truce : int)
  if is_personal_enemy(actor_personal_enemies, target_eid)
    return true

  let isTeamsFriendly = is_teams_friendly(actor_team, target_team)
  let hasTruce = has_truce(truce_controller__masks, actor_truce, target_truce)

  return !isTeamsFriendly && !hasTruce


def is_hostile(actor_team : int;
               actor_truce : int;
               actor_personal_enemies;
               target_eid : EntityId;
               target_team : int;
               target_truce : int)
  var result = true

  find_query() <| $ [es] (truce_controller__masks : UInt64List)
    result = is_hostile(truce_controller__masks, actor_team, actor_truce, actor_personal_enemies, target_eid, target_team, target_truce)
    return true

  return result


def is_teams_friendly(lhs, rhs : int)
  return lhs == rhs && lhs != TEAM_UNASSIGNED


def is_player_team(team_id : int)
  var result = false

  find_query() <| $ [es] (team__id : int;
                          player_team : Tag const?)
    if team_id != team__id
      return false

    result = (player_team != null)
    return true

  return result


def is_actor_teams_friendly(lhs, rhs : EntityId)
  var result = false
  query(lhs) <| $ [es] (team aka lhs_team : int)
    query(rhs) <| $ [es] (team aka rhs_team : int)
      result = is_teams_friendly(lhs_team, rhs_team)
  return result


def get_player_team(player_eid : EntityId)
  return get_int(player_eid, "team") ?? TEAM_UNASSIGNED


def get_local_player_team()
  return get_player_team(get_local_player_eid())


def have_active_teammates(owner_eid : EntityId; our_team : int; include_bots = false)
  return find_query() <| $ [es(REQUIRE=human)] (eid : EntityId;
                                                team : int;
                                                countAsAlive, isAlive, isDowned : bool;
                                                beh_tree__enabled = false;
                                                isSpectatable = true)
    return (
         eid != owner_eid
      && countAsAlive && isAlive && isSpectatable
      && !isDowned
      && is_teams_friendly(team, our_team)
      && (include_bots ? true : !beh_tree__enabled)
    )


def find_max_team_id()
  var maxTeamTid : int = 0
  query() <| $ [es] (team__id : int)
    maxTeamTid = max(maxTeamTid, team__id)
  return maxTeamTid


def create_new_raid_team(team_template : string; wish_spawn_place_id : int; spawnbase_eid = INVALID_ENTITY_ID)
  let teamTid = find_max_team_id() + 1
  // sync creation, because used immediately and team__id must be immediately visible
  let teamEid = createEntitySync(team_template) <| $(init)
    init |> set("team__id", teamTid)
    init |> set("team__spawnPlaceId", wish_spawn_place_id)
    init |> set("team__spawnBaseEid", spawnbase_eid)
  print("[TEAM] Created new team with id: <{teamTid}>, eid: <{teamEid}>, spawnPlaceId <{wish_spawn_place_id}>, spawnbase <{spawnbase_eid}>.")
  return teamEid


def create_new_base_team(team_template : string)
  let teamTid = find_max_team_id() + 1
  // sync creation, because used immediately and team__id must be immediately visible
  let teamEid = createEntitySync(team_template) <| $(init)
    init |> set("team__id", teamTid)
  print("[TEAM] Created new team with id: <{teamTid}>, eid: <{teamEid}>")
  return teamEid


def create_new_bot_team(spawnbase_eid : EntityId; spawn_group_id : int) : int
  var result = TEAM_UNASSIGNED
  find_query() <| $ [es] (am_teams__bots : string)
    let teamEid = create_new_raid_team(am_teams__bots, spawn_group_id, spawnbase_eid)
    query(teamEid) <| $ [es] (team__id : int)
      result = team__id
    return true
  return result


def for_each_teammate_player(player : EntityId; player_team : int; cb : block<(teammate : EntityId) : void>)
  find_query() <| $ [es] (team__id : int; team__memberEids : EidList)
    if team__id != player_team
      return false
    for member in team__memberEids
      if member != player
        invoke(cb, member)

    return true


def is_personal_enemy(personal_enemies__enemies : EidList;
                      target_eid : EntityId)
  return personal_enemies__enemies |> find_index(target_eid) >= 0


def is_personal_enemy(personal_enemies__enemies : EidList const?;
                      target_eid : EntityId)
  if personal_enemies__enemies == null
    return false

  return is_personal_enemy(*personal_enemies__enemies, target_eid)


def is_personal_enemy(actor_eid : EntityId;
                      target_eid : EntityId)
  var result = false
  query(actor_eid) <| $ [es] (personal_enemies__enemies : EidList)
    result = is_personal_enemy(personal_enemies__enemies, target_eid)
  return result


def add_personal_enemy(var personal_enemies__enemies : EidList;
                       target_eid : EntityId)
  if !is_personal_enemy(personal_enemies__enemies, target_eid)
    personal_enemies__enemies |> push(target_eid)
