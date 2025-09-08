require app
require Dacoll
require DagorMath
require DagorSystem
require DngDm
require DngHuman
require DngPhysObj
require ecs
require ecs.safe
require ecs.soa_template
require game.es.am_encounter_jump_quest_common
require game.es.riextra_common
require game.es.tweening_common
require game.events.events
require game.events.events_active_matter
require Grid
require math.base
require math.easing
require math.random
require net
require PhysObj

let DEFAULT_SPHERE_CAST_MASK = int(PhysLayer.EPL_ALL) & ~(int(PhysLayer.EPL_CHARACTER) | int(PhysLayer.EPL_KINEMATIC) | int(PhysLayer.EPL_DEBRIS))


def prepare_jump_rendinsts_collision_info(node_type : EncounterJumpQuestNodeType;
                                          encounter_jump_quest__physBlkFolder : string;
                                          var encounter_jump_quest_rendinsts : Array)
  for rendinstDataComp in encounter_jump_quest_rendinsts
    var rendinstDataObj = rendinstDataComp as Object
    if rendinstDataObj == null
      continue
    assume rendinstData = *rendinstDataObj
    let rendinstName = rendinstData.rendinst ?? ""
    let rendinstIdx = ensure_riextra_res_idx(rendinstName)

    if !has(rendinstData, "collres__res") && rendinstName != ""
      set(rendinstData, "collres__res", "{rendinstName}_collision")

    if !has(rendinstData, "phys_obj_net_phys__blk") && rendinstName != ""
      set(rendinstData, "phys_obj_net_phys__blk", "{encounter_jump_quest__physBlkFolder}/{node_type}/{rendinstName}.blk")

    let collres = get_ri_gen_extra_collres(rendinstIdx)
    if collres == null
      if rendinstIdx >= 0
        if node_type == EncounterJumpQuestNodeType.PATH || node_type == EncounterJumpQuestNodeType.TOP_PLATFORM
          logerr("Jump quest rendinst '{rendinstName}' has no collres! rendinstIdx={rendinstIdx}")

      set(rendinstData, "collisionSize", float3(2.0, 2.0, 2.0))
      continue

    let collresBox = BBox3(collres.vFullBBox)

    if !has(rendinstData, "collisionSize")
      set(rendinstData, "collisionSize", collresBox.width)
    if !has(rendinstData, "collisionOffset")
      set(rendinstData, "collisionOffset", -collresBox.center)


[soa_es, es(tag=server, on_appear, REQUIRE=encounter_jump_quest)]
def encounter_jump_quest_init(evt : Event;
                              eid : EntityId;
                              encounter_jump_quest__physBlkFolder : string;
                              var encounter_jump_quest__pathRendinsts : Array;
                              var encounter_jump_quest__topPlatformRendinsts : Array;
                              var encounter_jump_quest__decorRendinsts : Array)
  prepare_jump_rendinsts_collision_info(EncounterJumpQuestNodeType.PATH,
                                        encounter_jump_quest__physBlkFolder,
                                        encounter_jump_quest__pathRendinsts)
  prepare_jump_rendinsts_collision_info(EncounterJumpQuestNodeType.TOP_PLATFORM,
                                        encounter_jump_quest__physBlkFolder,
                                        encounter_jump_quest__topPlatformRendinsts)
  prepare_jump_rendinsts_collision_info(EncounterJumpQuestNodeType.DECOR,
                                        encounter_jump_quest__physBlkFolder,
                                        encounter_jump_quest__decorRendinsts)
  generate_jump_nodes_tree(eid)


struct EncounterJumpQuestSpawnPointData
  tm : float3x4
  templ : string


[es(tag=server, on_event=EventLevelLoaded, after=moving_zone_init, REQUIRE=encounter_jump_quest_controller)]
def encounter_jump_quest_controller_init(evt : Event;
                                         encounter_jump_quest_controller__encountersCount : int2;
                                         encounter_jump_quest_controller__minDistanceBetweenEncountersSq : float)
  assume minDistanceBetweenEncountersSq = encounter_jump_quest_controller__minDistanceBetweenEncountersSq

  var zoneRadiusSq = FLT_MAX
  var zoneCenter = float3(0, 0, 0)
  find_query() <| $ [es(REQUIRE=moving_zone__startEndTime)] (sphere_zone__radius : float; transform : float3x4)
    zoneRadiusSq = square(sphere_zone__radius)
    zoneCenter = transform[3]
    return true

  var encountersCount = rnd_int(encounter_jump_quest_controller__encountersCount)
  var spawnPoints : array<EncounterJumpQuestSpawnPointData>
  query() <| $ [es] (transform : float3x4;
                     encounter_jump_quest_spawn_point__jumpQuestTemplate : string)
    if distance_sq(transform[3], zoneCenter) > zoneRadiusSq
      return
    spawnPoints |> push(
      EncounterJumpQuestSpawnPointData(
        tm = transform,
        templ = encounter_jump_quest_spawn_point__jumpQuestTemplate))
  spawnPoints |> shuffle()

  var spawnPointIndex = 0
  var usedSpawnPointPositions : array<float3>
  while encountersCount > 0 && spawnPointIndex < length(spawnPoints)
    let potentialSpawnPoint = spawnPoints[spawnPointIndex]
    var valid = true
    for usedSpawnPointPosition in usedSpawnPointPositions
      if distance_sq(potentialSpawnPoint.tm[3], usedSpawnPointPosition) < minDistanceBetweenEncountersSq
        valid = false
        break
    if valid
      createEntity(potentialSpawnPoint.templ) <| $(init)
        init |> set("transform", potentialSpawnPoint.tm)
      usedSpawnPointPositions |> push(potentialSpawnPoint.tm[3])
      --encountersCount
      print("Creating jump encounter at {potentialSpawnPoint.tm[3]}")

    ++spawnPointIndex


