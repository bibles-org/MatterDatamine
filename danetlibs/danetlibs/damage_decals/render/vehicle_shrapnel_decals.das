require ecs
require ecs.safe
require dm
require DngDm
require AnimV20
require CollRes
require DagorMath
require DagorRandom
require DaWeaponProps
require Grid
require PhysMat
require DamageDecals
require BallisticsProps
require danetlibs.dm.dm_events
require danetlibs.damage_decals.render.damage_decals_matrices_common
require danetlibs.damage_decals.render.vehicle_damage_decals_common
require danetlibs.weapons.shell_events
require danetlibs.renderer.includes.pufd_events

let
  SHRAPNEL_DECAL_SIZE = 0.3f
  SHRAPNEL_DECAL_CLOSE_RANGE = 0.2f


def can_spawn_shrapnel_decals(local_pos : float3; part_id : int; coll_node_id : int;
                              max_decals_per_part : int;
                              shrapnel_decals_part_id : IntList&;
                              shrapnel_decals_local_pos : Point3List&;
                              damage_decals__projectileHitCollNodeId : IntList;
                              damage_decals__projectileHitLocalPos : Point3List;
                              damage_decals__projectileHitCaliber : FloatList)
  if (max_decals_per_part <= 0)
    return false
  var decalsPerPart = 0
  for partId, lPos in shrapnel_decals_part_id, shrapnel_decals_local_pos
    if partId != part_id
      continue
    decalsPerPart++
    if decalsPerPart >= max_decals_per_part
      return false
    if length_sq(local_pos - lPos) < SHRAPNEL_DECAL_CLOSE_RANGE * SHRAPNEL_DECAL_CLOSE_RANGE
      return false
  for collNodeId, lPos, caliber in damage_decals__projectileHitCollNodeId, damage_decals__projectileHitLocalPos, damage_decals__projectileHitCaliber
    if collNodeId != coll_node_id
      continue
    let minAllowedDist = (SHRAPNEL_DECAL_SIZE + caliber) * 0.5
    if length_sq(local_pos - lPos) < minAllowedDist * minAllowedDist
      return false
  return true

[es(no_order, tag=render, REQUIRE_NOT=disableUpdate)]
def vehicle_shrapnel_decals_delayed_create(info : UpdateStageInfoAct;
                                           transform : float3x4;
                                           animchar : AnimcharBaseComponent;
                                           collres : CollisionResource;
                                           damage_model : DamageModel;
                                           var damage_decals__collNodeId : IntList&;
                                           var damage_decals__nodeMatrixId : UInt32List&;
                                           var damage_decals__shrapnelDecalId : IntList&;
                                           var damage_decals__shrapnelDecalPartId : IntList&;
                                           var damage_decals__shrapnelDecalLocalPos : Point3List&;
                                           var damage_decals__shrapnelDecalLocalHitDirTemp : Point3List&;
                                           var damage_decals__shrapnelDecalLocalNormalTemp : Point3List&;
                                           isExploded : bool = false)
  var curIdx = length(damage_decals__shrapnelDecalId)
  for locHitDir, locNormal in damage_decals__shrapnelDecalLocalHitDirTemp, damage_decals__shrapnelDecalLocalNormalTemp
    let partId = damage_decals__shrapnelDecalPartId[curIdx]
    let collNodeId = damage_model.dmData |> get_collision_node_id(partId)
    var nodeTm : float3x4
    collres_get_collision_node_tm(collres, collNodeId, transform, animchar.nodeTree, nodeTm)
    let pos = nodeTm * damage_decals__shrapnelDecalLocalPos[curIdx]
    let dir = rotate(nodeTm, locHitDir)
    let normal = rotate(nodeTm, locNormal)

    let physmatId = get_part_physmat_id(damage_model.dmData, partId)
    let physmatName = physmatId >= 0 ? get_material_name(get_material(physmatId)) : "steel"

    let mergedMatrices = isExploded && length(damage_decals__collNodeId) == 0
    let matrixId = get_matrix_id(collNodeId, damage_decals__collNodeId, damage_decals__nodeMatrixId, mergedMatrices)
    let nodeInvTm = mergedMatrices ? inverse(transform) : inverse(nodeTm)
    let decalState = uint16(isExploded ? 0 : EXPLOSION_PATCH_STATE__PRIMER_COLOR)
    let decalId = create_vehicle_damage_decal(pos, dir, normal, SHRAPNEL_DECAL_SIZE, physmatName, "shrapnel_damage", int(matrixId), nodeInvTm, decalState)
    if decalId >= 0
      push(damage_decals__shrapnelDecalId, decalId)
      curIdx++
    else
      erase(damage_decals__shrapnelDecalPartId, curIdx)
      erase(damage_decals__shrapnelDecalLocalPos, curIdx)

  damage_decals__shrapnelDecalLocalHitDirTemp |> clear()
  damage_decals__shrapnelDecalLocalNormalTemp |> clear()

