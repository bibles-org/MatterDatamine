require ecs
require app
require DagorMath
require math.base
require danetlibs.renderer.includes.pufd_events
require AnimV20
require GeomNodeTree
require game.events.events_active_matter
require math.random
require pathfinder


[es(tag=gameClient, after=floating_object_set_position, REQUIRE_NOT=floating_object__disableEllipseFloating)]
def mothman_update_charging_object_progress(update : ParallelUpdateFrameDelayed;
                                            monstrified_mothman_attack__loadTime : float;
                                            monstrified_mothman_attack__chargedAt : float;
                                            monstrified_mothman_attack__chosenObject : EntityId;
                                            var monstrified_mothman_attack__floatingObjectAttractionProgress : float&)
  if monstrified_mothman_attack__chargedAt <= 0.0
    let val = monstrified_mothman_attack__floatingObjectAttractionProgress
    monstrified_mothman_attack__floatingObjectAttractionProgress = approach(val, 0.0, update.dt, 0.1)
    return

  let chargeProgress = 1.0 - clamp((monstrified_mothman_attack__chargedAt - update.curTime) / monstrified_mothman_attack__loadTime, 0.0, 1.0)
  let previousProgress = monstrified_mothman_attack__floatingObjectAttractionProgress
  monstrified_mothman_attack__floatingObjectAttractionProgress = chargeProgress
  if chargeProgress >= 1.0 && previousProgress < 1.0
    addSubTemplate(monstrified_mothman_attack__chosenObject, "mothman_clientside_prepared_object")


[es(tag=server, on_appear)]
def init_mothman_floating_object_approach_from_pos_server(evt : Event;
                                                          floating_object__owner : EntityId;
                                                          var floating_object_approach_from_pos__pos : float3&;
                                                          var floating_object_approach_from_pos__approachStart : float&)
  floating_object_approach_from_pos__approachStart = get_sync_time()
  query(floating_object__owner) <| $ [es] (transform : float3x4;
                                           monstrified_mothman_gathering__objectAppearRandomRadius : float2;
                                           monstrified_mothman_gathering__maxHeight : float)
    var pos2d = rnd_point_on_ring(monstrified_mothman_gathering__objectAppearRandomRadius)
    pos2d.x = abs(pos2d.x) // spawn stone before our eyes
    let localPos = float3(pos2d.x, -monstrified_mothman_gathering__maxHeight, pos2d.y)
    floating_object_approach_from_pos__pos = transform * localPos
    project_to_nearest_navmesh_point(floating_object_approach_from_pos__pos, 1.0)


[es(tag=gameClient, after=mothman_update_charging_object_progress, before=mothman_update_charging_object_position)]
def mothman_floating_object_approach_from_pos(update : ParallelUpdateFrameDelayed;
                                              eid : EntityId;
                                              floating_object_approach_from_pos__pos : float3;
                                              floating_object_approach_from_pos__approachTime : float;
                                              floating_object_approach_from_pos__approachStart : float;
                                              var transform aka object_transform : float3x4&)
  // on the start of the function, transform is the desired position on the ellipse
  let approachProgress = clamp((update.curTime - floating_object_approach_from_pos__approachStart) / floating_object_approach_from_pos__approachTime, 0.0, 1.0)
  object_transform[3] = floating_object_approach_from_pos__pos + (object_transform[3] - floating_object_approach_from_pos__pos) * approachProgress
  if approachProgress >= 1.0
    removeSubTemplate(eid, "floating_object_approach_from_pos")


[es(tag=gameClient, after=mothman_update_charging_object_progress)]
def mothman_update_charging_object_position(update : ParallelUpdateFrameDelayed;
                                            animchar : AnimcharBaseComponent;
                                            hero : Tag const?;
                                            human_cam__camNodeId : int;
                                            transform aka mothman_transform : float3x4;
                                            monstrified_mothman_attack__objectPrepareCameraOffset : float3;
                                            floating_objects__eids : EidList;
                                            monstrified_mothman_attack__chosenObject : EntityId;
                                            monstrified_mothman_attack__shotAt : float;
                                            monstrified_mothman_attack__shootAnimTime : float;
                                            monstrified_mothman_attack__floatingObjectAttractionProgress : float)
  if monstrified_mothman_attack__chosenObject == INVALID_ENTITY_ID || empty(floating_objects__eids) || !has_value(floating_objects__eids, monstrified_mothman_attack__chosenObject)
    return

  let endThrowAnimAt = monstrified_mothman_attack__shotAt + monstrified_mothman_attack__shootAnimTime
  if update.curTime < endThrowAnimAt
    return

  let wposRel = geomtree_getNodeWposRel(*animchar.nodeTree, human_cam__camNodeId)
  let wofs = geomtree_getWtmOfs(*animchar.nodeTree)
  let cameraPos = wposRel + wofs

  var desiredPosition : float3
  if hero != null
    find_query() <| $ [es] (camera__active : bool; transform aka camera_transform : float3x4)
      if !camera__active
        return false
      desiredPosition = camera_transform * monstrified_mothman_attack__objectPrepareCameraOffset
      return true
  else // hero
    var rot = float3x3(mothman_transform)
    swap(rot[2], rot[0])
    desiredPosition = cameraPos + rot * monstrified_mothman_attack__objectPrepareCameraOffset

  query(monstrified_mothman_attack__chosenObject) <| $ [es] (var transform aka object_transform : float3x4&)
    let desiredDelta = desiredPosition - object_transform[3]
    transform[3] += desiredDelta * pow(monstrified_mothman_attack__floatingObjectAttractionProgress, 0.25)