[es(tag=server, on_appear)]
def encounter_jump_quest_rendinst_rotor_init(evt : Event;
                                             transform : float3x4;
                                             encounter_jump_quest_rendinst_rotor__rotSpeedRng : float2;
                                             var encounter_jump_quest_rendinst_rotor__rotSpeed : float3&;
                                             var encounter_jump_quest_rendinst_rotor__startAngle : float3&)
  encounter_jump_quest_rendinst_rotor__rotSpeed = float3(rnd_float(encounter_jump_quest_rendinst_rotor__rotSpeedRng),
                                                         rnd_float(encounter_jump_quest_rendinst_rotor__rotSpeedRng),
                                                         rnd_float(encounter_jump_quest_rendinst_rotor__rotSpeedRng))
  var heading : float
  var attitude : float
  var bank : float
  let q = DagorMath::quat(transform)
  quat_to_euler(q, heading, attitude, bank)
  encounter_jump_quest_rendinst_rotor__startAngle = float3(bank, heading, attitude)


def get_encounter_jump_quest_rendinst_rotor_rotation(cur_time : float;
                                                     encounter_jump_quest_rendinst_rotor__startAngle : float3;
                                                     encounter_jump_quest_rendinst_rotor__rotSpeed : float3)
  let curAnglesShift = encounter_jump_quest_rendinst_rotor__rotSpeed * cur_time
  var q : quat
  euler_to_quat(encounter_jump_quest_rendinst_rotor__startAngle.y + curAnglesShift.y,
                encounter_jump_quest_rendinst_rotor__startAngle.z + curAnglesShift.z,
                encounter_jump_quest_rendinst_rotor__startAngle.x + curAnglesShift.x,
                q)
  return q


[es(no_order)]
def encounter_jump_quest_rendinst_rotor_update(act : UpdateStageInfoAct;
                                               encounter_jump_quest_rendinst_rotor__active : bool;
                                               encounter_jump_quest_rendinst_rotor__startAngle : float3;
                                               encounter_jump_quest_rendinst_rotor__rotSpeed : float3;
                                               var transform : float3x4)
  if !encounter_jump_quest_rendinst_rotor__active
    return

  let q = get_encounter_jump_quest_rendinst_rotor_rotation(act.curTime, encounter_jump_quest_rendinst_rotor__startAngle,
                                                                           encounter_jump_quest_rendinst_rotor__rotSpeed)
  make_tm(q, transform[3], transform)


[es(tag=server, on_appear)]
def encounter_jump_quest_rendinst_levitation_init(evt : Event;
                                                  encounter_jump_quest_rendinst_levitation__speedRng : float2;
                                                  encounter_jump_quest_rendinst_levitation__amplitudeRng : float2;
                                                  var encounter_jump_quest_rendinst_levitation__speed : float&;
                                                  var encounter_jump_quest_rendinst_levitation__amplitude : float&)
  encounter_jump_quest_rendinst_levitation__speed = rnd_float(encounter_jump_quest_rendinst_levitation__speedRng)
  encounter_jump_quest_rendinst_levitation__amplitude = rnd_float(encounter_jump_quest_rendinst_levitation__amplitudeRng)


[es(before=(encounter_jump_quest_process_players))]
def encounter_jump_quest_rendinst_levitation_pre_update(act : UpdateStageInfoAct;
                                                        var encounter_jump_quest_rendinst_levitation__load : int&)
  encounter_jump_quest_rendinst_levitation__load = 0


