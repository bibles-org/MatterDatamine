options no_aot
require ecs
require math
require math.base
require AnimV20
require CollRes
require Dacoll
require DagorConsole
require DagorDebug3D
require DagorMath
require DagorSystem
require DngCamera
require DngDm
require DamageDecals
require danetlibs.dm.dm_events
require danetlibs.damage_decals.render.vehicle_damage_decals_common
require danetlibs.renderer.includes.pufd_events


[es(tag=render, REQUIRE=(damage_model, damageDecalDecorDebug), REQUIRE_NOT=disableUpdate)]
def vehicle_damage_decal_decor_add_shrapnel_debug(evt : AddShrapnelDecal;
                                                  collres : CollisionResource;
                                                  var damage_decals_decor__shrapnelDecalCollNodeName : StringList&;
                                                  var damage_decals_decor__shrapnelDecalLocalPos : Point3List&;
                                                  var damage_decals_decor__shrapnelDecalLocalDir : Point3List&;
                                                  var damage_decals_decor__shrapnelDecalLocalNormal : Point3List&)
  let nodeName = collres_get_node(collres, evt.collNodeId) |> collnode_get_name
  push(damage_decals_decor__shrapnelDecalCollNodeName, nodeName)
  push(damage_decals_decor__shrapnelDecalLocalPos, evt.localPos)
  push(damage_decals_decor__shrapnelDecalLocalDir, evt.localDir)
  push(damage_decals_decor__shrapnelDecalLocalNormal, evt.localNormal)

[es(tag=render, REQUIRE=(damage_model, damageDecalDecorDebug), REQUIRE_NOT=disableUpdate)]
def vehicle_damage_decal_decor_add_hit_debug(evt : AddHitDecal;
                                             transform : float3x4;
                                             animchar : AnimcharBaseComponent;
                                             collres : CollisionResource;
                                             var damage_decals_decor__projectileHitCollNodeName : StringList&;
                                             var damage_decals_decor__projectileHitLocalPos : Point3List&;
                                             var damage_decals_decor__projectileHitLocalDir : Point3List&;
                                             var damage_decals_decor__projectileHitLocalNormal : Point3List&;
                                             var damage_decals_decor__projectileHitCaliber : FloatList&;
                                             var damage_decals_decor__projectileHitDamageType : StringList&)
  var nodeTm : float3x4
  collres_get_collision_node_tm(collres, evt.collNodeId, transform, animchar.nodeTree, nodeTm)
  let nodeInvTm = inverse(nodeTm)
  let nodeLocalPos = nodeInvTm * evt.pos
  let nodeLocalDir = rotate(nodeInvTm, evt.dir)
  let nodeLocalNorm = rotate(nodeInvTm, evt.normal)
  let nodeName = collres_get_node(collres, evt.collNodeId) |> collnode_get_name
  push(damage_decals_decor__projectileHitCollNodeName, nodeName)
  push(damage_decals_decor__projectileHitLocalPos, nodeLocalPos)
  push(damage_decals_decor__projectileHitLocalDir, nodeLocalDir)
  push(damage_decals_decor__projectileHitLocalNormal, nodeLocalNorm)
  push(damage_decals_decor__projectileHitCaliber, evt.caliber)
  push(damage_decals_decor__projectileHitDamageType, evt.damageType)

[es(tag=render, REQUIRE=(damage_model, damageDecalDecorDebug), REQUIRE_NOT=disableUpdate)]
def vehicle_damage_decal_decor_on_hit_debug(evt : EventOnHitByProjectile;
                                            eid : EntityId;
                                            transform : float3x4)
  let hitType = evt.pierced ? ProjectileHitType.PIERCE : ProjectileHitType.STOP
  let pos = transform * evt.localHitPos
  let dir = rotate(transform, evt.localHitDir)
  let norm = rotate(transform, evt.localNormal)
  sendEvent(eid, AddHitDecal(collNodeId = evt.nodeId, pos = pos, dir = dir, normal = norm, caliber = evt.caliber, damageType = get_decal_damage_type(hitType, evt.localHitDir, evt.localNormal, evt.bulletTypeId)))

[es(tag=render, REQUIRE=(damage_model, damageDecalDecorDebug), REQUIRE_NOT=disableUpdate)]
def vehicle_damage_decal_decor_on_ricochet_debug(evt : EventOnRicochet;
                                                 eid : EntityId;
                                                 transform : float3x4)
  let hitType = ProjectileHitType.RICOCHETE
  let pos = transform * evt.localHitPos
  let dir = rotate(transform, evt.localHitDir)
  let norm = rotate(transform, evt.localNormal)
  var bulletTypeId = -1
  ecs::query(evt.projectileEid) <| $ [es] (dm_projectile_state : ProjectileState)
    bulletTypeId = dm_projectile_state.projectileTypePropsId
  sendEvent(eid, AddHitDecal(collNodeId = evt.nodeId, pos = pos, dir = dir, normal = norm, damageType = get_decal_damage_type(hitType, evt.localHitDir, evt.localNormal, bulletTypeId)))

