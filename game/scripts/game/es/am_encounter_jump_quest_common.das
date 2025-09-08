module am_encounter_jump_quest_common shared
require app
require ecs
require ecs.safe
require ecs.soa_template
require math.base
require math.random
require game.events.events_active_matter
require DagorMath
require DagorRandom
require DagorSystem
require Dacoll


enum EncounterJumpQuestNodeType
  PATH
  TOP_PLATFORM
  DECOR


enum EncounterJumpQuestNodeFlags
  LOOT_NODE = 0x1
  GRAVITY_SPHERE_NODE = 0x2


[soa_template]
struct EncounterJumpQuestNode
  encounter_jump_quest__nodes__type : int
  encounter_jump_quest__nodes__collisionTm : float3x4
  encounter_jump_quest__nodes__rendinstIdx : int
  encounter_jump_quest__nodes__rendinstEid : EntityId
  encounter_jump_quest__nodes__rendinstMinMaxBoundingRadius : float2
  encounter_jump_quest__nodes__flags : int
  encounter_jump_quest__nodes__treeDepth : int


enum EncounterJumpQuestNodeRendinstState
  NONE
  PREPARING_TO_DEMOLITION
  DEMOLITION
  DEBRIS
  PREPARING_TO_RECOVERING
  RECOVERING


[soa_template]
struct EncounterJumpQuestEnemy
  encounter_jump_quest_core_ai__enemies__eid : EntityId
  encounter_jump_quest_core_ai__enemies__alarmTime : float


enum EncounterJumpQuestCoreProjectileState
  NONE
  MOVE_TO_IDLE_ORBIT
  IDLE
  MOVE_INSIDE_CORE
  TRACKING_ENEMY
  CHARGING_TO_RAM
  RAM_ENEMY
  RAM_BOUNCE


def get_jump_node_human_stand_height()
  return 3.5

def get_jump_node_human_stand_tm(pos : float3)
  var humanStandTm = IDENT_TM
  let humanStandRadius = 0.75
  let humanStandHeight = get_jump_node_human_stand_height()
  humanStandTm[0][0] = humanStandRadius * 2.0
  humanStandTm[1][1] = humanStandHeight
  humanStandTm[2][2] = humanStandRadius * 2.0
  humanStandTm[3] = pos + float3(0.0, humanStandHeight * 0.5, 0.0)
  return humanStandTm


