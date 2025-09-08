require ecs
require ecs.safe
require Grid
require math.base
require DagorMath
require DagorSystem
require game.events.events_active_matter
require game.es.door_operations_common


[es(tag=server, on_appear)]
def door_check_from_door_controller_on_appear(evt : Event;
                                              eid aka door_eid : EntityId;
                                              transform aka door_transform : float3x4;
                                              isDoor : bool)
  if !isDoor
    return

  find_query() <| $ [es] (eid aka door_controller_eid : EntityId;
                          door_controller__detectDoorRadius : float;
                          transform aka door_controller_transform : float3x4;
                          var door_controller__doorEid : EntityId&)
    if door_controller__doorEid != INVALID_ENTITY_ID
      return false

    let distSq = distance_sq(door_transform[3], door_controller_transform[3])
    if distSq <= square(door_controller__detectDoorRadius)
      door_controller__doorEid = door_eid
      sendEvent(door_controller_eid, EventDoorControllerInited())
      return true
    return false


[es(tag=server)]
def door_controller_init_state(evt : EventDoorControllerInited;
                               door_controller__initState : int;
                               door_controller__doorEid : EntityId)
  change_door_state(door_controller__doorEid, door_controller__initState, float3(), /*is_server*/true)


[es(on_appear)]
def door_calculate_rotation_speed_by_mass(evt : Event;
                                          rendinst__mass : float;
                                          door__rotSpeedPerMass : float = 3000.0;
                                          var rendinst_axis_rotation__rotSpeed : float&)
  if rendinst__mass > 0.0
    rendinst_axis_rotation__rotSpeed = door__rotSpeedPerMass / rendinst__mass


[es(on_appear, after=door_calculate_rotation_speed_by_mass, before=rotating_rendinst_simple_phys_appear)]
def door_calculate_mass_by_rotation_speed(evt : Event;
                                          rendinst_axis_rotation__rotSpeed : float;
                                          door__rotSpeedPerMass : float = 3000.0;
                                          var rendinst__mass : float&)
  if rendinst__mass == 0.0 && rendinst_axis_rotation__rotSpeed > 0.0
    rendinst__mass = door__rotSpeedPerMass / rendinst_axis_rotation__rotSpeed


[es(on_appear)]
def rotating_door_simple_phys_on_appear(evt : Event;
                                        door_operations__openedAngle : float;
                                        door_operations__closedAngle : float;
                                        var rotating_rendinst_simple_phys__clampAngles : float2&)
  let minClampAngle = min(door_operations__openedAngle, door_operations__closedAngle)
  let maxClampAngle = max(door_operations__openedAngle, door_operations__closedAngle)
  rotating_rendinst_simple_phys__clampAngles = float2(minClampAngle, maxClampAngle)


[es(on_appear)]
def rotating_door_init_opened_dir(evt : Event;
                                  rendinst_axis_rotation__axis : float3;
                                  door_operations__openedAngle : float;
                                  initialTransform : float3x4;
                                  var door_operations__openedDir : float3&)
  var tm : float3x4
  make_tm(rendinst_axis_rotation__axis, deg_to_rad(door_operations__openedAngle), tm)
  tm = initialTransform * tm
  door_operations__openedDir = tm[0]


[es(tag=server, on_appear, REQUIRE=destroyDoorsInTm)]
def destroy_doors_in_tm_on_appear(evt : Event; transform : float3x4)
  destroy_doors_in_tm(transform)


[unused_argument(level__loadingGen), es(tag=server, track=level__loadingGen)]
def destroy_doors_in_tm_es(evt : Event;
                           level__loadingGen : int;
                           level__levelLoaded : bool;
                           level__gameObjectsEntitiesCreated : bool)
  if level__levelLoaded && level__gameObjectsEntitiesCreated
    query() <| $ [es(REQUIRE=destroyDoorsInTm)] (transform : float3x4)
      destroy_doors_in_tm(transform)


def destroy_doors_in_tm(transform : float3x4)
  let boxAxis = float3(abs(transform[0].x) + abs(transform[1].x) + abs(transform[2].x),
                        abs(transform[0].y) + abs(transform[1].y) + abs(transform[2].y),
                        abs(transform[0].z) + abs(transform[1].z) + abs(transform[2].z)) * 0.5
  let bbox = BBox3(transform[3] - boxAxis, transform[3] + boxAxis)
  for_each_entity_in_grid(ecs_hash("doors"), bbox, GridEntCheck.BOUNDING) <| $(doorEid : EntityId)
    query(doorEid) <| $ [es] (isDoor : bool; pair_door__eid : EntityId)
      if isDoor
        destroyEntity(doorEid)
        destroyEntity(pair_door__eid)