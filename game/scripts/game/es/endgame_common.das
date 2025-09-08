module endgame_common shared
require ecs
require app
require ecs.safe
require net
require game.events.events_active_matter
require active_matter.game.es.objectives.objective_common
require DngNet
require strings
require ecs.safe
require rapidjson
require DagorMath
require jsonwriter
require DagorBase64
require game.utils.team
require game.utils.net_utils
require game.es.item_equip_common
require game.es.message_queue_common
require game.events.events_active_matter
require game.es.chronotrace_progress_track_common
require game.es.human_self_resurrection_device_common
require active_matter.game.es.objectives.objective_common


// sync with dagor\active_matter\profileServer\structures\profile.das
struct BattleAreaInfo
  raidName : string
  scene : string


struct BattleResultAction
  session_id : string
  contractsProgression : array<ContractProgression>
  loadout : array<BattleResultItem>
  AMResource : int
  isSuccessRaid : bool
  isRentedEquipment : bool
  battleStats : table<string; float>
  newUnlocks : array<string>
  trackPointsV2 : string
  contractsVisuals : string
  teamInfo : string
  dateTime : uint64
  debriefingStats : table<string; int>
  battleAreaInfo : BattleAreaInfo
  chronotracesProgression : table<string; table<string; int>>


def send_player_endgame_result(team_id : int; player_eid : EntityId; allow_spectate : bool; game_end_reson : int; auto_exit : bool)
  print("[Send player endgame result] player {player_eid} from team {team_id} game_end_reason {game_end_reson}")
  send_net_event(
    player_eid,
    EventEndgamePlayerResult(allowSpectate = allow_spectate, reason = game_end_reson, team = team_id, autoExit = auto_exit),
    target_entity_conn(player_eid)
  )


def send_team_endgame_result(team_id : int; member_eids : EidList; allow_spectate : bool; game_end_reson : int; auto_exit : bool)
  for memberEid in member_eids
    send_player_endgame_result(team_id, memberEid, allow_spectate, game_end_reson, auto_exit)


def private pack_float3(var data : JsonWriter; name : string; value : float3)
  data |> jw_key_obj(name) <| $()
    data |> jw_key_value("x", value.x)
    data |> jw_key_value("y", value.y)
    data |> jw_key_value("z", value.z)


def private pack_int2(var data : JsonWriter; name : string; value : int2)
  data |> jw_key_obj(name) <| $()
    data |> jw_key_value("x", value.x)
    data |> jw_key_value("y", value.y)


def write_map_object_zone(object_eid : EntityId;
                          id : string;
                          name : string;
                          contractType : int;
                          is_secret : bool;
                          var data : JsonWriter)
  query(object_eid) <| $ [es] (transform : float3x4; map_object_zone__radius : float)
    data |> jw_start_obj()
    data |> jw_key_value("objectiveId", id)
    data |> jw_key_value("objectiveName", name)
    data |> jw_key_value("isSecretObjective", is_secret)
    data |> jw_key_value("radius", map_object_zone__radius)
    data |> jw_key_value("contractType", contractType)
    data |> pack_float3("position", transform[3])
    data |> jw_end_obj()

  query(object_eid) <| $ [es] (transform : float3x4;
                               map_object_marker__iconName : string;
                               map_object_marker__tooltip : string = "";
                               map_object_marker__activeColor : float3 const?;
                               map_object_marker__hoverColor : float3 const?;
                               map_object_marker__inactiveColor : float3 const?;
                               map_object_marker__clampToBorder : bool const?)
    data |> jw_start_obj()
    data |> jw_key_value("objectiveId", id)
    data |> jw_key_value("objectiveName", name)
    data |> jw_key_value("contractType", contractType)
    data |> jw_key_value("isSecretObjective", is_secret)
    data |> jw_key_value("iconName", map_object_marker__iconName)
    data |> pack_float3("position", transform[3])
    if map_object_marker__tooltip != ""
      data |> jw_key_value("tooltip", map_object_marker__tooltip)
    if map_object_marker__activeColor != null
      data |> pack_float3("activeColor", *map_object_marker__activeColor)
    if map_object_marker__hoverColor != null
      data |> pack_float3("hoverColor", *map_object_marker__hoverColor)
    if map_object_marker__inactiveColor != null
      data |> pack_float3("inactiveColor", *map_object_marker__inactiveColor)
    if map_object_marker__clampToBorder != null
      data |> jw_key_value("clampToBorder", *map_object_marker__clampToBorder)
    data |> jw_end_obj()


def get_battle_area_info() : BattleAreaInfo
  var result : BattleAreaInfo
  result.scene = get_current_scene()
  query() <| $ [es] (level__raidName : string)
    result.raidName = level__raidName
  return <- result


