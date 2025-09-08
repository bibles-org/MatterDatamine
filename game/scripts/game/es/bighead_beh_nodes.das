options always_export_initializer = true

require app
require ecs
require BehNodes
require math.base
require math.random
require DagorMath
require Grid
require PhysMat
require Dacoll
require DagorDataBlock
require ecs.soa_template
require game.es.bighead_common
require DagorSystem
require DngNet
require DagorSystem
require BehNodes


[soa_template]
struct BigheadVictims
  bighead_victims__eid : EntityId
  bighead_victims__lastSeen : float


[beh_node(name="bigheadChooseVictims")]
class BigheadChooseVictims : BehNodeAdapter
  def override update(dt : float) : EBehResult
    let bighead = beh_tree_eid(owner)
    var addedNewVictims = false
    let hasComponents = query(bighead) <| $ [soa_blk, es] (transform aka bighead_transform : float3x4;
                                                           bighead_victims__searchRadius : float;
                                                           var bigheadVictims : BigheadVictims_SOA)
      let now = get_sync_time()
      for_each_entity_in_grid(ecs_hash("humans"), BSphere3(transform[3], bighead_victims__searchRadius), GridEntCheck.BOUNDING) <| $(victimEid : EntityId)
        if has_value(bighead_victims__eid, victimEid)
          return
        query(victimEid) <| $ [es] (transform aka victim_transform : float3x4; isAlive : bool)
          if !isAlive
            return
          let direction = victim_transform[3] - bighead_transform[3]
          let len = length(direction)
          let mat = get_material_id("aiRay")
          let normalizedDirection = direction / len
          let visible = !rayhit_normalized(bighead_transform[3], normalizedDirection, len - 0.01, ETF_DEFAULT, mat)
          if visible
            addedNewVictims = true
            push(bigheadVictims, BigheadVictims(bighead_victims__eid = victimEid, bighead_victims__lastSeen = now))
    if !hasComponents
      logerr("bigheadChooseVictims: some required components are missing")
      return EBehResult.ER_FAILED
    return addedNewVictims ? EBehResult.ER_SUCCESS : EBehResult.ER_FAILED


[beh_node(name="bigheadUpdateVictims")]
class BigheadUpdateVictims : BehNodeAdapter
  def override update(dt : float) : EBehResult
    let bighead = beh_tree_eid(owner)
    query(bighead) <| $ [soa_blk, es] (transform aka bighead_transform : float3x4;
                                       bighead_victims__looseInterestAfter : float;
                                       bighead_victims__pursueRadius : float;
                                       var bigheadVictims : BigheadVictims_SOA)
      let now = get_sync_time()
      var indicesToRemove : array<int>
      for victim, idx in bigheadVictims, range(length(bigheadVictims))
        query(victim.bighead_victims__eid) <| $ [es] (transform aka victim_transform : float3x4; isAlive : bool)
          if !isAlive
            push(indicesToRemove, idx)
            return
          let direction = victim_transform[3] - bighead_transform[3]
          let len = length(direction)
          if len > bighead_victims__pursueRadius
            push(indicesToRemove, idx)
            return
          let mat = get_material_id("aiRay")
          let normalizedDirection = direction / len
          let visible = !rayhit_normalized(bighead_transform[3], normalizedDirection, len, ETF_DEFAULT, mat)
          if visible
            victim.bighead_victims__lastSeen = now
          elif now - victim.bighead_victims__lastSeen > bighead_victims__looseInterestAfter
            push(indicesToRemove, idx)
      var iidx = length(indicesToRemove) - 1
      while iidx >= 0
        erase(bigheadVictims, indicesToRemove[iidx])
        --iidx

    return EBehResult.ER_SUCCESS


[beh_node(name="bigHeadAttack")]
class BigHeadAttack : BehNodeAdapter
  objectsToThrow : int
  prepareTime : float

  def override loadFromBlk(var data : DataBlock)
    objectsToThrow = data |> datablock_getInt("objectsToThrow", -1)
    prepareTime = data |> datablock_getReal("prepareTime", -1.0)
    if objectsToThrow == -1
      logerr("BigHeadMultiAttack: \"objectsToThrow\" is not specified")
    if prepareTime < 0.0
      logerr("AttackTime: \"prepareTime\" is not specified")

  def override update(dt : float) : EBehResult
    if objectsToThrow == -1 || prepareTime < 0.0
      return EBehResult.ER_FAILED

    var result = EBehResult.ER_FAILED
    let bighead = beh_tree_eid(owner)
    let attackStarted = query(bighead) <| $ [es] (bighead_attack__state : int)
      if bighead_attack__state == int(BigheadAttackState.DONE)
        remote_remove_sub_template(bighead, "bighead_attack")
        result = EBehResult.ER_SUCCESS
      else
        result = EBehResult.ER_RUNNING

    if !attackStarted
      var noVictims = true
      query(bighead) <| $ [es] (bighead_victims__eid : EidList)
        noVictims = empty(bighead_victims__eid)
      if noVictims
        result = EBehResult.ER_FAILED
      else
        remote_add_sub_template(bighead, "bighead_attack") <| $(i)
          set(i, "bighead_attack__prepareTime", prepareTime)
          set(i, "bighead_attack__throwAmount", objectsToThrow)
        result = EBehResult.ER_RUNNING

    return result


[beh_node(name="bigheadChooseWanderingPosition")]
class BigheadChooseWanderingPosition : BehNodeAdapter
  def override update(dt : float)
    let bighead = beh_tree_eid(owner)
    var result = EBehResult.ER_FAILED
    query(bighead) <| $ [es] (bighead__territory : EntityId; var bighead_wandering__position : float3&)
      query(bighead__territory) <| $ [es] (bighead_territory__wanderingPositions : Point3List)
        if empty(bighead_territory__wanderingPositions)
          logerr("No custom wandering positions in bighewad territory!")
          result = EBehResult.ER_FAILED
          return
        bighead_wandering__position = bighead_territory__wanderingPositions[rnd_int(0, length(bighead_territory__wanderingPositions) - 1)]
        result = EBehResult.ER_SUCCESS
    return result


[beh_node(name="bigheadFlyToPosition")]
class BigheadFlyAround : BehNodeAdapter
  posParam : string
  @hidden posParamHash : uint

  def override loadFromBlk(var data : DataBlock)
    load_ecs_param(data, "positionComponent", posParam, posParamHash)

  def override update(dt : float)
    let bighead = beh_tree_eid(owner)
    var result = EBehResult.ER_FAILED
    let alreadyFlying = query(bighead) <| $ [es] (transform : float3x4;
                                                  bighead_movement__waypointApproachDistance : float;
                                                  bighead_movement__wayPointList : Point3List;
                                                  bighead_movement__wayPointListIndex : int;
                                                  bighead_movement__position : float3)
      if bighead_movement__wayPointListIndex < length(bighead_movement__wayPointList)
        result = EBehResult.ER_RUNNING
        return
      result = distance_sq(transform[3], bighead_movement__position) < square(bighead_movement__waypointApproachDistance) ? EBehResult.ER_SUCCESS : EBehResult.ER_FAILED

    if alreadyFlying
      return result

    let position = get_Point3(bighead, posParam, posParamHash) ?? float3(0.0)
    addSubTemplate(bighead, "bighead_movement") <| $(i)
      set(i, "bighead_movement__position", position)
    return EBehResult.ER_RUNNING

  def override exit()
    removeSubTemplate(beh_tree_eid(owner), "bighead_movement")
