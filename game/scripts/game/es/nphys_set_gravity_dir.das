require ecs
require DngNet
require Grid
require game.es.grav_zones_common
require DagorMath
require math.base


[es(tag=server, REQUIRE_NOT=nphys__disabled, on_appear)]
def navmesh_phys_init_gravity(evt : Event;
                              transform : float3x4;
                              var navmesh_phys__upDir : float3&)
  let gravDir = get_grav_dir(transform[3], true) //Even if we get the wrong one, it's still better than nothing
  navmesh_phys__upDir = -gravDir


[es(tag=server, before=move_navmesh_phys_lookdir, parallel_for=4,
    REQUIRE_NOT=(deadEntity, nphys__disabled))]
def navmesh_phys_update_gravity(act : UpdateStageInfoAct;
                                navmesh_phys__currentPos : float3;
                                var am_navmesh_creature__gravZones : EidList;
                                var navmesh_phys__upDir : float3&)
  var leavedZonesIdx : array<int>
  var zones : array<tuple<level : int, weight : float, force : float3>>

  for index, zoneEid in iter_range(am_navmesh_creature__gravZones), am_navmesh_creature__gravZones
    var zoneLevel = 0
    var zoneWeight = 0.0
    var zoneForce = float3(0.0, 0.0, 0.0)
    if !calc_zone_gravity_if_inside(zoneEid, navmesh_phys__currentPos, zoneForce, zoneWeight, zoneLevel)
      leavedZonesIdx |> push(index)
    else
      zones |> push((zoneLevel, zoneWeight, zoneForce))

  let wishUpDir = -get_grav_dir(zones)

  navmesh_phys__upDir = approach(navmesh_phys__upDir, wishUpDir, act.dt, 0.1)

  for i in iter_range(leavedZonesIdx)
    am_navmesh_creature__gravZones |> erase(leavedZonesIdx[length(leavedZonesIdx) - 1 - i])


def update_zone_list(creature_eid, zone_eid : EntityId)
  query(creature_eid) <| $ [es] (var am_navmesh_creature__gravZones : EidList)
    if !has_value(am_navmesh_creature__gravZones, zone_eid)
      am_navmesh_creature__gravZones |> push(zone_eid)


[es(tag=server, no_order)]
def navmesh_monster_enter_sphere_grav_zone(act : UpdateStageInfoAct;
                                           eid : EntityId;
                                           transform : float3x4;
                                           grav_zone__outerRadius : float)
  let zoneSphere = BSphere3(transform[3], grav_zone__outerRadius)
  for_each_entity_in_grid(fixed_array(ecs_hash("humans"), ecs_hash("creatures")), zoneSphere, GridEntCheck.POS) <| $(navEid : EntityId)
    update_zone_list(navEid, eid)


[es(tag=server, no_order)]
def navmesh_monster_enter_box_grav_zone(act : UpdateStageInfoAct;
                                        eid : EntityId;
                                        transform : float3x4;
                                        gravity_zone__boxSize : float3)
  let zoneBox = BBox3(-gravity_zone__boxSize / 2.0, gravity_zone__boxSize / 2.0)
  for_each_entity_in_grid(fixed_array(ecs_hash("humans"), ecs_hash("creatures")), transform, zoneBox, GridEntCheck.POS) <| $(navEid : EntityId)
    update_zone_list(navEid, eid)
