require ecs
require ecs.safe
require app
require Grid
require DagorMath
require DagorSystem
require DngDm
require BehNodes
require walkerai
require math.random
require game.es.ecs_common
require game.events.events_active_matter
require game.es.ability_common
require game.events.events
require math.base
require game.es.monster_common
require game.es.am_nphys_common
require game.es.ability_enums_common
require pathfinder


def calculate_scream_minion_spawn_position(minion_index : int;
                                           master_transform : float3x4;
                                           spawn_sector_radians : float;
                                           spawn_sector_offset : float2;
                                           total_minions_count : int)
  let halfSpawnSectorRadians = spawn_sector_radians * 0.5
  let anglePerMinion = safediv(spawn_sector_radians, float(total_minions_count))

  var angle = -halfSpawnSectorRadians + 0.5 * anglePerMinion + (anglePerMinion * float(minion_index))
  angle += rnd_float(-0.1, 0.1)

  var dir2d : float3
  sincos(angle, dir2d.z, dir2d.x)

  let offset = rnd_float(spawn_sector_offset) * dir2d

  return master_transform * offset


def calculate_scream_minion_spawn_tm(minion_index : int;
                                     master_transform : float3x4;
                                     spawn_sector_radians : float;
                                     spawn_sector_offset : float2;
                                     total_minions_count : int)
  var minionPos = calculate_scream_minion_spawn_position(minion_index, master_transform,
                                                         spawn_sector_radians, spawn_sector_offset,
                                                         total_minions_count)

  project_to_nearest_navmesh_point(minionPos, 1.0)

  var minionTM : float3x4
  minionTM[0] = normalize(master_transform[3] - minionPos)
  minionTM[2] = cross(minionTM[0], master_transform[1])
  minionTM[1] = cross(minionTM[2], minionTM[0])
  minionTM[3] = minionPos

  return minionTM


[es(tag=server, on_appear, REQUIRE=scream_affect)]
def scream_affect_on_appear(evt : Event;
                            game_effect__attachedTo : EntityId)
  query(game_effect__attachedTo) <| $ [es] (game_effect__screamMinionTemplates : Array;
                                            game_effect__screamMinionSpawnSectorDegrees : float;
                                            game_effect__screamMinionSpawnOffset : float2;
                                            game_effect__screamMinionCountMax : int;
                                            game_effect__screamMinionDistSqToTeleport : float = 50.0;
                                            transform aka master_transform : float3x4)
    let spawnSectorRadians = DEG_TO_RAD * game_effect__screamMinionSpawnSectorDegrees

    var currentMinions : array<EntityId>
    var minionsToTeleport : array<EntityId>
    query() <| $[es(REQUIRE_NOT=deadEntity)] (eid aka minion_eid : EntityId;
                                              minion_creature__masterEid : EntityId;
                                              transform aka minion_transform : float3x4;
                                              hitpoints__maxHp : float;
                                              var hitpoints__hp : float&)
      if minion_creature__masterEid == game_effect__attachedTo
        currentMinions |> push(minion_eid)

        hitpoints__hp = hitpoints__maxHp

        let distToMasterSq = distance_sq(master_transform[3], minion_transform[3])
        if distToMasterSq >= game_effect__screamMinionDistSqToTeleport
          minionsToTeleport |> push(minion_eid)

    let processingMinionsCount = min(length(minionsToTeleport) + 1, game_effect__screamMinionCountMax)

    var minionIndex = 0

    // Teleport existing minions
    for currentMinion in minionsToTeleport

      let minionTM = calculate_scream_minion_spawn_tm(minionIndex++, master_transform,
                                                      spawnSectorRadians, game_effect__screamMinionSpawnOffset,
                                                      processingMinionsCount)
      nphys_teleport_to_tm(currentMinion, minionTM)


    if length(currentMinions) >= game_effect__screamMinionCountMax
      return

    var minionTotalWeight = 0.0
    for screamMinionTemplateData in game_effect__screamMinionTemplates
      minionTotalWeight += (screamMinionTemplateData as Object)?.weight ?? 0.0

    let rnd = rnd_float(0.0, minionTotalWeight)
    var weight = 0.0
    for screamMinionTemplateData in game_effect__screamMinionTemplates
      weight += (screamMinionTemplateData as Object)?.weight ?? 0.0
      if weight >= rnd
        let screamMinionTemplate = (screamMinionTemplateData as Object)?["template"] ?? ""

        let minionTM = calculate_scream_minion_spawn_tm(minionIndex++, master_transform,
                                                        spawnSectorRadians, game_effect__screamMinionSpawnOffset,
                                                        processingMinionsCount)
        spawn_minion(game_effect__attachedTo, minionTM,
                    "{screamMinionTemplate}+monster_changed_minion_spawn_from_portal")
        break


def calucale_scream_minions_count(master_eid : EntityId)
  var minions = 0
  query() <| $ [es(REQUIRE_NOT=deadEntity)] (minion_creature__masterEid : EntityId)
    if master_eid == minion_creature__masterEid
      minions++
  return minions


[es(on_appear)]
def scream_minion_on_appear(evt : Event;
                            minion_creature__masterEid : EntityId)
  query(minion_creature__masterEid) <| $ [es] (var game_effect__screamMinionCount : int&)
    game_effect__screamMinionCount = calucale_scream_minions_count(minion_creature__masterEid)


[es(on_disappear)]
def scream_minion_on_disappear(evt : Event;
                               minion_creature__masterEid : EntityId)
  query(minion_creature__masterEid) <| $ [es] (var game_effect__screamMinionCount : int&)
    game_effect__screamMinionCount--