def test_box_jump_volume_collision(collision_tm : float3x4)
  var haveCollision = true

  let mask = int(PhysLayer.EPL_ALL) & ~int(PhysLayer.EPL_CHARACTER)
  test_box_collision_world(collision_tm, -1, PhysLayer.EPL_DEFAULT, mask) <| $(contacts : array<CollisionContactData>#)
    haveCollision = length(contacts) > 0
  if haveCollision
    return true

  dacoll_use_box_collision() <| $(var coll : CollisionObject)
    dacoll_set_collision_object_tm(coll, collision_tm)
    haveCollision = test_collision_ri(coll, IDENT_BBOX)
  if haveCollision
    return true

  return false


[soa_def]
def is_jump_volume_valid(collision_tm : float3x4;
                         bounding_radius : float;
                         encounter_jump_quest__nodes : EncounterJumpQuestNode_SOA)
  let posXZ = collision_tm[3].xz
  let groundY = traceht_lmesh(posXZ)
  if collision_tm[3].y < groundY
    return false

  if test_box_jump_volume_collision(collision_tm)
    return false

  let tmTopPoint = get_jump_node_top_point(collision_tm)
  var humanStandTm = get_jump_node_human_stand_tm(tmTopPoint)

  if test_box_jump_volume_collision(humanStandTm)
    return false

  var valid = true

  let baseBoundingRadius = get_jump_node_human_stand_height() + bounding_radius
  let topPointStandOffset = float3(0.0, get_jump_node_human_stand_height() * 0.5, 0.0)

  let nodesCount = length(encounter_jump_quest__nodes)
  for nodeIdx in range(nodesCount)
    let reverseIdx = nodesCount - nodeIdx - 1
    let nodeBoundingRadiusMax = encounter_jump_quest__nodes[reverseIdx].encounter_jump_quest__nodes__rendinstMinMaxBoundingRadius.y
    let nodeCollisionTm = encounter_jump_quest__nodes[reverseIdx].encounter_jump_quest__nodes__collisionTm
    let boundingRadiusSq = square(nodeBoundingRadiusMax + baseBoundingRadius)
    if distance_sq(collision_tm[3], nodeCollisionTm[3]) >= boundingRadiusSq
      continue
    if check_bbox3_intersection(IDENT_BBOX, collision_tm, IDENT_BBOX, nodeCollisionTm)
      valid = false
      break
    let topPoint = get_jump_node_top_point(nodeCollisionTm)
    humanStandTm[3] = topPoint + topPointStandOffset
    if check_bbox3_intersection(IDENT_BBOX, collision_tm, IDENT_BBOX, humanStandTm)
      valid = false
      break
  return valid


[soa_def]
def test_volume_jump_nodes_collision(collision_tm : float3x4;
                                     bounding_radius : float;
                                     encounter_jump_quest__nodes : EncounterJumpQuestNode_SOA;
                                     ignore_index : int = -1)
  var haveCollision = false

  for nodeIdx in iter_range(encounter_jump_quest__nodes)
    if nodeIdx == ignore_index
      continue

    let nodeBoundingRadiusMax = encounter_jump_quest__nodes[nodeIdx].encounter_jump_quest__nodes__rendinstMinMaxBoundingRadius.y
    let nodeCollisionTm = encounter_jump_quest__nodes[nodeIdx].encounter_jump_quest__nodes__collisionTm
    let boundingRadiusSq = square(nodeBoundingRadiusMax + bounding_radius)
    if distance_sq(collision_tm[3], nodeCollisionTm[3]) >= boundingRadiusSq
      continue
    if check_bbox3_intersection(IDENT_BBOX, collision_tm, IDENT_BBOX, nodeCollisionTm)
      haveCollision = true
      break
  return haveCollision


[soa_def]
def is_jump_volume_valid_with_links_check(collision_tm : float3x4;
                                          bounding_radius : float;
                                          horizontal_offset_max : float;
                                          encounter_jump_quest__nodes : EncounterJumpQuestNode_SOA;
                                          encounter_jump_quest__nodeLinks : IPoint2List)
  if !is_jump_volume_valid(collision_tm, bounding_radius, encounter_jump_quest__nodes)
    return false

  let maxLinkOffsetSq = square(bounding_radius + horizontal_offset_max)
  for link in encounter_jump_quest__nodeLinks
    let tm0 = encounter_jump_quest__nodes[link.x].encounter_jump_quest__nodes__collisionTm
    let tm1 = encounter_jump_quest__nodes[link.y].encounter_jump_quest__nodes__collisionTm
    let topPoint0 = get_jump_node_top_point(tm0)
    let topPoint1 = get_jump_node_top_point(tm1)
    let centerLinkPoint = (topPoint0 + topPoint1) * 0.5
    if distance_sq(collision_tm[3], centerLinkPoint) < maxLinkOffsetSq
      return false

  return true


def get_jump_node_top_point(collision_tm : float3x4)
  return collision_tm[3] + collision_tm[1] * 0.5


[soa_def]
def push_jump_volume(var encounter_jump_quest__nodes : EncounterJumpQuestNode_SOA;
                     node_type : EncounterJumpQuestNodeType;
                     collision_tm : float3x4;
                     rendinst_idx : int;
                     bounding_radius_min : float;
                     bounding_radius_max : float;
                     tree_depth : int)
  encounter_jump_quest__nodes |> push() <| EncounterJumpQuestNode(
    encounter_jump_quest__nodes__type = int(node_type),
    encounter_jump_quest__nodes__collisionTm = collision_tm,
    encounter_jump_quest__nodes__rendinstIdx = rendinst_idx,
    encounter_jump_quest__nodes__rendinstMinMaxBoundingRadius = float2(bounding_radius_min, bounding_radius_max),
    encounter_jump_quest__nodes__treeDepth = tree_depth)


[soa_def]
def destroy_jump_node_rendinsts(encounter_jump_quest__nodes : EncounterJumpQuestNode_SOA)
  for node in encounter_jump_quest__nodes
    destroyEntity(node.encounter_jump_quest__nodes__rendinstEid)


[soa_def]
def select_jump_node_rendinst_data(node_type : int;
                                   rendinst_index : int;
                                   encounter_jump_quest__pathRendinsts : Array;
                                   encounter_jump_quest__topPlatformRendinsts : Array;
                                   encounter_jump_quest__decorRendinsts : Array;
                                   cb : block<(rendinst_data : Object) : void>)
  if node_type == int(EncounterJumpQuestNodeType.PATH)
    invoke(cb, *(encounter_jump_quest__pathRendinsts[rendinst_index] as Object))
  elif node_type == int(EncounterJumpQuestNodeType.TOP_PLATFORM)
    invoke(cb, *(encounter_jump_quest__topPlatformRendinsts[rendinst_index] as Object))
  elif node_type == int(EncounterJumpQuestNodeType.DECOR)
    invoke(cb, *(encounter_jump_quest__decorRendinsts[rendinst_index] as Object))
  else
    logerr("get_jump_node_rendinst_data: unsupported nodeType={node_type}!")


[soa_def]
def create_jump_node_rendinsts(jump_quest_eid : EntityId;
                               root_pos : float3;
                               encounter_jump_quest__pathRendinsts : Array;
                               encounter_jump_quest__pathRendinstLevitationChance : float;
                               encounter_jump_quest__topPlatformRendinsts : Array;
                               encounter_jump_quest__decorRendinsts : Array;
                               encounter_jump_quest__decorRendinstRotorChance : float;
                               encounter_jump_quest__decorRendinstLevitationChance : float;
                               var encounter_jump_quest__nodes : EncounterJumpQuestNode_SOA;
                               var sphere_zone__radius : float&)
  for nodeIdx, node in iter_range(encounter_jump_quest__nodes), encounter_jump_quest__nodes
    let nodeType = node.encounter_jump_quest__nodes__type
    let rendinstIdx = node.encounter_jump_quest__nodes__rendinstIdx
    select_jump_node_rendinst_data(nodeType, rendinstIdx,
                                   encounter_jump_quest__pathRendinsts,
                                   encounter_jump_quest__topPlatformRendinsts,
                                   encounter_jump_quest__decorRendinsts) <| $(rendinstData : Object)
      let collisionOffset = rendinstData.collisionOffset ?? float3(0.0, 0.0, 0.0)
      let collisionSize = rendinstData.collisionSize ?? float3(1.0, 1.0, 1.0)

      var rendinstTemplate = "encounter_jump_quest_node_rendinst"
      if nodeType == int(EncounterJumpQuestNodeType.DECOR)
        if gfrnd() <= encounter_jump_quest__decorRendinstRotorChance
          rendinstTemplate += "+encounter_jump_quest_rendinst_rotor"
        if gfrnd() <= encounter_jump_quest__decorRendinstLevitationChance
          rendinstTemplate += "+encounter_jump_quest_rendinst_levitation"
      if nodeType == int(EncounterJumpQuestNodeType.PATH)
        let isLootNode = (node.encounter_jump_quest__nodes__flags & int(EncounterJumpQuestNodeFlags.LOOT_NODE)) != 0
        if !isLootNode
          if gfrnd() <= encounter_jump_quest__pathRendinstLevitationChance
            var sagginTm = node.encounter_jump_quest__nodes__collisionTm
            let MAX_SAGGIN_OFFSET = 0.5
            sagginTm[3].y -= MAX_SAGGIN_OFFSET
            if !test_box_jump_volume_collision(sagginTm) && !test_volume_jump_nodes_collision(sagginTm,
                                                                                              node.encounter_jump_quest__nodes__rendinstMinMaxBoundingRadius.y,
                                                                                              encounter_jump_quest__nodes,
                                                                                              nodeIdx)
              rendinstTemplate += "+encounter_jump_quest_path_rendinst_levitation"

      node.encounter_jump_quest__nodes__rendinstEid = createEntity(rendinstTemplate) <| $(var init)
        var tm = node.encounter_jump_quest__nodes__collisionTm
        tm |> orthonormalize()
        tm[3] += rotate(tm, collisionOffset)
        set(init, "transform", tm)
        set(init, "encounter_jump_quest_node_rendinst__jumpQuestEid", jump_quest_eid)
        set(init, "encounter_jump_quest_node_rendinst__nodeIndex", nodeIdx)
        set(init, "encounter_jump_quest_node_rendinst__treeDepth", node.encounter_jump_quest__nodes__treeDepth)
        set(init, "encounter_jump_quest_node_rendinst__positionTransform", tm)
        set(init, "encounter_jump_quest_node_rendinst__volume", collisionSize.x * collisionSize.y * collisionSize.z)
        set(init, "ri_extra__name", rendinstData.rendinst ?? "")
        set(init, "collres__res", rendinstData.collres__res ?? "")
        set(init, "phys_obj_net_phys__blk", rendinstData.phys_obj_net_phys__blk ?? "")

      sphere_zone__radius = max(sphere_zone__radius,
                                distance(root_pos, node.encounter_jump_quest__nodes__collisionTm[3]) +
                                node.encounter_jump_quest__nodes__rendinstMinMaxBoundingRadius.y)


[soa_def]
def generate_jump_nodes_branch(root_node_idx : int;
                               limit_y : float;
                               limit_nodes_count : int;
                               root_pos : float3;
                               encounter_jump_quest__pathRendinsts : Array;
                               encounter_jump_quest__rendinstRollDegrees : float;
                               encounter_jump_quest__horizontalOffsetRnd : float2;
                               encounter_jump_quest__verticalOffsetRnd : float2;
                               create_node_attempts : int;
                               var encounter_jump_quest__nodes : EncounterJumpQuestNode_SOA;
                               var encounter_jump_quest__nodeLinks : IPoint2List)
  let rendinstsCount = length(encounter_jump_quest__pathRendinsts)

  assume horizontalOffsetRnd = encounter_jump_quest__horizontalOffsetRnd
  assume verticalOffsetRnd = encounter_jump_quest__verticalOffsetRnd

  var createdNodesCount = 0

  var attachToNodeIdx = -1

  var fallbackEnabled = false

  var currentPosLS : float3
  if root_node_idx == -1
    // Trunk
    let startY = 2.0
    currentPosLS = float3(0.0, startY, 0.0)
    fallbackEnabled = true
  else
    assume tm = encounter_jump_quest__nodes[root_node_idx].encounter_jump_quest__nodes__collisionTm
    currentPosLS = tm[3] - root_pos
    attachToNodeIdx = root_node_idx

  var nodeGenerationLoopFails = 0

  while currentPosLS.y < limit_y && createdNodesCount < limit_nodes_count
    currentPosLS.y += rnd_float(verticalOffsetRnd)

    var horizontalAngle : float
    if root_node_idx == -1 && currentPosLS.x != 0.0 && currentPosLS.z != 0.0 && gfrnd() < 0.5
      // Bend the trunk to the center
      let horizontalToCenter = -float2(currentPosLS.x, currentPosLS.z)
      let horizontalToCenterLengthSq = length_sq(horizontalToCenter)
      if horizontalToCenterLengthSq > 1e-3
        let horizontalDirToCenter = horizontalToCenter / sqrt(horizontalToCenterLengthSq)
        let d = clamp(dot(float2(1, 0), horizontalDirToCenter), -1.0, 1.0)
        horizontalAngle = (horizontalDirToCenter.y >= 0.0 ? 1.0 : -1.0) * acos(d)
        if horizontalToCenterLengthSq <= square(20.0)
          horizontalAngle += PI
      else
        horizontalAngle = gfrnd() * TWOPI
    else
      horizontalAngle = gfrnd() * TWOPI

    var nodePlaced = false
    for attemptNum in range(create_node_attempts)
      var horizontalDir : float2
      sincos(horizontalAngle, horizontalDir.y, horizontalDir.x)

      let tooDifficultToPlace = attemptNum > (create_node_attempts / 2)

      var horizontalOffset : float2
      if tooDifficultToPlace
        horizontalOffset = horizontalDir * horizontalOffsetRnd.y
      else
        horizontalOffset = horizontalDir * rnd_float(horizontalOffsetRnd)

      let newPosLS = currentPosLS + float3(horizontalOffset.x, 0.0, horizontalOffset.y)
      let newPosWS = root_pos + newPosLS

      let rendinstIdx = grnd() % rendinstsCount
      let rendinstData = encounter_jump_quest__pathRendinsts[rendinstIdx] as Object
      let collisionSize = rendinstData?.collisionSize ?? float3(1.0, 1.0, 1.0)

      assume rollDegrees = encounter_jump_quest__rendinstRollDegrees

      var tm : float3x4
      var q : quat
      euler_to_quat(gfrnd() * TWOPI,
                    deg_to_rad(rnd_float(-rollDegrees, rollDegrees)),
                    deg_to_rad(rnd_float(-rollDegrees, rollDegrees)),
                    q)
      make_tm(q, newPosWS - float3(0.0, collisionSize.y * 0.5, 0.0), tm)

      tm = tm * scale_tm(collisionSize)

      let boundingRadiusMin = min(collisionSize.x, collisionSize.z) * 0.5
      let boundingRadiusMax = max(max(collisionSize.x, collisionSize.y), collisionSize.z) * 0.5 * 1.414

      if is_jump_volume_valid(tm, boundingRadiusMax, encounter_jump_quest__nodes)
        let newNodeIdx = length(encounter_jump_quest__nodes)
        let treeDepth = (attachToNodeIdx != -1 ? encounter_jump_quest__nodes[attachToNodeIdx].encounter_jump_quest__nodes__treeDepth + 1
                                               : 0)
        encounter_jump_quest__nodes |> push_jump_volume(EncounterJumpQuestNodeType.PATH, tm, rendinstIdx,
                                                        boundingRadiusMin, boundingRadiusMax, treeDepth)
        if attachToNodeIdx != -1
          encounter_jump_quest__nodeLinks |> push(int2(attachToNodeIdx, newNodeIdx))
        attachToNodeIdx = newNodeIdx
        currentPosLS = newPosLS
        createdNodesCount++
        nodePlaced = true
        nodeGenerationLoopFails = 0
        break
      else
        horizontalAngle += PI * 2.0 / float(create_node_attempts)

    if !nodePlaced
      ++nodeGenerationLoopFails
      if nodeGenerationLoopFails >= 3
        // Dead end
        if fallbackEnabled
          if attachToNodeIdx == -1 || nodeGenerationLoopFails >= 15
            return false
          else
            // Fallback
            attachToNodeIdx = max(attachToNodeIdx - 3, 0)
            let tm = encounter_jump_quest__nodes[attachToNodeIdx].encounter_jump_quest__nodes__collisionTm
            currentPosLS = tm[3] - root_pos
        else
          return false
  return true


[soa_def]
def generate_jump_nodes_top_platform(encounter_jump_quest__topPlatformRendinsts : Array;
                                     attach_to_node_idx : int;
                                     horizontal_offset_max : float;
                                     encounter_jump_quest__verticalOffsetRnd : float2;
                                     var encounter_jump_quest__nodes : EncounterJumpQuestNode_SOA;
                                     var encounter_jump_quest__nodeLinks : IPoint2List)
  let attachToNodeTm = encounter_jump_quest__nodes[attach_to_node_idx].encounter_jump_quest__nodes__collisionTm
  let attachToNodePos = attachToNodeTm[3]
  let attachToNodeTopPoint = get_jump_node_top_point(attachToNodeTm)
  let attachToNodeHumanStandTm = get_jump_node_human_stand_tm(attachToNodeTopPoint)

  assume verticalOffsetRnd = encounter_jump_quest__verticalOffsetRnd

  let rendinstsCount = length(encounter_jump_quest__topPlatformRendinsts)

  var horizontalAngle : float
  var attempts = 0
  let attemptsToFail = 16

  while attempts < attemptsToFail
    var horizontalDir : float2
    sincos(horizontalAngle, horizontalDir.y, horizontalDir.x)

    let rendinstIdx = grnd() % rendinstsCount
    let rendinstData = encounter_jump_quest__topPlatformRendinsts[rendinstIdx] as Object
    let collisionSize = rendinstData?.collisionSize ?? float3(1.0, 1.0, 1.0)
    let boundingRadiusMin = min(collisionSize.x, collisionSize.z) * 0.5
    let boundingRadiusMax = max(max(collisionSize.x, collisionSize.y), collisionSize.z) * 0.5 * 1.414

    var tm : float3x4
    let scaleTM = scale_tm(collisionSize)

    var offsetValue = horizontal_offset_max
    var foundValidOffset = false
    while offsetValue < horizontal_offset_max * 2.0
      let horizontalOffset = horizontalDir * offsetValue

      let newPos = attachToNodePos + float3(horizontalOffset.x,
                                            rnd_float(verticalOffsetRnd),
                                            horizontalOffset.y)

      var q : quat
      euler_to_quat(gfrnd() * TWOPI,
                    deg_to_rad(rnd_float(-5.0, 5.0)),
                    deg_to_rad(rnd_float(-5.0, 5.0)),
                    q)
      make_tm(q, newPos - float3(0.0, collisionSize.y * 0.5, 0.0), tm)
      tm = tm * scaleTM

      if (check_bbox3_intersection(IDENT_BBOX, tm, IDENT_BBOX, attachToNodeTm) ||
         check_bbox3_intersection(IDENT_BBOX, tm, IDENT_BBOX, attachToNodeHumanStandTm))
        offsetValue += 0.5
      else
        foundValidOffset = true
        break

    if foundValidOffset && is_jump_volume_valid(tm, boundingRadiusMax, encounter_jump_quest__nodes)
      let newNodeIdx = length(encounter_jump_quest__nodes)
      let treeDepth = encounter_jump_quest__nodes[attach_to_node_idx].encounter_jump_quest__nodes__treeDepth + 1
      encounter_jump_quest__nodes |> push_jump_volume(EncounterJumpQuestNodeType.TOP_PLATFORM, tm, rendinstIdx,
                                                      boundingRadiusMin, boundingRadiusMax, treeDepth)
      encounter_jump_quest__nodeLinks |> push(int2(attach_to_node_idx, newNodeIdx))
      return true
    else
      horizontalAngle += PI * 4.0 / float(attemptsToFail)
      attempts++

  return false


[soa_def]
def generate_decor_nodes(encounter_jump_quest__decorRendinsts : Array;
                         encounter_jump_quest__decorNodesCountRnd : int2;
                         encounter_jump_quest__decorOffsetRnd : float2;
                         horizontal_offset_max : float;
                         encounter_jump_quest__nodeLinks : IPoint2List;
                         var encounter_jump_quest__nodes : EncounterJumpQuestNode_SOA)
  let decorCount = rnd_int(encounter_jump_quest__decorNodesCountRnd)
  let pathNodesCount = length(encounter_jump_quest__nodes)
  let rendinstsCount = length(encounter_jump_quest__decorRendinsts)

  var decorGeneratedCount = 0
  var decorGenerationFails = 0
  while decorGeneratedCount < decorCount && decorGenerationFails < 50
    let offsetValue = rnd_float(encounter_jump_quest__decorOffsetRnd)
    let rndDir = normalize(float3(gfrnd() - 0.5, gfrnd() - 0.5, gfrnd() - 0.5))

    let offset = rndDir * offsetValue

    let pathNodeIdx = grnd() % pathNodesCount
    let pathNodePos = encounter_jump_quest__nodes[pathNodeIdx].encounter_jump_quest__nodes__collisionTm[3]

    let decorNodePos = pathNodePos + offset

    let rendinstIdx = grnd() % rendinstsCount
    let rendinstData = encounter_jump_quest__decorRendinsts[rendinstIdx] as Object
    let collisionSize = rendinstData?.collisionSize ?? float3(1.0, 1.0, 1.0)

    var tm : float3x4
    var q : quat
    euler_to_quat(gfrnd() * TWOPI,
                  gfrnd() * TWOPI,
                  gfrnd() * TWOPI,
                  q)
    make_tm(q, decorNodePos - float3(0.0, collisionSize.y * 0.5, 0.0), tm)

    tm = tm * scale_tm(collisionSize)

    let boundingRadiusMin = min(collisionSize.x, collisionSize.z) * 0.5
    let boundingRadiusMax = max(max(collisionSize.x, collisionSize.y), collisionSize.z) * 0.5 * 1.414

    if is_jump_volume_valid_with_links_check(tm, boundingRadiusMax, horizontal_offset_max,
                                             encounter_jump_quest__nodes, encounter_jump_quest__nodeLinks)
      let treeDepth = rnd_int(5, 65)
      encounter_jump_quest__nodes |> push_jump_volume(EncounterJumpQuestNodeType.DECOR, tm, rendinstIdx,
                                                      boundingRadiusMin, boundingRadiusMax, treeDepth)
      ++decorGeneratedCount
      decorGenerationFails = 0
    else
      ++decorGenerationFails


[soa_def]
def generate_jump_nodes_tree(jump_quest_eid : EntityId)
  var result = false
  query(jump_quest_eid) <| $ [soa_blk, es] (transform aka jump_quest_transform : float3x4;
                                            encounter_jump_quest__rendinstRollDegrees : float;
                                            encounter_jump_quest__horizontalOffsetRnd : float2;
                                            encounter_jump_quest__verticalOffsetRnd : float2;
                                            encounter_jump_quest__heightRnd : float2;
                                            encounter_jump_quest__branchesCountRnd : int2;
                                            encounter_jump_quest__branchNodesCountRnd : int2;
                                            encounter_jump_quest__trunkNodesLimit : int;
                                            encounter_jump_quest__trunkCreateNodeAttempts : int;
                                            encounter_jump_quest__branchCreateNodeAttempts : int;
                                            encounter_jump_quest__activeMatterOnStepsRnd : int2;
                                            encounter_jump_quest__amCoreTemplate : string;
                                            encounter_jump_quest__decorNodesCountRnd : int2;
                                            encounter_jump_quest__decorOffsetRnd : float2;
                                            encounter_jump_quest__decorRendinstRotorChance : float;
                                            encounter_jump_quest__decorRendinstLevitationChance : float;
                                            encounter_jump_quest__pathRendinstLevitationChance : float;
                                            encounter_jump_quest__pathRendinsts : Array;
                                            encounter_jump_quest__topPlatformRendinsts : Array;
                                            encounter_jump_quest__decorRendinsts : Array;
                                            var encounter_jump_quest__nodes : EncounterJumpQuestNode_SOA;
                                            var encounter_jump_quest__nodeLinks : IPoint2List;
                                            var encounter_jump_quest__entities : EidList;
                                            var sphere_zone__radius : float&;
                                            var encounter_jump_quest__radiusSq : float&;
                                            var encounter_jump_quest__coreEid : EntityId&)
    let root_pos = jump_quest_transform[3]

    let attempts = 3
    for _ in range(attempts)
      destroy_jump_node_rendinsts(encounter_jump_quest__nodes)

      encounter_jump_quest__nodes |> clear()
      encounter_jump_quest__nodeLinks |> clear()

      for eid in encounter_jump_quest__entities
        destroyEntity(eid)
      encounter_jump_quest__entities |> clear()

      sphere_zone__radius = 1.0
      encounter_jump_quest__radiusSq = 1.0

      assume branchNodesCountRnd = encounter_jump_quest__branchNodesCountRnd

      let treeHeight = rnd_float(encounter_jump_quest__heightRnd)
      let branchesCount = rnd_int(encounter_jump_quest__branchesCountRnd)

      // Trunk
      if generate_jump_nodes_branch(/*root_node_idx*/ -1,
                                    treeHeight,
                                    encounter_jump_quest__trunkNodesLimit,
                                    root_pos,
                                    encounter_jump_quest__pathRendinsts,
                                    encounter_jump_quest__rendinstRollDegrees,
                                    encounter_jump_quest__horizontalOffsetRnd,
                                    encounter_jump_quest__verticalOffsetRnd,
                                    encounter_jump_quest__trunkCreateNodeAttempts,
                                    encounter_jump_quest__nodes,
                                    encounter_jump_quest__nodeLinks)

        // Top platform
        if generate_jump_nodes_top_platform(encounter_jump_quest__topPlatformRendinsts,
                                            length(encounter_jump_quest__nodes) - 1,
                                            encounter_jump_quest__horizontalOffsetRnd.y,
                                            encounter_jump_quest__verticalOffsetRnd,
                                            encounter_jump_quest__nodes,
                                            encounter_jump_quest__nodeLinks)
          let trunkNodesCount = length(encounter_jump_quest__nodes)
          let topPlatformNodeIdx = trunkNodesCount - 1
          let topPlatformNodeTm = encounter_jump_quest__nodes[topPlatformNodeIdx].encounter_jump_quest__nodes__collisionTm
          let topPlatformTopPoint = get_jump_node_top_point(topPlatformNodeTm)

          // Branches
          var branchTopNodeIndices : array<int>
          let nodesPerTrunkSegment = trunkNodesCount / (branchesCount + 1)
          for b in range(branchesCount)
            let trunkNodeIdx = b * nodesPerTrunkSegment + grnd() % nodesPerTrunkSegment
            if generate_jump_nodes_branch(trunkNodeIdx,
                                          treeHeight,
                                          rnd_int(branchNodesCountRnd),
                                          root_pos,
                                          encounter_jump_quest__pathRendinsts,
                                          encounter_jump_quest__rendinstRollDegrees,
                                          encounter_jump_quest__horizontalOffsetRnd,
                                          encounter_jump_quest__verticalOffsetRnd,
                                          encounter_jump_quest__branchCreateNodeAttempts,
                                          encounter_jump_quest__nodes,
                                          encounter_jump_quest__nodeLinks)
              let branchTopNodeIdx = length(encounter_jump_quest__nodes) - 1
              branchTopNodeIndices |> push(branchTopNodeIdx)

          // Gather simple step nodes
          var stepNodeIndices : array<int>
          for i in iter_range(encounter_jump_quest__nodes)
            if i != topPlatformNodeIdx && !has_value(branchTopNodeIndices, i)
              stepNodeIndices |> push(i)
          let stepNodeIndicesCount = length(stepNodeIndices)

          // Decor
          generate_decor_nodes(encounter_jump_quest__decorRendinsts,
                              encounter_jump_quest__decorNodesCountRnd,
                              encounter_jump_quest__decorOffsetRnd,
                              encounter_jump_quest__horizontalOffsetRnd.y,
                              encounter_jump_quest__nodeLinks,
                              encounter_jump_quest__nodes)

          // Create active matter on the ends of the branches
          for branchTopNodeIdx in branchTopNodeIndices
            let branchTopNodeTm = encounter_jump_quest__nodes[branchTopNodeIdx].encounter_jump_quest__nodes__collisionTm
            let branchTopNodeTmTopPoint = get_jump_node_top_point(branchTopNodeTm)
            let branchTopNodeBoundingRadiusMin = encounter_jump_quest__nodes[branchTopNodeIdx].encounter_jump_quest__nodes__rendinstMinMaxBoundingRadius.x

            encounter_jump_quest__nodes[branchTopNodeIdx].encounter_jump_quest__nodes__flags |= int(EncounterJumpQuestNodeFlags.LOOT_NODE)

            let horizontalDir = rnd_dir2()
            let horizontalOffset = horizontalDir * (gfrnd() * branchTopNodeBoundingRadiusMin * 0.5)

            // TODO: Decide what will be generated here and move it into data
            let activeMatterEid  = createEntity("active_matter_pile+coin_item_count_5+item_in_world") <| $(init)
              var coinTm = IDENT_TM
              coinTm[3] = branchTopNodeTmTopPoint + float3(horizontalOffset.x, 0.0, horizontalOffset.y)
              init |> set("transform", coinTm)
            encounter_jump_quest__entities |> push(activeMatterEid)

          // Create active matter on the random step nodes
          for i in range(stepNodeIndicesCount)
            swap(stepNodeIndices[i], stepNodeIndices[(grnd() % stepNodeIndicesCount)])
          var activeMatterLeft = rnd_int(encounter_jump_quest__activeMatterOnStepsRnd)
          var activeMatterStepNodeNum = 0
          while activeMatterLeft > 0 && activeMatterStepNodeNum < stepNodeIndicesCount
            let stepNodeIdx = stepNodeIndices[activeMatterStepNodeNum]
            let stepNodeTm = encounter_jump_quest__nodes[stepNodeIdx].encounter_jump_quest__nodes__collisionTm
            let stepNodeTmTopPoint = get_jump_node_top_point(stepNodeTm)
            let stepNodeBoundingRadiusMin = encounter_jump_quest__nodes[stepNodeIdx].encounter_jump_quest__nodes__rendinstMinMaxBoundingRadius.x

            encounter_jump_quest__nodes[stepNodeIdx].encounter_jump_quest__nodes__flags |= int(EncounterJumpQuestNodeFlags.LOOT_NODE)

            let horizontalDir = rnd_dir2()
            let horizontalOffset = horizontalDir * (gfrnd() * stepNodeBoundingRadiusMin * 0.5)

            var coinTemplate : string

            // TODO: Decide what will be generated here and move it into data
            if grnd() % 8 == 0 && activeMatterLeft >= 2
              coinTemplate = "active_matter_pile+coin_item_count_2+item_in_world"
              activeMatterLeft -= 2
            else
              coinTemplate = "active_matter_pile+coin_item_count_1+item_in_world"
              activeMatterLeft -= 1

            let activeMatterEid  = createEntity(coinTemplate) <| $(init)
              var coinTm = IDENT_TM
              coinTm[3] = stepNodeTmTopPoint + float3(horizontalOffset.x, 0.0, horizontalOffset.y)
              init |> set("transform", coinTm)
            encounter_jump_quest__entities |> push(activeMatterEid)
            ++activeMatterStepNodeNum

          // Create all rendinsts
          create_jump_node_rendinsts(jump_quest_eid,
                                    root_pos,
                                    encounter_jump_quest__pathRendinsts,
                                    encounter_jump_quest__pathRendinstLevitationChance,
                                    encounter_jump_quest__topPlatformRendinsts,
                                    encounter_jump_quest__decorRendinsts,
                                    encounter_jump_quest__decorRendinstRotorChance,
                                    encounter_jump_quest__decorRendinstLevitationChance,
                                    encounter_jump_quest__nodes,
                                    sphere_zone__radius)

          // Create AM Core
          encounter_jump_quest__coreEid = createEntity(encounter_jump_quest__amCoreTemplate) <| $(init)
            var amCoreTm = IDENT_TM
            amCoreTm[3] = topPlatformTopPoint + float3(0.0, 3.5, 0.0)
            init |> set("transform", amCoreTm)
          encounter_jump_quest__entities |> push(encounter_jump_quest__coreEid)

          encounter_jump_quest__radiusSq = square(sphere_zone__radius)

          result = true
          return

    print("Failed to create jump nodes tree at {root_pos}")
    encounter_jump_quest__nodes |> clear()
    encounter_jump_quest__nodeLinks |> clear()

    sphere_zone__radius = 1.0
    encounter_jump_quest__radiusSq = 1.0

    return

  if result
    sendEvent(jump_quest_eid, EventJumpNodeTreeGenerated())

  return result


[soa_def]
def demolish_jump_nodes_tree(encounter_jump_quest__pathRendinsts : Array;
                             encounter_jump_quest__topPlatformRendinsts : Array;
                             encounter_jump_quest__decorRendinsts : Array;
                             encounter_jump_quest__coreEid : EntityId;
                             encounter_jump_quest__nodes : EncounterJumpQuestNode_SOA;
                             encounter_jump_quest__recoveringDelay : float2;
                             var encounter_jump_quest__recoverAt : float&)
  query(encounter_jump_quest__coreEid) <| $ [es] (var hitpoints__hp : float&)
    hitpoints__hp = 0.0

  encounter_jump_quest__recoverAt = get_sync_time() + rnd_float(encounter_jump_quest__recoveringDelay)

  for node in encounter_jump_quest__nodes
    let nodeType = node.encounter_jump_quest__nodes__type
    let rendinstIdx = node.encounter_jump_quest__nodes__rendinstIdx
    select_jump_node_rendinst_data(nodeType, rendinstIdx,
                                   encounter_jump_quest__pathRendinsts,
                                   encounter_jump_quest__topPlatformRendinsts,
                                   encounter_jump_quest__decorRendinsts) <| $(rendinstData : Object)
      let physObjNetPhysBlk = rendinstData.phys_obj_net_phys__blk ?? ""
      if physObjNetPhysBlk == ""
        return

      query(node.encounter_jump_quest__nodes__rendinstEid) <| $ [es] (var encounter_jump_quest_node_rendinst__state : int&)
        assume state = encounter_jump_quest_node_rendinst__state
        if state != int(EncounterJumpQuestNodeRendinstState.NONE)
          return

        state = int(EncounterJumpQuestNodeRendinstState.PREPARING_TO_DEMOLITION)


[soa_def]
def recover_jump_nodes_tree(encounter_jump_quest__coreEid : EntityId;
                            encounter_jump_quest__nodes : EncounterJumpQuestNode_SOA)
  query(encounter_jump_quest__coreEid) <| $ [es] (hitpoints__maxHp : float;
                                                  var hitpoints__hp : float&)
    hitpoints__hp = hitpoints__maxHp

  for node in encounter_jump_quest__nodes
    query(node.encounter_jump_quest__nodes__rendinstEid) <| $ [es] (var encounter_jump_quest_node_rendinst__state : int&)
      assume state = encounter_jump_quest_node_rendinst__state
      if state == int(EncounterJumpQuestNodeRendinstState.DEBRIS)
        state = int(EncounterJumpQuestNodeRendinstState.PREPARING_TO_RECOVERING)