def get_debriefing_stats(player_eid : EntityId) : table<string; int>
  var result : table<string; int>
  query(player_eid) <| $ [es] (scoring_player__medicineUsed : int;
                               scoring_player__lootedSecretContainers : int;
                               scoring_player__lootedBodies : int;
                               scoring_player__lootedCommonContainers : int;
                               scoring_player__receivedDamage : float;
                               scoring_player__dealtDamage : float;
                               scoring_player__playerPathLen : float;
                               scoring_player__playTime : float2)
    result |> insert("medicineUsed", scoring_player__medicineUsed)
    result |> insert("lootedSecretContainers", scoring_player__lootedSecretContainers)
    result |> insert("lootedBodies", scoring_player__lootedBodies)
    result |> insert("lootedCommonContainers", scoring_player__lootedCommonContainers)
    result |> insert("receivedDamage", ceili(scoring_player__receivedDamage))
    result |> insert("dealtDamage", ceili(scoring_player__dealtDamage))
    result |> insert("playerPathLen", ceili(scoring_player__playerPathLen))
    result |> insert("playTime", ceili(scoring_player__playTime.x))
  return <- result


def fill_teammate_info(var team_info : JsonWriter; teammate_eid : EntityId)
  query(teammate_eid) <| $ [es] (name : string;
                                 initialHeroItems : Array;
                                 userid : uint64;
                                 player_ribbons__curColors : int2)
    team_info |> jw_start_obj()
    team_info |> jw_key_value("id", string(userid))
    team_info |> jw_key_value("name", name)
    team_info |> pack_int2("ribbonColors", player_ribbons__curColors)

    for item in initialHeroItems
      let slotName = (item as Object)?.slotName ?? ""
      if slotName != "equipment_chronogene_primary_1"
        continue

      let templateName = (item as Object)?.templateName ?? ""
      team_info |> jw_key_value("suitTemplate", templateName)
      break
    team_info |> jw_end_obj()


def get_player_battle_result_data(player_eid : EntityId;
                                  scoring_player__isExtractedSuccess, player__isRentedEquipment : bool;
                                  player__stats : Object;
                                  saved_am : int;
                                  currentHeroItems : Array;
                                  player_move_tracker__trackPoints : Array;
                                  var chronotraces_progression : Object) : BattleResultAction
  var result : BattleResultAction
  result.session_id = string(get_session_id())
  result.isSuccessRaid = scoring_player__isExtractedSuccess
  result.isRentedEquipment = player__isRentedEquipment
  result.battleAreaInfo <- get_battle_area_info()
  result.contractsProgression <- get_objectives_for_save(scoring_player__isExtractedSuccess, player_eid)
  result.AMResource = saved_am
  result.dateTime = json_get_or(get_matching_invite_data(), "startTimestamp", 1000ul)
  query(player_eid) <| $ [es] (player__newUnlocks : StringList)
    for newUnlock in player__newUnlocks
      result.newUnlocks |> push(string(newUnlock))

  var loadout : array<BattleResultItem>
  for item in currentHeroItems
    let itemObj = get_ecs_object(item)
    if itemObj == null
      continue

    let templateName = (*itemObj).templateName ?? ""
    if templateName |> ends_with("_chronogene_passive") || templateName == "passive_chronogenes_stash"
      continue

    let preparedItem = BattleResultItem(
      itemId = int(uint((*itemObj).itemId ?? INVALID_ENTITY_ID)),
      parentItemId = int(uint((*itemObj).parentItemId ?? INVALID_ENTITY_ID)),
      slotName = (*itemObj).slotName ?? "",
      templateName = templateName,
      charges = (*itemObj).charges ?? 0,
      isCorrupted = (*itemObj).isCorrupted ?? false,
      isReplica = (*itemObj).isReplica ?? false,
      isCreatedByZone = (*itemObj).isCreatedByZone ?? false,
      isFoundInRaid = (*itemObj).isFoundInRaid ?? false,
      ownerNickname = (*itemObj).ownerNickname ?? "",
      killerNickname = (*itemObj).killerNickname ?? "",
      killedByWeapon = (*itemObj).killedByWeapon ?? "",
      deathReason = (*itemObj).deathReason ?? ""
    )
    loadout |> push(preparedItem)

    if preparedItem.isCreatedByZone && !empty(preparedItem.templateName)
      item_add_progress(chronotraces_progression, preparedItem.templateName, "extract")

  result.loadout <- loadout

  var chronotracesProgression : table<string; table<string; int>>
  for progressionsEntry in chronotraces_progression
    var tab : table<string; int>
    let progressionsData = get_ecs_object(progressionsEntry.value)
    if progressionsData == null
      continue
    for incomeProgression in (*progressionsData)
      let value = incomeProgression.value ?? 0
      if value > 0
        tab |> insert(incomeProgression.key, value)
    chronotracesProgression[progressionsEntry.key] <- tab

  result.chronotracesProgression <- chronotracesProgression

  var statsToSafe : table<string; float>
  for stat in player__stats
    statsToSafe |> insert(stat.key, float(get_int(stat.value) ?? 0))
  result.battleStats <- statsToSafe

  result.debriefingStats <- get_debriefing_stats(player_eid)

  jw_writer() <| $(var trackPointsData : JsonWriter)
    trackPointsData |> jw_start_array()
    for trackPoint in player_move_tracker__trackPoints
      let trackPointObj = get_ecs_object(trackPoint)
      if trackPointObj == null
        continue
      trackPointsData |> jw_start_obj()
      trackPointsData |> jw_key_value("eventType", trackPointObj?.eventType ?? "unknown")
      trackPointsData |> jw_key_value("timestamp", trackPointObj?.timestamp ?? 0.0)
      let position = trackPointObj?.position ?? float3(0.0)
      trackPointsData |> jw_key_obj("position") <| $()
        trackPointsData |> jw_key_value("x", position.x)
        trackPointsData |> jw_key_value("y", position.y)
        trackPointsData |> jw_key_value("z", position.z)
      let victimPosition = trackPointObj?.victimPosition
      let name = trackPointObj?.name
      if name != null // either killer of the player or someone killed by the player
        trackPointsData |> jw_key_value("name", name ?? "unknown")
      if victimPosition != null
        trackPointsData |> jw_key_value("victimType", trackPointObj?.victimType ?? "unknown")
        let victimPositionData = victimPosition ?? float3(0.0)
        trackPointsData |> jw_key_obj("victimPosition") <| $()
          trackPointsData |> jw_key_value("x", victimPositionData.x)
          trackPointsData |> jw_key_value("y", victimPositionData.y)
          trackPointsData |> jw_key_value("z", victimPositionData.z)
      trackPointsData |> jw_end_obj()
    trackPointsData |> jw_end_array()
    result.trackPointsV2 = encode_base64(trackPointsData.result)

  jw_writer() <| $(var contractsVisualsData : JsonWriter)
    contractsVisualsData |> jw_start_array()
    query() <| $ [es] (objective__playerEid : EntityId;
                       objective__id : string;
                       objective__name : string;
                       objective__contractType : int;
                       secretObjective : Tag const?;
                       objective__staticTargetsList : EidList)
      if objective__playerEid != player_eid
        return
      let isSecret = secretObjective != null

      for targetEid in objective__staticTargetsList
        write_map_object_zone(targetEid, objective__id, objective__name, objective__contractType, isSecret, contractsVisualsData)
    contractsVisualsData |> jw_end_array()
    result.contractsVisuals = encode_base64(contractsVisualsData.result)

  jw_writer() <| $(var playerTeamData : JsonWriter)
    playerTeamData |> jw_start_array()
    query(player_eid) <| $ [es] (team : int)
      for_each_teammate_player(player_eid, team) <| $(teammate_eid)
        fill_teammate_info(playerTeamData, teammate_eid)
      fill_teammate_info(playerTeamData, player_eid)
    playerTeamData |> jw_end_array()
    result.teamInfo = encode_base64(playerTeamData.result)

  return <- result