[soa_es, es(no_order)]
def encounter_jump_quest_process_players(act : UpdateStageInfoAct;
                                         transform aka jump_quest_transform : float3x4;
                                         encounter_jump_quest__radiusSq : float;
                                         encounter_jump_quest__pathRendinsts : Array;
                                         encounter_jump_quest__topPlatformRendinsts : Array;
                                         encounter_jump_quest__decorRendinsts : Array;
                                         encounter_jump_quest__nodes : EncounterJumpQuestNode_SOA)
  query() <| $ [es(REQUIRE=possessedByPlr)] (transform aka possessed_transform : float3x4;
                                             beh_tree__enabled : bool;
                                             human_net_phys__isOnGround : bool;
                                             var human_net_phys : HumanActor)
    if beh_tree__enabled
      return

    if distance_sq(jump_quest_transform[3], possessed_transform[3]) > encounter_jump_quest__radiusSq
      return
    if human_net_phys__isOnGround

      let upDir = -human_net_phys.phys.currentState.gravDirection
      let obstacleHt = human_net_phys.phys.maxObstacleHeight + human_net_phys.phys.collRad
      var tm : float3x4
      location_toTM(human_net_phys.phys.currentState.location, tm)
      let walkQueryPos = tm * human_net_phys.phys |> human_phys_calcCollCenter()
      let curMaxPos = walkQueryPos + upDir * obstacleHt
      let curMinPos = walkQueryPos - upDir * obstacleHt

      var queryOut = ShapeQueryOutput()
      if sphere_cast_ex(curMaxPos, curMinPos, human_net_phys.phys.walkRad,
                        queryOut, human_net_phys.phys.rayMatId, human_net_phys.phys.torsoCollision,
                        human_net_phys.phys |> human_phys_getTraceHandle(), DEFAULT_SPHERE_CAST_MASK)
        let bsphere = BSphere3(queryOut.res, 0.5)
        find_entity_in_grid(ecs_hash("jump_quest_rendinsts"), bsphere, GridEntCheck.BOUNDING) <| $ [unused_argument(pos)] (rendinst_eid : EntityId; pos : float3)
          var rendinstFound = false
          query(rendinst_eid) <| $ [es(REQUIRE_NOT=encounter_jump_quest_rendinst_rotor)] (encounter_jump_quest_node_rendinst__nodeIndex : int;
                                                                                          transform aka rendinst_transform : float3x4;
                                                                                          var encounter_jump_quest_rendinst_levitation__load : int&;
                                                                                          var encounter_jump_quest_rendinst_levitation__loadTimestamp : float&)
            assume nodeIdx = encounter_jump_quest_node_rendinst__nodeIndex
            let nodeType = encounter_jump_quest__nodes[nodeIdx].encounter_jump_quest__nodes__type
            let rendinstIdx = encounter_jump_quest__nodes[nodeIdx].encounter_jump_quest__nodes__rendinstIdx
            select_jump_node_rendinst_data(nodeType, rendinstIdx,
                                          encounter_jump_quest__pathRendinsts,
                                          encounter_jump_quest__topPlatformRendinsts,
                                          encounter_jump_quest__decorRendinsts) <| $(rendinstData : Object)
              let collisionOffset = rendinstData.collisionOffset ?? float3(0.0, 0.0, 0.0)

              var nodeCollisionTm = encounter_jump_quest__nodes[nodeIdx].encounter_jump_quest__nodes__collisionTm
              nodeCollisionTm[3] = rendinst_transform[3] - rotate(rendinst_transform, collisionOffset)

              let localPoint = inverse(nodeCollisionTm) * queryOut.res
              let BBOX_MARGIN = 0.05
              if BBox3(float3(), 1.0 + BBOX_MARGIN) & localPoint
                rendinstFound = true
                encounter_jump_quest_rendinst_levitation__load++
                encounter_jump_quest_rendinst_levitation__loadTimestamp = act.curTime
          return rendinstFound


[es(after=(encounter_jump_quest_rendinst_rotor_update, encounter_jump_quest_process_players))]
def encounter_jump_quest_rendinst_levitation_update(act : UpdateStageInfoAct;
                                                    encounter_jump_quest_rendinst_levitation__active : bool;
                                                    encounter_jump_quest_rendinst_levitation__speed : float;
                                                    encounter_jump_quest_rendinst_levitation__amplitude : float;
                                                    encounter_jump_quest_node_rendinst__positionTransform : float3x4;
                                                    encounter_jump_quest_node_rendinst__volume : float;
                                                    encounter_jump_quest_rendinst_levitation__load : int;
                                                    encounter_jump_quest_rendinst_levitation__loadTimestamp : float;
                                                    encounter_jump_quest_rendinst_levitation__saggin : float;
                                                    encounter_jump_quest_rendinst_levitation__sagginExtraTime : float;
                                                    encounter_jump_quest_rendinst_levitation__sagginMaxLoad : int;
                                                    encounter_jump_quest_rendinst_levitation__sagginVolumesRange : float2;
                                                    encounter_jump_quest_rendinst_levitation__sagginVolumeMult : float;
                                                    encounter_jump_quest_rendinst_levitation__lerpFactor : float;
                                                    var transform : float3x4)
  if !encounter_jump_quest_rendinst_levitation__active
    return

  assume loadTimestamp = encounter_jump_quest_rendinst_levitation__loadTimestamp
  assume volume = encounter_jump_quest_node_rendinst__volume

  let load = min(encounter_jump_quest_rendinst_levitation__load, encounter_jump_quest_rendinst_levitation__sagginMaxLoad)
  let loadProgress = float(load) / float(encounter_jump_quest_rendinst_levitation__sagginMaxLoad)

  let amplitude = encounter_jump_quest_rendinst_levitation__amplitude * (1.0 - loadProgress)
  let yOffset = amplitude * sin(act.curTime * encounter_jump_quest_rendinst_levitation__speed)

  var newY = encounter_jump_quest_node_rendinst__positionTransform[3].y + yOffset

  if (encounter_jump_quest_rendinst_levitation__load > 0 ||
      (loadTimestamp != 0.0 && loadTimestamp + encounter_jump_quest_rendinst_levitation__sagginExtraTime >= act.curTime))
    let volumeKoef = cvt(encounter_jump_quest_node_rendinst__volume,
                         encounter_jump_quest_rendinst_levitation__sagginVolumesRange.x,
                         encounter_jump_quest_rendinst_levitation__sagginVolumesRange.y,
                         1.0,
                         encounter_jump_quest_rendinst_levitation__sagginVolumeMult)
    let totalSaggin = encounter_jump_quest_rendinst_levitation__saggin * float(load) * volumeKoef
    newY -= totalSaggin

  transform[3].y = lerp(transform[3].y, newY, act.dt * encounter_jump_quest_rendinst_levitation__lerpFactor)


