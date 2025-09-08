require ecs
require ecs.safe
require ecs.common
require app
require Grid
require DagorMath
require matching
require math.random
require math.base
require DagorSystem
require DagorRandom
require DngNet
require rapidjson
require game.es.app_common
require game.es.player_profile_common
require game.events.events_game
require game.utils.spawn_base
require game.utils.team
require game.es.level_common
require game.es.item_equip_common
require ecs.soa_template


def spawn_bot_hero(hero_template : string;
                   team_id : int;
                   squad_size : int;
                   base_eid : EntityId)
  var tm = get_TMatrix(base_eid, "transform") ?? IDENT_TM
  orthonormalize(tm)

  var templ = getTemplateByName(hero_template)
  if templ == null
    templ = buildTemplateByName(hero_template)
  if templ != null
    createEntity(hero_template) <| $(var init : ComponentsInitializer)
      init |> set("transform", tm)
      init |> set("team", team_id)

  mark_respawn_base(team_id, base_eid, squad_size)


[es(tag=server, on_appear, REQUIRE=am_militant_bot)]
def raid_bot_player_create(evt : Event;
                           eid : EntityId;
                           var possessedByPlr : EntityId&;
                           team : int)
  query() <| $ [es] (bot_spawner__playerTemplate : string)
    find_query() <| $ [es] (bot_spawner__generatedNames : StringList; var bot_names__nextNameId : int&)
      bot_names__nextNameId++
      if bot_names__nextNameId >= length(bot_spawner__generatedNames)
        bot_names__nextNameId = 0
        logerr("Not enough bot names. Reseting names cursor to zero.")
      let plr_eid = createEntity(bot_spawner__playerTemplate) <| $(var init : ComponentsInitializer)
        init |> set("possessed", eid)
        init |> set("connid", INVALID_CONNECTION_ID)
        init |> set("name", bot_spawner__generatedNames[bot_names__nextNameId])
        init |> set("userid", INVALID_USER_ID)
        init |> set("team", team)
      possessedByPlr = plr_eid
      broadcastEvent(EventTeamMemberJoined(eid = plr_eid, team = team))
      return true


[es(tag=server, on_appear, REQUIRE=playerIsBot)]
def raid_bot_player_set_possessed_template(evt : Event; possessed : EntityId; var possessedTemplate : das_string&)
  if !is_raid_mode()
    return

  var templateName = add_sub_template_name(getEntityTemplateName(possessed), "bot_squad_leader")
  templateName = remove_sub_template_name(templateName, "equipped_bot+equipped_bot_female+initial_loadout_creation")
  possessedTemplate := templateName


[es(tag=server, on_event=EventComponentsDisappear, REQUIRE=(am_militant_bot, initial_loadout_creation))]
def raid_bot_player_set_permanent_items(evt : Event; eid : EntityId; possessedByPlr : EntityId)
  query(possessedByPlr) <| $ [es] (var initialHeroItems : Array)
    if !empty(initialHeroItems)
      return
    save_player_items(initialHeroItems, eid)

    let itemsLen = initialHeroItems |> length()
    for i in range(itemsLen)
      let idx = (itemsLen - 1)  - i
      var itemObj = getRW_ecs_object(initialHeroItems[idx])
      if itemObj != null
        let templateName = (*itemObj).templateName ?? ""
        let itemTemplate = getOrBuildTemplateByName(templateName)
        if itemTemplate != null && templateHasComponent(*itemTemplate, "item__permanentItem")
          continue
      initialHeroItems |> erase(idx)


[soa_template]
struct TeamSpawnInfo
  bot_spawner__teamName : string
  bot_spawner__teamMaxGroups : int
  bot_spawner__teamJipEndAt : float
  bot_spawner__teamBotsPerGroupMinMax : int2
  bot_spawner__teamSpawnGroupId : int
  bot_spawner__teamLastSpawnedAt : float


def private parse_float_from_json(json; name; default_value_float : float; default_value_int : int) : float
  var result = json_get_or(json, name, default_value_float)
  if result == default_value_float
    result = float(json_get_or(json, name, default_value_int))
  return result


