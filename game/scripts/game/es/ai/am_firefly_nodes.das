options always_export_initializer = true
require ecs
require DagorMath
require BehNodes
require DngDm
require DngNet
require Grid


[beh_node(name="fireflySleep")]
class FireflySleep : BehNodeAdapter

  def override update(dt : float) : EBehResult
    let eid = beh_tree_eid(owner)
    var success = false
    var failure = true
    query(eid) <| $ [es] (firefly__sleepTemplate : string;
                          firefly__activeTemplate : string;
                          nphys_levitating__elevation : float;
                          var nphys_levitating__prefferedElevation : float&)
      failure = false
      nphys_levitating__prefferedElevation = 0.0
      success = nphys_levitating__elevation < 0.05
      if success
        remote_change_sub_template(eid, firefly__activeTemplate, firefly__sleepTemplate)
    return success ? EBehResult.ER_SUCCESS : (failure ? EBehResult.ER_FAILED : EBehResult.ER_RUNNING)


[beh_node(name="fireflyFindTarget")]
class FireflyFindTarget : BehNodeAdapter
  xenosTeam : int = -1

  def override init()
    find_query() <| $ [es(REQUIRE=xenos_team)] (team__id : int)
      xenosTeam = team__id
      return true

  def override update(dt : float) : EBehResult
    let eid = beh_tree_eid(owner)
    var success = false
    query(eid) <| $ [es] (transform : float3x4;
                          firefly__origin : float3;
                          firefly__originRadius, firefly__searchRadius : float;
                          var walker_agent__targetEid : EntityId&)
      walker_agent__targetEid = INVALID_ENTITY_ID
      let dstToOrigin = distance(transform[3], firefly__origin)
      let adjustedRadius = min(firefly__searchRadius, firefly__originRadius - dstToOrigin) //don't search where you can't chase
      if adjustedRadius > 1.0
        find_entity_in_grid(ecs_hash("humans"), BSphere3(transform[3], adjustedRadius), GridEntCheck.POS) <| $(target_eid : EntityId)
          query(target_eid) <| $ [es(REQUIRE=sleep_disturber__radius, REQUIRE_NOT=deadEntity)] (isAlive : bool = true; team : int const?)
            if !isAlive || (team != null && *team == xenosTeam)
              return
            walker_agent__targetEid = target_eid
            success = true
          return success
    return success ? EBehResult.ER_SUCCESS : EBehResult.ER_FAILED