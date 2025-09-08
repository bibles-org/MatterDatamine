require ecs
require app
require level
require DngNet
require DagorMath
require math.base
require game.events.events_game


struct PointsStruct
  eid : EntityId
  time : float


def delete_player_points(var points : array<PointsStruct>; count : int)
  if count <= 0
    for point in points
      send_net_event(point.eid, CmdDeleteMapUserPoint())
  elif length(points) > count
    let numPoints = length(points) - count
    for _ in range(numPoints)
      var first = 0
      for j in range(1, length(points))
        if points[j].time < points[first].time
          first = j
      if points[first].eid != INVALID_ENTITY_ID
        send_net_event(points[first].eid, CmdDeleteMapUserPoint())
        erase(points, first)


[es(tag=server, on_appear)]
def map_user_point_init_es(evt : Event;
                           eid : EntityId;
                           userPointOwner : EntityId;
                           var userPointName : das_string&;
                           pointGroup : int;
                           timer__start : float;
                           timer__delta : float;
                           var timer__destroy : float&;
                           countPoint : int = 1)
  timer__destroy = timer__start + timer__delta

  let renameUserPointOwner = userPointOwner
  let renameEid = eid
  let renamePointGroup = pointGroup
  var points : array<PointsStruct>

  query() <| $ [es] (eid : EntityId;
                     userPointOwner : EntityId;
                     timer__start : float;
                     pointGroup : int)
    if userPointOwner == renameUserPointOwner && eid != renameEid && pointGroup == renamePointGroup
      points |> emplace(PointsStruct(
        eid = eid,
        time = timer__start
      ))

  points |> sort <| $(a, b)
    return a.time < b.time

  delete_player_points(points, countPoint - 1)

  userPointName := "{points.length() + 1}"
  for p, idx in points, range(points.length())
    query(p.eid) <| $ [es] (var userPointName : das_string&)
      userPointName := "{idx+1}"


def create_map_user_point(point_type : string;
                          var pos : float3;
                          norm : float3;
                          eid : EntityId;
                          team : int;
                          template_name : string;
                          silent : bool)
  if length_sq(pos) == 0.f
    return INVALID_ENTITY_ID
  if empty(template_name)
    return INVALID_ENTITY_ID

  return createEntity(template_name) <| $(init)
    var tm = IDENT_TM
    if length_sq(norm) > FLT_EPSILON
      make_tm(dir_to_quat(norm), tm)
    tm[3] = pos
    init |> set("transform", tm)
    init |> set("team", team)
    init |> set("userPointOwner", eid)
    init |> set("userPointType", point_type)
    init |> set("timer__start", get_sync_time())
    init |> set("silentAppearance", silent)


[es(tag=server, REQUIRE=player)]
def map_user_point_create_es(evt : CmdCreateMapUserPoint;
                             team : int;
                             eid : EntityId;
                             map_mark_creator__markTemplateName : string;
                             map_mark_creator__markCreationCooldown : float;
                             var map_mark_creator__lastMarkTime : float&)
  if !is_level_loaded()
    return

  let curTime = get_sync_time()
  if curTime < map_mark_creator__lastMarkTime + map_mark_creator__markCreationCooldown
    return
  map_mark_creator__lastMarkTime = curTime

  create_map_user_point(evt.item_name, evt.pos, evt.norm, eid, team, map_mark_creator__markTemplateName, false)