[soa_es, es(tag=server, on_event=EventLevelLoaded)]
def raid_bot_spawner_per_team_init(evt : Event;
                                   eid aka spawner_eid : EntityId;
                                   bot_spawner__botsPerGroupMinMax : int2;
                                   bot_spawner__allowedTeams : IntList;
                                   var bot_spawner__spawnAt : float&;
                                   var teamSpawnInfo : TeamSpawnInfo_SOA)
  let curTime = get_sync_time()

  var totalMaxSquads = 0
  var firstSpawnAt = FLT_MAX
  let globalJipSetting = parse_float_from_json(get_matching_invite_data(), "jipEnableTime", -1.0, -1)

  print("[BOT SPAWNER][{spawner_eid}] initializing per team bot spawner. globalJip: <{globalJipSetting}>")
  // Matching teams are "spawn groups" in this context
  get_matching_invite_data() |> FindMember("mode_info", JsonType.kObjectType) <| $(modeinfo : JsonValue)
    modeinfo |> FindMember("teams", JsonType.kArrayType) <| $(teams : JsonValue)
      teams |> GetArray() <| $(teamsArray : JsonConstArray)
        var teamIdx = -1
        for team in teamsArray
          teamIdx += 1
          let name = json_get_or(team, "name", "")
          let maxSquads = json_get_or(team, "maxGroups", 0) // Groups on matching are squads in this context
          totalMaxSquads += maxSquads
          // 0.0 in per-team jip means it's unset
          // TODO: fix this in all our matching configs! Matching thinks that 0.0 is DISABLING JIP, not just unset
          var jipDuration = parse_float_from_json(team, "jipEnableTime", 0.0, 0)
          if jipDuration == 0.0
            jipDuration = globalJipSetting
          // == 0.0 means no JIP is allowed for the team, so don't spawn bots
          let jipEndAt = jipDuration <= 0.0 ? FLT_MAX : curTime + jipDuration
          firstSpawnAt = min(firstSpawnAt, jipEndAt)
          var botsPerGroup = bot_spawner__botsPerGroupMinMax
          if !empty(bot_spawner__allowedTeams) && -1 == bot_spawner__allowedTeams |> find_index(teamIdx)
            botsPerGroup = int2(0, 0)
          print("[BOT SPAWNER][{spawner_eid}] Team \"{name}\" max groups <{maxSquads}> jip duration <{jipDuration}> bots per group <{botsPerGroup}>.")
          push(teamSpawnInfo, TeamSpawnInfo(bot_spawner__teamName = name,
                                            bot_spawner__teamMaxGroups = maxSquads,
                                            bot_spawner__teamJipEndAt = jipEndAt,
                                            bot_spawner__teamBotsPerGroupMinMax = botsPerGroup,
                                            bot_spawner__teamSpawnGroupId = teamIdx + 1,
                                            bot_spawner__teamLastSpawnedAt = 0.0))

  if totalMaxSquads == 0 && is_dev_circuit()
    print("[BOT SPAWNER][{spawner_eid}] filling with default teams")
    let defaultJipTime = 300.0
    var fakeTeam = TeamSpawnInfo(bot_spawner__teamName = "DefaultRaider",
                                 bot_spawner__teamMaxGroups = 8,
                                 bot_spawner__teamJipEndAt = curTime + defaultJipTime,
                                 bot_spawner__teamBotsPerGroupMinMax = int2(2, 3),
                                 bot_spawner__teamLastSpawnedAt = 0.0)
    fakeTeam.bot_spawner__teamSpawnGroupId = 1
    push(teamSpawnInfo, fakeTeam)
    fakeTeam.bot_spawner__teamSpawnGroupId = 2
    push(teamSpawnInfo, fakeTeam)
    fakeTeam.bot_spawner__teamSpawnGroupId = 3
    push(teamSpawnInfo, fakeTeam)
    firstSpawnAt = curTime + defaultJipTime

  if firstSpawnAt == FLT_MAX
    print("[BOT SPAWNER][{spawner_eid}] Nothing to spawn ending work.")
    destroyEntity(spawner_eid)
    return

  if bot_spawner__spawnAt == 0.0
    bot_spawner__spawnAt = firstSpawnAt
    print("[BOT SPAWNER][{eid}] Bot spawner set next tick at <{firstSpawnAt}> (in {int(firstSpawnAt - curTime)}s)")