def encounter_jump_quest_freefall_loot(origin_pos : float3;
                                       radius : float;
                                       time : float = 15.0)
  for_each_entity_in_grid(ecs_hash("loot"), BSphere3(origin_pos, radius), GridEntCheck.POS) <| $ [unused_argument(pos)] (item_eid : EntityId; pos : float3)
    query(item_eid) <| $ [es(REQUIRE=item__isPickable)] (dropTm : float3x4 const?)
      addSubTemplate(item_eid, "item_freefalling") <| $(var init : ComponentsInitializer)
        init |> set("item_freefalling__stopAt", get_sync_time() + time)
        if dropTm != null
          let addHeight = (*dropTm)[3].y
          init |> set("item_freefalling__addHeight", addHeight)


[soa_es, es(tag=server, track=encounter_jump_quest_node_rendinst__state)]
def encounter_jump_quest_node_rendinst_state_track_server(evt : Event;
                                                          eid : EntityId;
                                                          transform aka rendinst_transform : float3x4;
                                                          encounter_jump_quest_node_rendinst__treeDepth : int;
                                                          encounter_jump_quest_node_rendinst__state : int;
                                                          encounter_jump_quest_node_rendinst__demolitionDelayPerDepth : float2 = float2(0.025, 0.2);
                                                          encounter_jump_quest_node_rendinst__demolitionTime : float = 20.0;
                                                          encounter_jump_quest_node_rendinst__demolitionCoreImpulseRng : float2 = float2(20.0, 35.0);
                                                          encounter_jump_quest_node_rendinst__demolitionCoreOmegaRng : float2 = float2(0.6, 1.2);
                                                          encounter_jump_quest_node_rendinst__demolitionBaseImpulseRng : float2 = float2(0.5, 1.5);
                                                          encounter_jump_quest_node_rendinst__demolitionBaseOmegaRng : float2 = float2(0.3, 0.6);
                                                          encounter_jump_quest_node_rendinst__topPlatformDemolitionTime : float = 20.0;
                                                          encounter_jump_quest_node_rendinst__recoveringDelayPerDepth : float2 = float2(0.025, 0.2);
                                                          encounter_jump_quest_node_rendinst__jumpQuestEid : EntityId;
                                                          encounter_jump_quest_node_rendinst__nodeIndex : int;
                                                          encounter_jump_quest_node_rendinst__punchNodeIndex : int;
                                                          ri_extra__name : string;
                                                          var ri_extra__hasCollision : bool&)
  assume punchNodeIndex = encounter_jump_quest_node_rendinst__punchNodeIndex

  if encounter_jump_quest_node_rendinst__state == int(EncounterJumpQuestNodeRendinstState.PREPARING_TO_DEMOLITION)
    addSubTemplate(eid, "encounter_jump_quest_node_rendinst_preparing_to_demolition") <| $(var init : ComponentsInitializer)
      query(encounter_jump_quest_node_rendinst__jumpQuestEid) <| $ [soa_blk, es] (encounter_jump_quest__nodes : EncounterJumpQuestNode_SOA)
        assume nodeType = encounter_jump_quest__nodes[encounter_jump_quest_node_rendinst__nodeIndex].encounter_jump_quest__nodes__type
        if nodeType == int(EncounterJumpQuestNodeType.DECOR)
          init |> set("encounter_jump_quest_node_rendinst_preparing_to_demolition__demolitionAt", get_sync_time())
        elif nodeType == int(EncounterJumpQuestNodeType.TOP_PLATFORM)
          let demolitionDelay = encounter_jump_quest_node_rendinst__demolitionDelayPerDepth.y * float(encounter_jump_quest_node_rendinst__treeDepth)
          init |> set("encounter_jump_quest_node_rendinst_preparing_to_demolition__demolitionAt", get_sync_time() + demolitionDelay)
        else
          if (nodeType == int(EncounterJumpQuestNodeType.PATH)) && (encounter_jump_quest_node_rendinst__nodeIndex % punchNodeIndex == 0)
            init |> set("encounter_jump_quest_node_rendinst_preparing_to_demolition__demolitionAt", get_sync_time() + 0.05)
          else
            let demolitionDelay = rnd_float(encounter_jump_quest_node_rendinst__demolitionDelayPerDepth) * float(encounter_jump_quest_node_rendinst__treeDepth)
            init |> set("encounter_jump_quest_node_rendinst_preparing_to_demolition__demolitionAt", get_sync_time() + demolitionDelay)
  elif encounter_jump_quest_node_rendinst__state == int(EncounterJumpQuestNodeRendinstState.DEMOLITION)
    removeSubTemplate(eid, "encounter_jump_quest_node_rendinst_preparing_to_demolition")

    ri_extra__hasCollision = false
    replace_ri_extra_res(eid, ri_extra__name, /*destroy*/ false, /*add_restorable*/ false, /*create_destr_and_fx*/ false)

    query(encounter_jump_quest_node_rendinst__jumpQuestEid) <| $ [soa_blk, es] (encounter_jump_quest__coreEid : EntityId;
                                                                                encounter_jump_quest__nodes : EncounterJumpQuestNode_SOA)
      assume nodeType = encounter_jump_quest__nodes[encounter_jump_quest_node_rendinst__nodeIndex].encounter_jump_quest__nodes__type
      assume nodeFlags = encounter_jump_quest__nodes[encounter_jump_quest_node_rendinst__nodeIndex].encounter_jump_quest__nodes__flags

      let isGravitySphereNode = (nodeFlags & int(EncounterJumpQuestNodeFlags.GRAVITY_SPHERE_NODE)) != 0
      if isGravitySphereNode
        find_query() <| $ [es] (encounter_jump_quest_gravity_sphere__jumpQuestEid : EntityId;
                                encounter_jump_quest_gravity_sphere__nodeIndex : int;
                                var am_gravity_sphere__active : bool&)
          if (encounter_jump_quest_gravity_sphere__jumpQuestEid != encounter_jump_quest_node_rendinst__jumpQuestEid ||
              encounter_jump_quest_node_rendinst__nodeIndex != encounter_jump_quest_gravity_sphere__nodeIndex)
            return false
          am_gravity_sphere__active = false
          return true

      addSubTemplate(eid, "encounter_jump_quest_node_rendinst_demolition") <| $(var init : ComponentsInitializer)
        var demolitionTime = encounter_jump_quest_node_rendinst__demolitionTime
        if nodeType == int(EncounterJumpQuestNodeType.TOP_PLATFORM)
          demolitionTime = encounter_jump_quest_node_rendinst__topPlatformDemolitionTime
        else
          let isDecor = (nodeType == int(EncounterJumpQuestNodeType.DECOR))
          let isChosenPath = (nodeType == int(EncounterJumpQuestNodeType.PATH)) && (encounter_jump_quest_node_rendinst__nodeIndex % punchNodeIndex == 0)
          query(encounter_jump_quest__coreEid) <| $ [es] (transform aka core_transform : float3x4)
            let toCore = normalize(core_transform[3] - rendinst_transform[3])
            let corePunch = isChosenPath || isDecor
            assume demolitionCoreImpulseRng = encounter_jump_quest_node_rendinst__demolitionCoreImpulseRng
            assume demolitionCoreOmegaRng = encounter_jump_quest_node_rendinst__demolitionCoreOmegaRng
            assume demolitionBaseImpulseRng = encounter_jump_quest_node_rendinst__demolitionBaseImpulseRng
            assume demolitionBaseOmegaRng = encounter_jump_quest_node_rendinst__demolitionBaseOmegaRng
            let initialImpulse = corePunch ? -toCore * rnd_float(demolitionCoreImpulseRng) : rnd_dir3() * rnd_float(demolitionBaseImpulseRng)
            let initialOmega = corePunch ? rnd_dir3() * rnd_float(demolitionCoreOmegaRng) : rnd_dir3() * rnd_float(demolitionBaseOmegaRng)
            init |> set("encounter_jump_quest_node_rendinst_demolition__initialImpulse", initialImpulse)
            init |> set("encounter_jump_quest_node_rendinst_demolition__initialOmega", initialOmega)

        init |> set("encounter_jump_quest_node_rendinst_demolition__stopAt", get_sync_time() + demolitionTime)

    encounter_jump_quest_freefall_loot(rendinst_transform[3], 5.0)
  elif encounter_jump_quest_node_rendinst__state == int(EncounterJumpQuestNodeRendinstState.DEBRIS)
    ri_extra__hasCollision = true
    replace_ri_extra_res(eid, ri_extra__name, /*destroy*/ false, /*add_restorable*/ false, /*create_destr_and_fx*/ false)

    removeSubTemplate(eid, "encounter_jump_quest_node_rendinst_demolition")

    send_net_event(eid, CmdJumpQuestNodeSyncTransform(transform = rendinst_transform))
  elif encounter_jump_quest_node_rendinst__state == int(EncounterJumpQuestNodeRendinstState.PREPARING_TO_RECOVERING)
    addSubTemplate(eid, "encounter_jump_quest_node_rendinst_recovering") <| $(var init : ComponentsInitializer)
      let invDepth = max(0, 100 - encounter_jump_quest_node_rendinst__treeDepth)
      let recoveringDelay = rnd_float(encounter_jump_quest_node_rendinst__recoveringDelayPerDepth) * float(invDepth)
      init |> set("encounter_jump_quest_node_rendinst_recovering__recoveringAt", get_sync_time() + recoveringDelay)
  elif encounter_jump_quest_node_rendinst__state == int(EncounterJumpQuestNodeRendinstState.RECOVERING)
    encounter_jump_quest_freefall_loot(rendinst_transform[3], 5.0)
  elif encounter_jump_quest_node_rendinst__state == int(EncounterJumpQuestNodeRendinstState.NONE)
    send_net_event(eid, CmdJumpQuestNodeSyncTransform(transform = rendinst_transform))

    query(encounter_jump_quest_node_rendinst__jumpQuestEid) <| $ [soa_blk, es] (encounter_jump_quest__nodes : EncounterJumpQuestNode_SOA)
      assume nodeFlags = encounter_jump_quest__nodes[encounter_jump_quest_node_rendinst__nodeIndex].encounter_jump_quest__nodes__flags

      let isGravitySphereNode = (nodeFlags & int(EncounterJumpQuestNodeFlags.GRAVITY_SPHERE_NODE)) != 0
      if isGravitySphereNode
        find_query() <| $ [es] (encounter_jump_quest_gravity_sphere__jumpQuestEid : EntityId;
                                encounter_jump_quest_gravity_sphere__nodeIndex : int;
                                var am_gravity_sphere__active : bool&)
          if (encounter_jump_quest_gravity_sphere__jumpQuestEid != encounter_jump_quest_node_rendinst__jumpQuestEid ||
              encounter_jump_quest_node_rendinst__nodeIndex != encounter_jump_quest_gravity_sphere__nodeIndex)
            return false
          am_gravity_sphere__active = true
          return true


