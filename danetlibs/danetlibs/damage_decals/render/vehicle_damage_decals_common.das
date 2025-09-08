module vehicle_damage_decals_common shared

require daslib/algorithm
require ecs
require dm
require math.base
require AnimV20
require CollRes
require PhysMat
require DamageDecals
require DngDm
require DngWeapon
require danetlibs.damage_decals.render.damage_decals_matrices_common


[event(unicast)]
struct AddHitDecal
  collNodeId : int
  pos : float3
  dir : float3
  normal : float3
  caliber : float
  damageType : string

[event(unicast)]
struct AddShrapnelDecal
  collNodeId : int
  localPos : float3
  localDir : float3
  localNormal : float3

enum ProjectileHitType
  PIERCE
  STOP
  RICOCHETE

def private check_near_decals(new_local_pos : float3;
                              new_coll_node_id : int;
                              new_caliber : float;
                              local_poses : Point3List;
                              coll_node_ids : IntList;
                              calibers : FloatList)
  for localPos, collNodeId, caliber in local_poses, coll_node_ids, calibers
    if collNodeId != new_coll_node_id
      continue
    let distSq = length_sq(new_local_pos - localPos)
    if new_caliber < caliber * 1.1f && distSq < caliber * caliber * 2.0f
      return false
  return true

def get_decal_damage_type(hit_type : ProjectileHitType;
                          local_dir : float3;
                          local_normal : float3;
                          bullet_type_id : int)
  var damageType = ""
  let decal = get_bullet_decal(uint16(bullet_type_id))
  if (decal != null)
    let hitAngleCos = -dot(local_dir, local_normal)
    let angledType = hitAngleCos < cos(deg_to_rad(45.0f))
    if hit_type == ProjectileHitType.PIERCE
      damageType = angledType ? string(decal.pierceAngled) : string(decal.pierce)
    elif hit_type == ProjectileHitType.STOP
      damageType = angledType ? string(decal.stopAngled) : string(decal.stop)
    elif hit_type == ProjectileHitType.RICOCHETE
      damageType = string(decal.ricochet)
  return damageType

def create_damage_decal_on_vehicle(pos : float3;
                                   dir : float3;
                                   normal : float3;
                                   caliber : float;
                                   coll_node_id : int;
                                   damage_type : string;
                                   vehicle_eid : EntityId)
  query(vehicle_eid) <| $ [es] (transform : float3x4;
                                animchar : AnimcharBaseComponent;
                                collres : CollisionResource;
                                damage_model : DamageModel;
                                damage_decals__collNodesWithBurning : IntList;
                                var damage_decals__collNodeId : IntList&;
                                var damage_decals__nodeMatrixId : UInt32List&;
                                var damage_decals__projectileHitDecalId : IntList&;
                                var damage_decals__projectileHitCollNodeId : IntList&;
                                var damage_decals__projectileHitLocalPos : Point3List&;
                                var damage_decals__projectileHitCaliber : FloatList&;
                                isExploded : bool = false;
                                fire_damage__isBurn : bool = false)
    var nodeTm : float3x4
    collres_get_collision_node_tm(collres, coll_node_id, transform, animchar.nodeTree, nodeTm)
    let nodeInvTm = inverse(nodeTm)
    let nodeLocalPos = nodeInvTm * pos

    if !check_near_decals(nodeLocalPos, coll_node_id, caliber, damage_decals__projectileHitLocalPos,
        damage_decals__projectileHitCollNodeId, damage_decals__projectileHitCaliber)
      return

    let mergedMatrices = isExploded && length(damage_decals__collNodeId) == 0
    let matrixId = get_matrix_id(coll_node_id, damage_decals__collNodeId, damage_decals__nodeMatrixId, mergedMatrices)

    let partId = get_part_id_by_coll_node_id(damage_model.dmData, coll_node_id)
    let physmatId = get_part_physmat_id(damage_model.dmData, partId)
    let physmatName = physmatId >= 0 ? get_material_name(get_material(physmatId)) : "steel"

    let needBurning = fire_damage__isBurn && binary_search(damage_decals__collNodesWithBurning, coll_node_id)
    let decalState = uint16((isExploded ? 0 : EXPLOSION_PATCH_STATE__PRIMER_COLOR) |
                            (needBurning ? EXPLOSION_PATCH_STATE__BURNING : 0))

    let itm = mergedMatrices ? inverse(transform) : nodeInvTm
    let decalId = create_vehicle_damage_decal(pos, dir, normal, caliber / 2.f, physmatName, damage_type, int(matrixId), itm, decalState)
    if decalId >= 0
      push(damage_decals__projectileHitDecalId, decalId)
      push(damage_decals__projectileHitCollNodeId, coll_node_id)
      push(damage_decals__projectileHitLocalPos, nodeLocalPos)
      push(damage_decals__projectileHitCaliber, caliber)