[console_cmd(name="damage_decals.decor_debug")]
def damage_decals_decor_debug(enable : bool = true)
  query() <| $ [es(REQUIRE=damage_model)] (eid : EntityId)
    var newTemplate : string
    if enable
      newTemplate = add_sub_template_name(eid, "vehicle_damage_decals_decor_debug")
    else
      newTemplate = remove_sub_template_name(eid, "vehicle_damage_decals_decor_debug")
    if !empty(newTemplate)
      reCreateEntityFrom(eid, newTemplate)

[console_cmd(name="damage_decals.explosion_traces_debug")]
def explosion_traces_debug_cmd(enable : bool = true)
  query() <| $ [es(REQUIRE=damage_decals__explosionNumTraces)] (eid : EntityId)
    var newTemplate : string
    if enable
      newTemplate = add_sub_template_name(eid, "shrapnel_decals_debug")
    else
      newTemplate = remove_sub_template_name(eid, "shrapnel_decals_debug")
    if !empty(newTemplate)
      reCreateEntityFrom(eid, newTemplate)
  query() <| $ [es(REQUIRE=ri_shatter_decals__traceCountPerFrame)] (eid : EntityId)
    var newTemplate : string
    if enable
      newTemplate = add_sub_template_name(eid, "rendinst_shatter_decals_debug")
    else
      newTemplate = remove_sub_template_name(eid, "rendinst_shatter_decals_debug")
    if !empty(newTemplate)
      reCreateEntityFrom(eid, newTemplate)

[es(tag=(dev, render), before=vehicle_shrapnel_decals_process_explosion)]
def damage_decals_explosion_traces_debug(evt : ParallelUpdateFrameDelayed;
                                         var damage_decals__prevExplosionPos : float3&;
                                         var damage_decals__prevExplosionRadius : float&;
                                         damage_decals__explosionPos : Point3List;
                                         damage_decals__explosionMaxTraceLen : FloatList)
  if empty(damage_decals__explosionPos)
    return
  damage_decals__prevExplosionPos = back(damage_decals__explosionPos)
  damage_decals__prevExplosionRadius = back(damage_decals__explosionMaxTraceLen)

[es(tag=(dev, render), no_order)]
def draw_damage_decals_explosion_traces_debug(evt : UpdateStageInfoRenderDebug;
                                              eid : EntityId;
                                              damage_decals__prevExplosionPos : float3;
                                              damage_decals__prevExplosionRadius : float;
                                              damage_decals__prevExplosionTraceLen : float;
                                              damage_decals__prevExplosionTraces : Point3List)
  if length(damage_decals__prevExplosionTraces) == 0
    return
  var selectedEid = INVALID_ENTITY_ID
  query() <| $ [es(REQUIRE=daeditor__selected)] (eid aka selected_eid : EntityId)
    selectedEid = selected_eid
  if selectedEid != INVALID_ENTITY_ID && selectedEid != eid
    return
  assume explosionPos = damage_decals__prevExplosionPos
  begin_draw_cached_debug_lines(true, false, false)
  draw_cached_debug_sphere(explosionPos, damage_decals__prevExplosionRadius, E3DCOLOR(0xFFFF7F00), 16)
  for tracePoint in damage_decals__prevExplosionTraces
    let dist = length(tracePoint - explosionPos)
    let hit = dist < damage_decals__prevExplosionTraceLen - 0.01
    let color = hit ? E3DCOLOR(0xFFFFFF00) : E3DCOLOR(0xFFFF0000)
    draw_cached_debug_line(explosionPos, tracePoint, color)
    if (hit)
      draw_cached_debug_sphere(tracePoint, 0.05, color, 8)
  end_draw_cached_debug_lines()

[es(tag=(dev, render), no_order)]
def draw_rendinst_shatter_decals_traces_debug(evt : UpdateStageInfoRenderDebug;
                                              ri_shatter_decals__traceFrom : Point3List;
                                              ri_shatter_decals__traceTo : Point3List;
                                              ri_shatter_decals__traceHit : UInt8List)
  begin_draw_cached_debug_lines(true, false, false)
  for from, to, hit in ri_shatter_decals__traceFrom, ri_shatter_decals__traceTo, ri_shatter_decals__traceHit
    let color = hit == 1u8 ? E3DCOLOR(0xFFFFFF00) : E3DCOLOR(0xFFFF0000)
    draw_cached_debug_line(from, to, color)
  end_draw_cached_debug_lines()

[console_cmd(name="damage_decals.spawn_on_ri")]
def damage_decal_spawn_on_ri_cmd(damage_type : string; caliber : float)
  let cameraTm = get_cur_cam_entity() |> get_TMatrix("transform") ?? IDENT_TM
  var t = 5.0f
  var pmid = -1
  var norm : float3
  var riDesc = RendInstDesc()
  if !traceray_normalized(cameraTm[3], cameraTm[2], t, pmid, norm, ETF_RI, riDesc, -1)
    console_print("surface not found")
    return

  let decalPos = cameraTm[3] + t * cameraTm[2]
  if !create_ri_projective_damage_decal(decalPos, cameraTm[2], norm, riDesc.riExtraHandle, caliber, pmid, damage_type)
    console_print("failed to spawn")

[console_cmd(name="damage_decals.toggle_glass_holes")]
def toggle_glass_hole_render_mode()
  query() <| $ [es] (var glass_decals__hole_render : bool&)
    glass_decals__hole_render = !glass_decals__hole_render
    let status = glass_decals__hole_render ? "ON" : "OFF"
    console_print("glass hole render is {status}")