[es(tag=server, on_appear)]
def encounter_jump_quest_node_rendinst_demolition_init(evt : Event;
                                                       eid : EntityId;
                                                       ri_extra__name : string;
                                                       encounter_jump_quest_node_rendinst_demolition__initialImpulse : float3;
                                                       encounter_jump_quest_node_rendinst_demolition__initialOmega : float3;
                                                       var phys_obj_net_phys : PhysObjActor)
  if !phys_obj_net_phys.phys |> isCollisionValid()
    logerr("{eid}<{getEntityTemplateName(eid)}>: Jump quest node physobj collision invalid: '{ri_extra__name}'!")
    destroyEntity(eid)

  phys_obj_net_phys.phys.currentState.velocity += encounter_jump_quest_node_rendinst_demolition__initialImpulse
  phys_obj_net_phys.phys.currentState.omega += encounter_jump_quest_node_rendinst_demolition__initialOmega


[es]
def command_jump_quest_node_sync_transform(evt : CmdJumpQuestNodeSyncTransform;
                                           eid : EntityId;
                                           encounter_jump_quest_rendinst_rotor__active : bool const?;
                                           encounter_jump_quest_rendinst_levitation__active : bool const?)
  removeSubTemplate(eid, "loc_snapshots")

  if (encounter_jump_quest_rendinst_rotor__active == null &&
      encounter_jump_quest_rendinst_levitation__active == null)
    tween_transform_pos(eid, evt.transform[3], 3.0)