[soa_es, es(tag=server, no_order)]
def raid_bot_spawner_per_team_update(act : UpdateStageInfoAct;
                                     eid aka spawner_eid : EntityId;
                                     bot_spawner__spawnInterval : float;
                                     bot_spawner__squadSpawnCountRange : int2;
                                     bot_spawner__heroTemplates : StringList;
                                     var bot_spawner__spawnAt : float&;
                                     teamSpawnInfo : TeamSpawnInfo_SOA)
  if act.curTime < bot_spawner__spawnAt
    return

  bot_spawner__spawnAt = act.curTime + bot_spawner__spawnInterval

  // Aggregate all spawn bases by spawn group id and separate occupied from free ones
  var spawnGroup2SpawnBases : table<int; tuple<occupiedEids : array<EntityId>; freeEids : array<EntityId>>>
  query() <| $ [soa_blk, es] (eid : EntityId; team : int; spawnBase__spawnGroupId : int)
    if spawnBase__spawnGroupId <= 0
      return

    if !key_exists(spawnGroup2SpawnBases, spawnBase__spawnGroupId)
      spawnGroup2SpawnBases[spawnBase__spawnGroupId] <-  (array<EntityId>(), array<EntityId>())

    spawnGroup2SpawnBases |> get(spawnBase__spawnGroupId) <| $(var spawnInfo)
      if team == TEAM_UNASSIGNED
        spawnInfo.freeEids |> push(eid)
      else
        spawnInfo.occupiedEids |> push(eid)

  let allDangerPositions = find_spawn_base_danger_positions(TEAM_UNASSIGNED)
  let playerDangerPositions = find_spawn_base_danger_positions_players_only()

  var haveWaitingTeams = false

  // Generate all combinations of team and spawn base to spawn
  var spawnCandidates : array<tuple<teamIndex : int; spawnEid : EntityId>>
  for team, teamIndex in teamSpawnInfo, iter_range(teamSpawnInfo)
    // Don't spawn bots for teams where real players can still join
    if act.curTime < team.bot_spawner__teamJipEndAt
      haveWaitingTeams = true
      continue

    let spawnGroupId = team.bot_spawner__teamSpawnGroupId
    get(spawnGroup2SpawnBases, spawnGroupId) <| $(groupInfo)
      let availableSpawnsCount = length(groupInfo.freeEids)
      let needSquadsToSpawn = team.bot_spawner__teamMaxGroups - length(groupInfo.occupiedEids) // Is this correct? Seems a bit off, but this is old logic
      for j in range(min(availableSpawnsCount, needSquadsToSpawn))
        spawnCandidates |> emplace((teamIndex, groupInfo.freeEids[j]))


  var haveSpawnsBlockedByPlayers = false

  // Avoid to spawn near players
  let spawnCandidatesCount = length(spawnCandidates)
  for spawnCandidateIdx in range(spawnCandidatesCount)
    let reverseIdx = spawnCandidatesCount - spawnCandidateIdx - 1
    query(spawnCandidates[reverseIdx].spawnEid) <| $ [es] (transform aka candidate_transform : float3x4)
      let distToClosestPlayerSq = get_closest_dist_sq(candidate_transform[3], playerDangerPositions)
      if distToClosestPlayerSq < square(100.0)
        spawnCandidates |> erase(reverseIdx)
        haveSpawnsBlockedByPlayers = true


  if empty(spawnCandidates) && !haveWaitingTeams && !haveSpawnsBlockedByPlayers
    print("[BOT SPAWNER][{spawner_eid}] Nothing to spawn ending work.")
    destroyEntity(spawner_eid)
    return

  spawnCandidates |> shuffle()

  var numSquadsToSpawn = rnd_int(bot_spawner__squadSpawnCountRange.x, bot_spawner__squadSpawnCountRange.y)
  numSquadsToSpawn = min(length(spawnCandidates), numSquadsToSpawn)
  print("[BOT SPAWNER][{spawner_eid}] Have {length(spawnCandidates)} spawn candidates, will spawn {numSquadsToSpawn} squads.")
  query(spawner_eid) <| $ [es] (var bot_spawner__teamLastSpawnedAt : FloatList)
    for i in range(numSquadsToSpawn)
      let candidate = spawnCandidates[i]
      let teamIndex = int(candidate.teamIndex)
      let teamId = create_new_bot_team(candidate.spawnEid, teamSpawnInfo[teamIndex].bot_spawner__teamSpawnGroupId)
      let botsInSquadCount = rnd_int(teamSpawnInfo[teamIndex].bot_spawner__teamBotsPerGroupMinMax.x, teamSpawnInfo[teamIndex].bot_spawner__teamBotsPerGroupMinMax.y)
      for botCounter in range(botsInSquadCount)
        var heroTemplate := string(bot_spawner__heroTemplates[grnd() % length(bot_spawner__heroTemplates)])
        if botCounter == 0
          heroTemplate = add_sub_template_name(heroTemplate, "bot_squad_leader")

        spawn_bot_hero(heroTemplate, teamId, botsInSquadCount, candidate.spawnEid)
        bot_spawner__teamLastSpawnedAt[teamIndex] = act.curTime
        print("[BOT SPAWNER][{spawner_eid}] Spawned new bot \"{heroTemplate}\" in team_id <{teamId}> (group {teamSpawnInfo[teamIndex].bot_spawner__teamSpawnGroupId}) on base eid <{candidate.spawnEid}> \"{teamSpawnInfo[teamIndex].bot_spawner__teamName}\".")

  print("[BOT SPAWNER][{spawner_eid}] Bot spawner set next tick at <{bot_spawner__spawnAt}>. (in {int(bot_spawner__spawnAt - act.curTime)}s)")


[es(tag=server, on_event=EventOnMovingZoneStarted)]
def stop_bot_spawner_on_zone_shrink_start(evt : Event;
                                          eid : EntityId;
                                          bot_spawner__stopOnZoneShrinkStart : bool)
  if bot_spawner__stopOnZoneShrinkStart
    print("[BOT SPAWNER][{eid}] Destroying bot spawner as zone is shrinking.")
    destroyEntity(eid)