def is_any_teammate_playing(player : EntityId; player_team : int)
  return find_query() <| $ [es] (eid, possessed : EntityId;
                                 team : int;
                                 player__isFinishedRaid : bool;
                                 scoring_player__firstSpawnTime : float)
    if team != player_team || player == eid || player__isFinishedRaid
      return false

    if scoring_player__firstSpawnTime < 0.0
      print("[EndgameResult] player {player} from team {team} has unloaded teammate")
      return true
    else
      var heroAlive = false
      query(possessed) <| $ [es] (isAlive : bool)
        heroAlive = isAlive
      if heroAlive
        return true
      return find_player_ressurection_device(eid) != INVALID_ENTITY_ID


// if this function is called, player cannot continue raid!
def player_finish_raid(player_eid : EntityId; player_team : int; is_extracted : bool)
  var finishedAlready = false
  query(player_eid) <| $ [es] (var player__isFinishedRaid : bool&)
    finishedAlready = player__isFinishedRaid
    player__isFinishedRaid = true

  if finishedAlready
    return

  if !is_extracted
    query(player_eid) <| $ [es] (var currentHeroAM : int&;
                                 var currentHeroItems : Array)
      currentHeroAM = 0
      currentHeroItems |> clear()

  query(player_eid) <| $ [es(REQUIRE_NOT=active_matter_player_test__index)] (userid : uint64;
                                                                             scoring_player__isExtractedSuccess, player__isRentedEquipment : bool;
                                                                             player__stats : Object;
                                                                             currentHeroAM : int;
                                                                             currentHeroItems : Array;
                                                                             player_move_tracker__trackPoints : Array;
                                                                             var player__chronotracesProgression : Object)
    let data <- get_player_battle_result_data(player_eid,
                                              scoring_player__isExtractedSuccess,
                                              player__isRentedEquipment,
                                              player__stats,
                                              currentHeroAM,
                                              currentHeroItems,
                                              player_move_tracker__trackPoints,
                                              player__chronotracesProgression)
    print("[BATTLE RESULT] {data}")
    if !is_true_net_server()
      jw_writer() <| $(var battle_result : JsonWriter)
        battle_result |> jw_value(data)
        broadcastEvent(EventPlayerFinishedOfflineRaid(data = battle_result.result))

    elif has_network()
      sendToProfileServer("apply_battle_result", userid, data)

  for_each_teammate_player(player_eid, player_team) <| $(teammate)
    sendEvent(teammate, EventTeammateFinishedRaid())

  send_net_event(player_eid, EventPlayerFinishedRaid())