[soa_es, es(track=encounter_jump_quest_node_rendinst__state)]
def encounter_jump_quest_node_rendinst_state_track(evt : Event;
                                                   eid : EntityId;
                                                   encounter_jump_quest_node_rendinst__state : int;
                                                   var encounter_jump_quest_rendinst_rotor__active : bool?;
                                                   var encounter_jump_quest_rendinst_levitation__active : bool?)
  if encounter_jump_quest_node_rendinst__state == int(EncounterJumpQuestNodeRendinstState.DEMOLITION)
    addSubTemplate(eid, "loc_snapshots")
    addSubTemplate(eid, "loc_snapshots_wait_lock")

    if encounter_jump_quest_rendinst_rotor__active != null
      *encounter_jump_quest_rendinst_rotor__active = false
    if encounter_jump_quest_rendinst_levitation__active != null
      *encounter_jump_quest_rendinst_levitation__active = false

  elif encounter_jump_quest_node_rendinst__state == int(EncounterJumpQuestNodeRendinstState.DEBRIS)
    removeSubTemplate(eid, "loc_snapshots")
  elif encounter_jump_quest_node_rendinst__state == int(EncounterJumpQuestNodeRendinstState.RECOVERING)
    addSubTemplate(eid, "loc_snapshots")
    addSubTemplate(eid, "loc_snapshots_wait_lock")
  elif encounter_jump_quest_node_rendinst__state == int(EncounterJumpQuestNodeRendinstState.NONE)
    removeSubTemplate(eid, "loc_snapshots")

    if encounter_jump_quest_rendinst_rotor__active != null
      *encounter_jump_quest_rendinst_rotor__active = true
    if encounter_jump_quest_rendinst_levitation__active != null
      *encounter_jump_quest_rendinst_levitation__active = true


[es(tag=server, no_order)]
def encounter_jump_quest_node_rendinst_preparing_to_demolition(act : UpdateStageInfoAct;
                                                               encounter_jump_quest_node_rendinst_preparing_to_demolition__demolitionAt : float;
                                                               var encounter_jump_quest_node_rendinst__state : int&)
  if encounter_jump_quest_node_rendinst__state != int(EncounterJumpQuestNodeRendinstState.PREPARING_TO_DEMOLITION)
    return
  if act.curTime >= encounter_jump_quest_node_rendinst_preparing_to_demolition__demolitionAt
    encounter_jump_quest_node_rendinst__state = int(EncounterJumpQuestNodeRendinstState.DEMOLITION)


[es(tag=server, no_order)]
def encounter_jump_quest_node_rendinst_demolition(act : UpdateStageInfoAct;
                                                  phys_obj_net_phys : PhysObjActor;
                                                  var encounter_jump_quest_node_rendinst_demolition__stopAt : float&;
                                                  var encounter_jump_quest_node_rendinst__state : int&)
  if encounter_jump_quest_node_rendinst__state != int(EncounterJumpQuestNodeRendinstState.DEMOLITION)
    return
  if act.curTime >= encounter_jump_quest_node_rendinst_demolition__stopAt
    if (!phys_obj_net_phys.phys.currentState.hadContact ||
       length_sq(phys_obj_net_phys.phys.currentState.velocity) > square(1e-2) ||
       length_sq(phys_obj_net_phys.phys.currentState.omega) > square(1e-2))
      encounter_jump_quest_node_rendinst_demolition__stopAt = act.curTime + 1.0
      return
    encounter_jump_quest_node_rendinst__state = int(EncounterJumpQuestNodeRendinstState.DEBRIS)
  else
    if (phys_obj_net_phys.phys.hasGroundCollisionPoint &&
       length_sq(phys_obj_net_phys.phys.currentState.velocity) < square(1e-4) &&
       length_sq(phys_obj_net_phys.phys.currentState.omega) < square(1e-4))
      encounter_jump_quest_node_rendinst__state = int(EncounterJumpQuestNodeRendinstState.DEBRIS)