[es(on_appear, REQUIRE=deadEntity)]
def scream_minion_on_death(evt : Event;
                           var minion_creature__masterEid : EntityId&)
  query(minion_creature__masterEid) <| $ [es] (var game_effect__screamMinionCount : int&)
    game_effect__screamMinionCount = calucale_scream_minions_count(minion_creature__masterEid)
    minion_creature__masterEid = INVALID_ENTITY_ID


[es(tag=gameClient, on_appear, REQUIRE=scream_affect_in)]
def disoriented_client_near_sceraming_monster(evt : Event;
                                              game_effect__attachedTo : EntityId)
  query(game_effect__attachedTo) <| $ [es] (game_effect__screamDistance : float;
                                            game_effect__screamDisorientationRadius : float2;
                                            game_effect__screamDisorientationPower : float2;
                                            game_effect__screamDisorientationDistExp : float;
                                            transform aka screamer_transform : float3x4)
    find_query() <| $[es(REQUIRE=hero)] (eid aka hero_eid : EntityId;
                                         camera__look_at : DPoint3&)
      let distToHeadSq = length_sq(float3(camera__look_at) - screamer_transform[3])
      if distToHeadSq < square(game_effect__screamDistance) && game_effect__attachedTo != hero_eid
        sendEvent(hero_eid, EventPlayerTinnitus(position = screamer_transform[3],
          radius = game_effect__screamDisorientationRadius,
          power = game_effect__screamDisorientationPower,
          distExponent = game_effect__screamDisorientationDistExp))
      return true


[es(tag=server, on_appear)]
def tamed_creature_on_appear(evt : Event;
                             eid : EntityId;
                             minion_creature__masterEid : EntityId;
                             tamable_creature__behNode : string;
                             var agent_dangers : AgentDangers;
                             var tamed_creature__prevBehNode : das_string;
                             var tamed_creature__prevTeam : int&;
                             var team aka changed_team : int&;
                             var beh_tree__node : das_string;
                             var beh_tree : BehaviourTree;
                             var beh_tree__latencyLoadRequire : bool&)
  if tamable_creature__behNode == ""
    logerr("{get_entity_info(eid)}: tamed_creature_on_appear: tamable_creature__behNode is empty!")
    return

  query(minion_creature__masterEid) <| $ [es] (team aka master_team : int)
    tamed_creature__prevTeam = changed_team
    changed_team = master_team

    tamed_creature__prevBehNode := beh_tree__node
    beh_tree__node := tamable_creature__behNode

    beh_tree_reset(beh_tree)
    beh_tree__latencyLoadRequire = true

    agent_dangers.dangers |> clear()


[es(tag=server, no_order)]
def tamed_creature_update(act : UpdateStageInfoAct;
                          eid : EntityId;
                          tamed_creature__tamedTo : float;
                          var minion_creature__masterEid : EntityId&)
  if act.curTime >= tamed_creature__tamedTo
    removeSubTemplate(eid, "tamed_creature")
    minion_creature__masterEid = INVALID_ENTITY_ID


[es(tag=server, on_disappear)]
def tamed_creature_on_disappear(evt : Event;
                                tamed_creature__prevBehNode : string;
                                tamed_creature__prevTeam : int&;
                                var agent_dangers : AgentDangers;
                                var team aka changed_team : int&;
                                var beh_tree__node : das_string;
                                var beh_tree : BehaviourTree;
                                var beh_tree__latencyLoadRequire : bool&)
  changed_team = tamed_creature__prevTeam
  beh_tree__node := tamed_creature__prevBehNode

  beh_tree_reset(beh_tree)
  beh_tree__latencyLoadRequire = true

  agent_dangers.dangers |> clear()


[es(tag=gameClient, REQUIRE=hero)]
def scream_ability_on_use_failed(evt : AbilityUseFailed;
                                 var hero_scream_ability__lastFailedUseTime : float&)
  if evt.ability_name == SCREAM_ABILITY_NAME
    if evt.reason == int(AbilityUseFailedReason.COOLDOWN)
      hero_scream_ability__lastFailedUseTime = get_sync_time()


[es(tag=gameClient, on_appear, REQUIRE=hero)]
def scream_ability_store_spawn_time(evt : Event;
                                    var hero_scream_ability__spawnTime : float&)
  hero_scream_ability__spawnTime = get_sync_time()


[es(tag=gameClient, track=hero_ability__abilities, REQUIRE=hero)]
def scream_ability_update_spawn_time(evt : Event;
                                     hero_ability__abilities : Array;
                                     var hero_scream_ability__spawnTime : float&)
  if hero_scream_ability__spawnTime == 0.0
    for item in hero_ability__abilities
      let itemObj = get_ecs_object(item)
      let abilityName = get_string(itemObj, "name", "")
      if abilityName == SCREAM_ABILITY_NAME
        hero_scream_ability__spawnTime = get_sync_time()


def kill_all_minions(master_eid : EntityId)
  query() <| $ [es] (eid aka minion_eid : EntityId;
                     minion_creature__masterEid : EntityId)
    if minion_creature__masterEid == master_eid
      createEntity("suicide_effect_in_1_sec") <| $(var init : ComponentsInitializer)
        init |> set("game_effect__attachedTo", minion_eid)
        init |> set("game_effect__applyDelay", rnd_float(0.0, 2.5))


[es(tag=server, REQUIRE=(deadEntity, game_effect__screamMinionCount), on_appear)]
def active_matter_scream_ability_dead(evt : Event;
                                      eid aka master_eid : EntityId)
  kill_all_minions(master_eid)


[es(tag=server, REQUIRE=game_effect__screamMinionCount, on_disappear)]
def active_matter_scream_ability_disappear(evt : Event;
                                           eid aka master_eid : EntityId)
  kill_all_minions(master_eid)