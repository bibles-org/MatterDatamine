require ecs
require ecs.safe
require math.base
require DngDm
require DngWeapon
require AnimV20
require CollRes
require danetlibs.dm.dm_events
require danetlibs.damage_decals.render.vehicle_damage_decals_common


def create_damage_decal_on_hit_event(local_pos : float3;
                                     local_dir : float3;
                                     local_normal : float3;
                                     transform : float3x4;
                                     caliber : float;
                                     bullet_type_id : int;
                                     coll_node_id : int;
                                     hit_type : ProjectileHitType;
                                     vehicle_eid : EntityId)
  // Don't spawn decals for unknown type. It will use default texture which doesn't look good sometimes.
  if (bullet_type_id < 0)
    return
  let damageType = get_decal_damage_type(hit_type, local_dir, local_normal, bullet_type_id)
  let pos = transform * local_pos
  let dir = rotate(transform, local_dir)
  let normal = rotate(transform, local_normal)
  create_damage_decal_on_vehicle(pos, dir, normal, caliber, coll_node_id, damageType, vehicle_eid)

[es(tag=render, REQUIRE=damage_model, REQUIRE_NOT=disableUpdate)]
def vehicle_damage_decal_on_hit(evt : EventOnHitByProjectile;
                                transform : float3x4;
                                eid : EntityId)
  let hitType = evt.pierced ? ProjectileHitType.PIERCE : ProjectileHitType.STOP
  create_damage_decal_on_hit_event(evt.localHitPos, evt.localHitDir, evt.localNormal, transform,
                                   evt.caliber, evt.bulletTypeId, evt.nodeId, hitType, eid)

[es(tag=render, REQUIRE=damage_model, REQUIRE_NOT=disableUpdate)]
def vehicle_damage_decal_on_ricochet(evt : EventOnRicochet;
                                     transform : float3x4;
                                     eid : EntityId)
  let hitType = ProjectileHitType.RICOCHETE
  var bulletTypeId = -1
  ecs::query(evt.projectileEid) <| $ [es] (dm_projectile_state : ProjectileState)
    bulletTypeId = dm_projectile_state.projectileTypePropsId
  create_damage_decal_on_hit_event(evt.localHitPos, evt.localHitDir, evt.localNormal, transform,
                                   evt.caliber, bulletTypeId, evt.nodeId, hitType, eid)

[es(tag=render, on_appear, after=vehicle_damage_decal_decor_projectile_skin_init, REQUIRE=damage_model)]
def vehicle_damage_decal_decor_projectile_init(evt : Event;
                                               eid : EntityId;
                                               transform : float3x4;
                                               animchar : AnimcharBaseComponent;
                                               collres : CollisionResource;
                                               damage_decals_decor__projectileHitCollNodeName : StringList;
                                               damage_decals_decor__projectileHitLocalPos : Point3List;
                                               damage_decals_decor__projectileHitLocalDir : Point3List;
                                               damage_decals_decor__projectileHitLocalNormal : Point3List;
                                               damage_decals_decor__projectileHitCaliber : FloatList;
                                               damage_decals_decor__projectileHitDamageType : StringList)
  assume collNodeNames = damage_decals_decor__projectileHitCollNodeName
  assume localPoses = damage_decals_decor__projectileHitLocalPos
  assume localDirs = damage_decals_decor__projectileHitLocalDir
  assume localNormals = damage_decals_decor__projectileHitLocalNormal
  assume calibers = damage_decals_decor__projectileHitCaliber
  assume damageTypes = damage_decals_decor__projectileHitDamageType
  for collNodeName, localPos, localDir, localNormal, caliber, damageType in collNodeNames, localPoses, localDirs, localNormals, calibers, damageTypes
    let collNodeId = collres_get_node_index_by_name(collres, string(collNodeName))
    var nodeTm : float3x4
    collres_get_collision_node_tm(collres, collNodeId, transform, animchar.nodeTree, nodeTm)
    let pos = nodeTm * localPos
    let dir = rotate(nodeTm, localDir)
    let normal = rotate(nodeTm, localNormal)
    create_damage_decal_on_vehicle(pos, dir, normal, caliber, collNodeId, string(damageType), eid)

[es(tag=(render, netClient), on_appear, REQUIRE=damage_model)]
def vehicle_damage_decal_decor_projectile_skin_init(evt : Event;
                                                    skin__template : string;
                                                    skin__id : string;
                                                    var damage_decals_decor__projectileHitCollNodeName : StringList&;
                                                    var damage_decals_decor__projectileHitLocalPos : Point3List&;
                                                    var damage_decals_decor__projectileHitLocalDir : Point3List&;
                                                    var damage_decals_decor__projectileHitLocalNormal : Point3List&;
                                                    var damage_decals_decor__projectileHitCaliber : FloatList&;
                                                    var damage_decals_decor__projectileHitDamageType : StringList&)
  if empty(skin__id) || empty(skin__template)
    return
  let templ = getTemplateByName(string(skin__template))
  if templ == null
    return
  let skinInfo = get_ecs_array(getTemplateComponent(*templ, "skin__info"))
  if skinInfo == null
    return
  for skinComp in *skinInfo
    let skin = get_ecs_object(skinComp)
    if skin == null
      continue
    let id = skin?.id ?? ""
    if id != skin__id
      continue
    let projectileHitCollNodeName = get_ecs_StringList(skin?.damage_decals_decor__projectileHitCollNodeName)
    if projectileHitCollNodeName != null
      damage_decals_decor__projectileHitCollNodeName := *projectileHitCollNodeName
    let projectileHitLocalPos = get_ecs_Point3List(skin?.damage_decals_decor__projectileHitLocalPos)
    if projectileHitLocalPos != null
      damage_decals_decor__projectileHitLocalPos := *projectileHitLocalPos
    let projectileHitLocalDir = get_ecs_Point3List(skin?.damage_decals_decor__projectileHitLocalDir)
    if projectileHitLocalDir != null
      damage_decals_decor__projectileHitLocalDir := *projectileHitLocalDir
    let projectileHitLocalNormal = get_ecs_Point3List(skin?.damage_decals_decor__projectileHitLocalNormal)
    if projectileHitLocalNormal != null
      damage_decals_decor__projectileHitLocalNormal := *projectileHitLocalNormal
    let projectileHitCaliber = get_ecs_FloatList(skin?.damage_decals_decor__projectileHitCaliber)
    if projectileHitCaliber != null
      damage_decals_decor__projectileHitCaliber := *projectileHitCaliber
    let projectileHitDamageType = get_ecs_StringList(skin?.damage_decals_decor__projectileHitDamageType)
    if projectileHitDamageType != null
      damage_decals_decor__projectileHitDamageType := *projectileHitDamageType
    break