[es(tag=server, no_order)]
def encounter_jump_quest_node_rendinst_recovering(act : UpdateStageInfoAct;
                                                  eid : EntityId;
                                                  encounter_jump_quest_node_rendinst_recovering__recoveringAt : float;
                                                  encounter_jump_quest_node_rendinst_recovering__speedRng : float2;
                                                  encounter_jump_quest_node_rendinst__positionTransform : float3x4;
                                                  encounter_jump_quest_rendinst_rotor__startAngle : float3 const?;
                                                  encounter_jump_quest_rendinst_rotor__rotSpeed : float3 const?;
                                                  var transform : float3x4;
                                                  var encounter_jump_quest_node_rendinst_recovering__speed : float&;
                                                  var encounter_jump_quest_node_rendinst__state : int&;
                                                  var encounter_jump_quest_node_rendinst_recovering__progress : float&;
                                                  var encounter_jump_quest_node_rendinst_recovering__fromPos : float3&;
                                                  var encounter_jump_quest_node_rendinst_recovering__fromRot : float4&)
  if encounter_jump_quest_node_rendinst__state == int(EncounterJumpQuestNodeRendinstState.PREPARING_TO_RECOVERING)
    if act.curTime >= encounter_jump_quest_node_rendinst_recovering__recoveringAt
      encounter_jump_quest_node_rendinst__state = int(EncounterJumpQuestNodeRendinstState.RECOVERING)
      let posXZ = transform[3].xz
      let groundY = traceht_lmesh(posXZ)
      if transform[3].y < groundY
        transform[3].y = groundY
      encounter_jump_quest_node_rendinst_recovering__fromPos = transform[3]
      encounter_jump_quest_node_rendinst_recovering__fromRot = float4(DagorMath::quat(transform))
      encounter_jump_quest_node_rendinst_recovering__speed = rnd_float(encounter_jump_quest_node_rendinst_recovering__speedRng)
  elif encounter_jump_quest_node_rendinst__state == int(EncounterJumpQuestNodeRendinstState.RECOVERING)
    encounter_jump_quest_node_rendinst_recovering__progress += encounter_jump_quest_node_rendinst_recovering__speed * act.dt
    if encounter_jump_quest_node_rendinst_recovering__progress >= 1.0
      encounter_jump_quest_node_rendinst_recovering__progress = 1.0
      encounter_jump_quest_node_rendinst__state = int(EncounterJumpQuestNodeRendinstState.NONE)
      removeSubTemplate(eid, "encounter_jump_quest_node_rendinst_recovering")

    let targetPos = encounter_jump_quest_node_rendinst__positionTransform[3]
    var targetRot = DagorMath::quat(encounter_jump_quest_node_rendinst__positionTransform)

    if encounter_jump_quest_rendinst_rotor__startAngle != null && encounter_jump_quest_rendinst_rotor__rotSpeed != null
      targetRot = get_encounter_jump_quest_rendinst_rotor_rotation(act.curTime,
                                                                   *encounter_jump_quest_rendinst_rotor__startAngle,
                                                                   *encounter_jump_quest_rendinst_rotor__rotSpeed)

    let smoothT = inOutBezier(encounter_jump_quest_node_rendinst_recovering__progress)
    let pos = lerp(encounter_jump_quest_node_rendinst_recovering__fromPos, targetPos, float3(smoothT))
    let rot = slerp(DagorMath::quat(encounter_jump_quest_node_rendinst_recovering__fromRot), targetRot, smoothT)

    make_tm(rot, pos, transform)


[soa_es, es(tag=server, no_order)]
def encounter_jump_quest_recover(act : UpdateStageInfoAct;
                                 transform aka jump_quest_transform : float3x4;
                                 encounter_jump_quest__coreEid : EntityId;
                                 encounter_jump_quest__nodes : EncounterJumpQuestNode_SOA;
                                 encounter_jump_quest__playerMinMaxDistanceToRecover : float2;
                                 var encounter_jump_quest__recoverAt : float&)
  if encounter_jump_quest__recoverAt == 0.0 || act.curTime < encounter_jump_quest__recoverAt
    return

  let minDistSq = square(encounter_jump_quest__playerMinMaxDistanceToRecover.x)
  let maxDistSq = square(encounter_jump_quest__playerMinMaxDistanceToRecover.y)

  var recoverAvailable = false
  find_query() <| $ [es(REQUIRE=possessedByPlr)] (transform aka hero_transform : float3x4)
    let distSq = distance_sq(jump_quest_transform[3], hero_transform[3])
    if distSq < minDistSq
      recoverAvailable = false
      return true
    elif distSq < maxDistSq
      recoverAvailable = true

    return false

  if !recoverAvailable
    encounter_jump_quest__recoverAt = act.curTime + 5.0
    return

  encounter_jump_quest__recoverAt = 0.0

  recover_jump_nodes_tree(encounter_jump_quest__coreEid,
                          encounter_jump_quest__nodes)