[es(tag=render, REQUIRE=msg_sink)]
def vehicle_damage_decals_on_explosion_event(evt : CmdShellExplodeClient)
  let shellProjBallisticsProps = projectile_try_get_props(int(evt.shellId.ballisticsId))
  let caliber = shellProjBallisticsProps?.caliber ?? 0.0

  let explosionPos = evt.offsetedPos
  let maxRadius = get_shell_max_radius(int(evt.shellId.shellId), int(evt.shellId.damageId), int(evt.shellId.ballisticsId))
  let explosionRadius = maxRadius > 1.f ? pow(maxRadius, 0.7) : maxRadius
  let numTraces = ceili(explosionRadius * explosionRadius * 2.f)
  let sphere = BSphere3(explosionPos, explosionRadius)
  for_each_entity_in_grid(ecs_hash("vehicles"), sphere, GridEntCheck.BOUNDING) <| $(vehicle_eid : EntityId)
    query(vehicle_eid) <| $ [es(REQUIRE=damage_model, REQUIRE_NOT=disableUpdate)] (transform : float3x4;
                                                                                   animchar : AnimcharBaseComponent;
                                                                                   collres : CollisionResource;
                                                                                   damage_model : DamageModel;
                                                                                   damage_decals__minCaliberForShrapnelDecals : float;
                                                                                   damage_decals__maxShrapnelDecalsPerPart : int;
                                                                                   var damage_decals__explosionPos : Point3List&;
                                                                                   var damage_decals__explosionNumTraces : IntList&;
                                                                                   var damage_decals__explosionMaxTraceLen : FloatList&)
      // Fill intermediate arrays for shrapnel decals. They requires more traces and will be processed later.
      if damage_decals__maxShrapnelDecalsPerPart > 0 && caliber >= damage_decals__minCaliberForShrapnelDecals
        push(damage_decals__explosionPos, explosionPos)
        push(damage_decals__explosionNumTraces, numTraces)
        push(damage_decals__explosionMaxTraceLen, explosionRadius)

      // Check if explosion was too close to vehicle, in this case we can spawn decal with explosive damage
      if length_sq(evt.shellVelocity) > 0.01f
        let shellDir = normalize(evt.shellVelocity)
        let traceStart = evt.pos - 0.2f * shellDir
        let damageType = shell_has_cumulative_damage(int(evt.shellId.damageId)) ? "heat_penetration" : "explosive_non_penetration"
        collres_traceray(collres, transform, animchar.nodeTree, traceStart, shellDir, 0.5f, true,
            uint8(BehaviorFlag.TRACEABLE)) <| $ [unused_argument(_)] (_ : bool; isects : CollResIntersectionsType#)
          for isect in isects
            let partId = get_part_id_by_coll_node_id(damage_model.dmData, int(isect.collisionNodeId))
            if partId >= 0 && is_part_enabled(damage_model.dmData, make_part_id(partId, -1))
              let decalPos = traceStart + shellDir * isect.intersectionT
              let collNodeId = int(isect.collisionNodeId)
              create_damage_decal_on_vehicle(decalPos, shellDir, isect.normal, caliber, collNodeId, damageType, vehicle_eid)
              sendEvent(vehicle_eid, AddHitDecal(collNodeId = collNodeId, pos = decalPos, dir = shellDir, normal = isect.normal, caliber = caliber, damageType = damageType))
              return

def random_direction_in_sphere(theta_cos_range : float2 = float2(-1.f, 1.f))
  let phi = rnd_float(0.f, 2.f * PI)
  let theta = acos(rnd_float(theta_cos_range.x, theta_cos_range.y))
  let dir = float3(sin(theta) * cos(phi), sin(theta) * sin(phi), cos(theta))
  return dir

def random_direction_in_cone(cone_transform : float3x3; cone_angle_cos : float)
  let dir = random_direction_in_sphere(float2(cone_angle_cos, 1.f))
  return cone_transform * dir

def make_cone_transform(cone_height_dir : float3)
  var out_tm : float3x3
  if abs(cone_height_dir.y) < 0.9
    out_tm[0] = normalize(cross(cone_height_dir, float3(0.f, 1.f, 0.f)))
  else
    out_tm[0] = normalize(cross(cone_height_dir, float3(1.f, 0.f, 0.f)))
  out_tm[1] = cross(out_tm[0], cone_height_dir)
  out_tm[2] = cone_height_dir
  return out_tm

def perform_trace(vehicle_eid : EntityId;
                  expl_pos : float3;
                  trace_dir : float3;
                  trace_len : float;
                  transform : float3x4;
                  animchar : AnimcharBaseComponent;
                  collres : CollisionResource;
                  damage_model : DamageModel;
                  var inside_vehicle : bool&;
                  damage_decals__maxShrapnelDecalsPerPart : int;
                  var damage_decals__shrapnelDecalPartId : IntList&;
                  var damage_decals__shrapnelDecalLocalPos : Point3List&;
                  var damage_decals__shrapnelDecalLocalHitDirTemp : Point3List&;
                  var damage_decals__shrapnelDecalLocalNormalTemp : Point3List&;
                  damage_decals__projectileHitCollNodeId : IntList;
                  damage_decals__projectileHitLocalPos : Point3List;
                  damage_decals__projectileHitCaliber : FloatList;
                  var damage_decals__prevExplosionTraces : Point3List?)
  var normal : float3
  var decalPos : float3
  var partId : int
  var collNodeId : int
  var found = false
  inside_vehicle = false
  collres_traceray(collres, transform, animchar.nodeTree, expl_pos, trace_dir, trace_len, true,
      uint8(BehaviorFlag.TRACEABLE)) <| $ [unused_argument(_)] (_ : bool; isects : CollResIntersectionsType#)
    for isect in isects
      partId = get_part_id_by_coll_node_id(damage_model.dmData, int(isect.collisionNodeId))
      if partId < 0 || !is_part_enabled(damage_model.dmData, make_part_id(partId, -1))
        continue
      if !is_part_inner(damage_model.dmData, partId)
        found = true
        collNodeId = int(isect.collisionNodeId)
        normal = isect.normal
        decalPos = expl_pos + trace_dir * isect.intersectionT
      else
        inside_vehicle = true
      return
  if damage_decals__prevExplosionTraces != null
    let tracePos = found ? decalPos : expl_pos + trace_dir * trace_len
    push(*damage_decals__prevExplosionTraces, tracePos)
  if (!found)
    return
  var nodeTm : float3x4
  collres_get_collision_node_tm(collres, collNodeId, transform, animchar.nodeTree, nodeTm)
  let nodeInvTm = inverse(nodeTm)
  let localPos = nodeInvTm * decalPos
  if !can_spawn_shrapnel_decals(localPos, partId, collNodeId,
                                damage_decals__maxShrapnelDecalsPerPart,
                                damage_decals__shrapnelDecalPartId,
                                damage_decals__shrapnelDecalLocalPos,
                                damage_decals__projectileHitCollNodeId,
                                damage_decals__projectileHitLocalPos,
                                damage_decals__projectileHitCaliber)
    return
  let localDir = rotate(nodeInvTm, trace_dir)
  let localNormal = rotate(nodeInvTm, normal)
  push(damage_decals__shrapnelDecalPartId, partId)
  push(damage_decals__shrapnelDecalLocalPos, localPos)
  push(damage_decals__shrapnelDecalLocalHitDirTemp, localDir)
  push(damage_decals__shrapnelDecalLocalNormalTemp, localNormal)
  sendEvent(vehicle_eid, AddShrapnelDecal(collNodeId = collNodeId, localPos = localPos, localDir = localDir, localNormal = localNormal))

[es(tag=render)]
def vehicle_shrapnel_decals_process_explosion(info : ParallelUpdateFrameDelayed;
                                              eid : EntityId;
                                              animchar_bsph : vec4f;
                                              transform : float3x4;
                                              animchar : AnimcharBaseComponent;
                                              collres : CollisionResource;
                                              damage_model : DamageModel;
                                              damage_decals__maxShrapnelDecalsPerPart : int;
                                              var damage_decals__shrapnelDecalPartId : IntList&;
                                              var damage_decals__shrapnelDecalLocalPos : Point3List&;
                                              var damage_decals__shrapnelDecalLocalHitDirTemp : Point3List&;
                                              var damage_decals__shrapnelDecalLocalNormalTemp : Point3List&;
                                              damage_decals__projectileHitCollNodeId : IntList;
                                              damage_decals__projectileHitLocalPos : Point3List;
                                              damage_decals__projectileHitCaliber : FloatList;
                                              var damage_decals__explosionPos : Point3List&;
                                              var damage_decals__explosionNumTraces : IntList&;
                                              var damage_decals__explosionMaxTraceLen : FloatList&;
                                              var damage_decals__prevExplosionTraceLen : float?;
                                              var damage_decals__prevExplosionTraces : Point3List?;
                                              damage_decals__maxTracesPerFrame : int = 50)
  var numTracesLeft = damage_decals__maxTracesPerFrame
  for explPos, numTracesRef, maxTraceLen in damage_decals__explosionPos, damage_decals__explosionNumTraces, damage_decals__explosionMaxTraceLen
    if damage_decals__prevExplosionTraces != null
      *damage_decals__prevExplosionTraces |> clear()
      numTracesLeft = numTracesRef + 1
    var numTraces = min(numTracesRef, numTracesLeft)
    let distance = length(explPos - animchar_bsph.xyz)
    if distance < animchar_bsph.w
      let traceLen = min(animchar_bsph.w, maxTraceLen)
      if damage_decals__prevExplosionTraceLen != null
        *damage_decals__prevExplosionTraceLen = traceLen
      for _ in range(numTraces)
        let rayDir = random_direction_in_sphere()
        var insideVehicle = false
        perform_trace(eid, explPos, rayDir, traceLen, transform, animchar, collres, damage_model, insideVehicle,
                      damage_decals__maxShrapnelDecalsPerPart,
                      damage_decals__shrapnelDecalPartId,
                      damage_decals__shrapnelDecalLocalPos,
                      damage_decals__shrapnelDecalLocalHitDirTemp,
                      damage_decals__shrapnelDecalLocalNormalTemp,
                      damage_decals__projectileHitCollNodeId,
                      damage_decals__projectileHitLocalPos,
                      damage_decals__projectileHitCaliber,
                      damage_decals__prevExplosionTraces)
        if insideVehicle
          numTraces = 0
          numTracesRef = 0
          break
    else
      let areaRatio = animchar_bsph.w * animchar_bsph.w / (4.f * distance * distance)
      let coneAngleCos = 1.f - 2.f * areaRatio
      let coneTraces = ceili(float(numTraces) * areaRatio)
      let coneTm = make_cone_transform((animchar_bsph.xyz - explPos) / distance)
      let traceLen = min(distance + animchar_bsph.w, maxTraceLen)
      if damage_decals__prevExplosionTraceLen != null
        *damage_decals__prevExplosionTraceLen = traceLen
      for _ in range(coneTraces)
        let rayDir = random_direction_in_cone(coneTm, coneAngleCos)
        var insideVehicle = false
        perform_trace(eid, explPos, rayDir, traceLen, transform, animchar, collres, damage_model, insideVehicle,
                      damage_decals__maxShrapnelDecalsPerPart,
                      damage_decals__shrapnelDecalPartId,
                      damage_decals__shrapnelDecalLocalPos,
                      damage_decals__shrapnelDecalLocalHitDirTemp,
                      damage_decals__shrapnelDecalLocalNormalTemp,
                      damage_decals__projectileHitCollNodeId,
                      damage_decals__projectileHitLocalPos,
                      damage_decals__projectileHitCaliber,
                      damage_decals__prevExplosionTraces)
    numTracesRef -= numTraces
    numTracesLeft -= numTraces
    if numTracesLeft == 0
      return
  damage_decals__explosionPos |> clear()
  damage_decals__explosionNumTraces |> clear()
  damage_decals__explosionMaxTraceLen |> clear()

[es(tag=render, on_appear, after=vehicle_damage_decal_decor_shrapnel_skin_init, REQUIRE=damage_model)]
def vehicle_damage_decal_decor_shrapnel_init(evt : Event;
                                             collres : CollisionResource;
                                             damage_model : DamageModel;
                                             damage_decals_decor__shrapnelDecalCollNodeName : StringList;
                                             damage_decals_decor__shrapnelDecalLocalPos : Point3List;
                                             damage_decals_decor__shrapnelDecalLocalDir : Point3List;
                                             damage_decals_decor__shrapnelDecalLocalNormal : Point3List;
                                             var damage_decals__shrapnelDecalPartId : IntList&;
                                             var damage_decals__shrapnelDecalLocalPos : Point3List&;
                                             var damage_decals__shrapnelDecalLocalHitDirTemp : Point3List&;
                                             var damage_decals__shrapnelDecalLocalNormalTemp : Point3List&)
  assume collNodeNames = damage_decals_decor__shrapnelDecalCollNodeName
  assume localPoses = damage_decals_decor__shrapnelDecalLocalPos
  assume localDirs = damage_decals_decor__shrapnelDecalLocalDir
  assume localNormals = damage_decals_decor__shrapnelDecalLocalNormal
  for collNodeName, localPos, localDir, localNormal in collNodeNames, localPoses, localDirs, localNormals
    let collNodeId = collres_get_node_index_by_name(collres, string(collNodeName))
    let partId = get_part_id_by_coll_node_id(damage_model.dmData, collNodeId)
    push(damage_decals__shrapnelDecalPartId, partId)
    push(damage_decals__shrapnelDecalLocalPos, localPos)
    push(damage_decals__shrapnelDecalLocalHitDirTemp, localDir)
    push(damage_decals__shrapnelDecalLocalNormalTemp, localNormal)

[es(tag=(render, netClient), on_appear, REQUIRE=damage_model)]
def vehicle_damage_decal_decor_shrapnel_skin_init(evt : Event;
                                                  skin__template : string;
                                                  skin__id : string;
                                                  var damage_decals_decor__shrapnelDecalCollNodeName : StringList;
                                                  var damage_decals_decor__shrapnelDecalLocalPos : Point3List;
                                                  var damage_decals_decor__shrapnelDecalLocalDir : Point3List;
                                                  var damage_decals_decor__shrapnelDecalLocalNormal : Point3List)
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
    let shrapnelDecalCollNodeName = get_ecs_StringList(skin?.damage_decals_decor__shrapnelDecalCollNodeName)
    if shrapnelDecalCollNodeName != null
      damage_decals_decor__shrapnelDecalCollNodeName := *shrapnelDecalCollNodeName
    let shrapnelDecalLocalPos = get_ecs_Point3List(skin?.damage_decals_decor__shrapnelDecalLocalPos)
    if shrapnelDecalLocalPos != null
      damage_decals_decor__shrapnelDecalLocalPos := *shrapnelDecalLocalPos
    let shrapnelDecalLocalDir = get_ecs_Point3List(skin?.damage_decals_decor__shrapnelDecalLocalDir)
    if shrapnelDecalLocalDir != null
      damage_decals_decor__shrapnelDecalLocalDir := *shrapnelDecalLocalDir
    let shrapnelDecalLocalNormal = get_ecs_Point3List(skin?.damage_decals_decor__shrapnelDecalLocalNormal)
    if shrapnelDecalLocalNormal != null
      damage_decals_decor__shrapnelDecalLocalNormal := *shrapnelDecalLocalNormal
    break
