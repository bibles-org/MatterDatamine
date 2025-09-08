require ecs
require ecs.safe
require game.events.events
require math.base
require pathfinder
require DagorMath
require walkerai


def moveChildSegment(child_segment : EntityId; segment_dist : float; parent_pos : float3)
  query(child_segment) <| $ [es] (centipede__childSegment : EntityId; var transform : float3x4&)
    let newSegmentHeadPos = parent_pos
    let curSegmentTailPos = transform[3] - transform[0] * segment_dist
    var segmentWishDir = normalize(newSegmentHeadPos - curSegmentTailPos)
    let newSegmentTailPos = newSegmentHeadPos - segmentWishDir * segment_dist

    var newPos = newSegmentTailPos
    if project_to_nearest_navmesh_point(newPos, 0.1)
      segmentWishDir = normalize(newSegmentHeadPos - newPos)
    else
      newPos = newSegmentTailPos

    moveChildSegment(centipede__childSegment, segment_dist, newPos)

    let q = dir_to_quat(segmentWishDir)
    make_tm(q, newSegmentHeadPos, transform)


[es(tag=server, on_appear)]
def centipede_create(evt : Event;
                     centipede__segmentsCount : int;
                     centipede__segmentDist : float;
                     transform : float3x4;
                     centipede__segmentTempl : string;
                     centipede__tailTempl : string;
                     var centipede__childSegment : EntityId&)
  let headPos = transform[3]
  var childSegmentEid = INVALID_ENTITY_ID
  for i in range(centipede__segmentsCount)
    let currentSegmentNum = centipede__segmentsCount - i
    let newSegmentPos = headPos - transform[0] * (float(currentSegmentNum) * centipede__segmentDist)
    childSegmentEid = createEntity(!childSegmentEid ? centipede__tailTempl : centipede__segmentTempl) <| $(init)
      var tm = IDENT_TM
      tm[3] = newSegmentPos
      init |> set("transform", tm)
      init |> set("centipede__childSegment", childSegmentEid)
  centipede__childSegment = childSegmentEid


[es(tag=gameClient, REQUIRE=centipede__segmentsCount, after=(move_navmesh_phys_pos, move_navmesh_phys_lookdir))]
def centipede_move_client(act : UpdateStageInfoAct;
                          centipede__childSegment : EntityId;
                          centipede__segmentDist : float;
                          transform : float3x4)
  let parentPos = transform[3] - transform[0] * 0.08//centipede__segmentDist * 0.5
  moveChildSegment(centipede__childSegment, centipede__segmentDist, parentPos)


[es(tag=server, no_order, REQUIRE=centipede)]
def centipede_util_vars(act : UpdateStageInfoAct;
                        visual_attract__points : Array;
                        attract_point__eid : EntityId;
                        attract_point__ratio : float;
                        var util_vars__visibleAttractPoints : float&;
                        var util_vars__ready : bool&;
                        var util_vars__attractPointRatio : float&)
  if util_vars__ready
    return

  util_vars__visibleAttractPoints = 0f
  for it in visual_attract__points
    let data = it |> get_ecs_object()
    if data?.visible ?? false
      util_vars__visibleAttractPoints += 1f

  // start attract ratio from 0.5 to beat gotohome node
  util_vars__attractPointRatio = attract_point__eid != INVALID_ENTITY_ID ? 0.5 + attract_point__ratio : 0f

  util_vars__ready = true