[es(tag=server, on_appear)]
def encounter_jump_quest_earthshake_init(evt : Event;
                                         var encounter_jump_quest_earthshake__startAt : float&)
  encounter_jump_quest_earthshake__startAt = get_sync_time()


[es(tag=server, no_order)]
def encounter_jump_quest_earthshake_update_server(act : UpdateStageInfoAct;
                                                  eid : EntityId;
                                                  encounter_jump_quest_earthshake__startAt : float;
                                                  encounter_jump_quest_earthshake__time : float)
  let endAt = encounter_jump_quest_earthshake__startAt + encounter_jump_quest_earthshake__time
  if act.curTime >= endAt
    destroyEntity(eid)


[es(tag=server, REQUIRE=human)]
def encounter_jump_quest_node_rendinst_phys_human_contact(evt : EventOnCollision;
                                                          eid aka human_eid : EntityId;
                                                          human_net_phys : HumanActor;
                                                          hitpoints__hp : float)
  query(evt.offender) <| $ [es(REQUIRE=encounter_jump_quest_node_rendinst_phys)] (phys_obj_net_phys : PhysObjActor;
                                                                                  encounter_jump_quest_node_rendinst_phys__collisionDamageSpeedThreshold : float;
                                                                                  encounter_jump_quest_node_rendinst_phys__collisionDamageDotThreshold : float;
                                                                                  encounter_jump_quest_node_rendinst_phys__collisionDamageMult : float)
    let rendinstVel = evt.cvel
    let rendinstSpeed = length(rendinstVel)
    if rendinstSpeed <= encounter_jump_quest_node_rendinst_phys__collisionDamageSpeedThreshold
      return

    let rendinstToHuman = float3(human_net_phys.phys.currentState.location.P) - evt.pos
    let d = dot(normalize(rendinstVel), normalize(rendinstToHuman))
    if d < encounter_jump_quest_node_rendinst_phys__collisionDamageDotThreshold
      return

    assume collisionDamageMult = encounter_jump_quest_node_rendinst_phys__collisionDamageMult
    let speedKoef = rendinstSpeed * phys_obj_net_phys.phys.mass * collisionDamageMult
    var dmg = speedKoef * d
    let maxDmgPercent = evt.damage
    if maxDmgPercent >= 0.0
      dmg = min(dmg, hitpoints__hp * maxDmgPercent)
    if dmg <= 0.0
      return

    let dmDesc = DamageDesc(DamageType.DM_COLLISION, dmg, evt.pos, -evt.cvel)
    apply_damage(human_eid, evt.offender, dmDesc)


[soa_es, es(tag=server)]
def encounter_jump_quest_gravity_controller_generate(evt : EventJumpNodeTreeGenerated;
                                                     eid : EntityId;
                                                     encounter_jump_quest_gravity_controller__gravitySphereTemplate : string;
                                                     var encounter_jump_quest__nodes : EncounterJumpQuestNode_SOA;
                                                     var encounter_jump_quest__entities : EidList;
                                                     var encounter_jump_quest_gravity_controller__gravitySphereEids : EidList)
  let gravitySphereTemplate = getTemplateByName(encounter_jump_quest_gravity_controller__gravitySphereTemplate)
  if gravitySphereTemplate == null
    logerr("{eid}<{getEntityTemplateName(eid)}>: Undefined gravitySphereTemplate='{encounter_jump_quest_gravity_controller__gravitySphereTemplate}'!")
    return

  let gravitySphereRadius = getTemplateComponent(*gravitySphereTemplate, "sphere_zone__radius") ?? 0.0
  if gravitySphereRadius <= 0.0
    logerr("{eid}<{getEntityTemplateName(eid)}>: invalid gravitySphereRadius='{gravitySphereRadius}'!")
    return

  let gravitySphereRadiusSq = square(gravitySphereRadius)

  var gravitySpherePoints : array<float3>

  for nodeIdx, node in iter_range(encounter_jump_quest__nodes), encounter_jump_quest__nodes
    let nodeType = node.encounter_jump_quest__nodes__type
    let nodePoint = node.encounter_jump_quest__nodes__collisionTm[3]

    var isValidPoint = true
    if nodeType != int(EncounterJumpQuestNodeType.TOP_PLATFORM)
      for point in gravitySpherePoints
        let distSq = distance_sq(point, nodePoint)
        if distSq <= gravitySphereRadiusSq
          isValidPoint = false
          break

    if isValidPoint
      let sphereEid = createEntity(encounter_jump_quest_gravity_controller__gravitySphereTemplate) <| $(var init : ComponentsInitializer)
        var tm = IDENT_TM
        tm[3] = nodePoint
        init |> set("transform", tm)
        init |> set("encounter_jump_quest_gravity_sphere__jumpQuestEid", eid)
        init |> set("encounter_jump_quest_gravity_sphere__nodeIndex", nodeIdx)

      node.encounter_jump_quest__nodes__flags |= int(EncounterJumpQuestNodeFlags.GRAVITY_SPHERE_NODE)

      gravitySpherePoints |> push(nodePoint)
      encounter_jump_quest__entities |> push(sphereEid)
      encounter_jump_quest_gravity_controller__gravitySphereEids |> push(sphereEid)