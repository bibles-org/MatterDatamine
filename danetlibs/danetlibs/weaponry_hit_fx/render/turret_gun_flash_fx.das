require ecs
require ecs.safe
require ecs.extra_set
require ecs.common
require ecs.soa_template
require math.base
require strings
require fx
require AnimV20
require GeomNodeTree
require DaWeapons
require DagorSystem
require danetlibs.weaponry_hit_fx.main.physmat_fx_common
require PhysMat
require Dacoll
require RendInst
require DngCamera
require DagorMath


[soa_template]
struct TurretGunFx
  turret_gun_fx__fxTemplate : string
  turret_gun_fx__nodeId : int

[soa_template]
struct VegetationInfo
  vegetation_info__posHeight : float4
  vegetation_info__fxName : string
  vegetation_info__rendinstPool : int


def get_mult_tm(scale : float)
  var multTm = IDENT_TM
  multTm[0] = float3(0.0, scale,  0.0)
  multTm[1] = float3(scale, 0.0,  0.0)
  multTm[2] = float3(0.0, 0.0, -scale)
  return multTm


[es(tag=render, on_appear)]
def turret_ground_wave_fx_init_es(evt : Event;
                                  global_ground_wave_fx__maxImpulses : FloatList;
                                  var global_ground_wave_fx__effectGroups : Array&)
  if length(global_ground_wave_fx__maxImpulses) != length(global_ground_wave_fx__effectGroups)
    logerr("turret_ground_wave_fx_init_es: lengths of global_ground_wave_fx__maxImpulses and global_ground_wave_fx__effectGroups are not equal")

  for elem in global_ground_wave_fx__effectGroups
    var effectGroup = elem as Object
    if effectGroup == null
      logerr("turret_ground_wave_fx_init_es: all elements in global_ground_wave_fx__effectGroups should be 'object'")
      continue
    let infoForMats = effectGroup?.info ?as Object
    if infoForMats == null
      continue

    let defaultFx = effectGroup?.defaultFx ?? ""
    if empty(defaultFx)
      continue

    var fxs : array<string>
    resize(fxs, physMatCount())

    for_each_physmat_data(*infoForMats, /*group_prefix*/"group__") <| $(pmid : int; data : ChildComponent)
      let fxName = data as string
      if fxName == null
        logerr("turret_ground_wave_fx_init_es: all elements in 'info' in global_ground_wave_fx__effectGroups should be 't'")
        return
      elif empty(*fxName)
        fxs[pmid] := "-"
      else
        fxs[pmid] := *fxName

    *effectGroup |> set("fxs", fxs)


[es(tag=render, on_appear)]
def turret_dust_fx_init_es(evt : Event;
                           turret_dust_fx__nodes : StringList;
                           turret__owner : EntityId;
                           var turret_dust_fx__nodeIds : IntList&)
  query(turret__owner) <| $ [es] (animchar : AnimcharBaseComponent)
    for node in turret_dust_fx__nodes
      let nodeId = geomtree_findNodeIndex(*animchar.nodeTree, string(node))
      if nodeId >= 0
        turret_dust_fx__nodeIds |> push(nodeId)

def spawn_ground_wave_fx_aux(forward_dir : float3;
                             fx_up_dir : float3;
                             pos : float3;
                             fx_name : string;
                             allow_paint_from_biome : bool = false;
                             desired_biome : string = "")
  if empty(fx_name) || fx_name == "-"
    return

  var tm : float3x4
  tm[1] = normalize(fx_up_dir)
  tm[2] = normalize(cross(forward_dir, tm[1]))
  tm[0] = normalize(cross(tm[1], tm[2]))
  tm[3] = pos

  let fxTemplate = getTemplateByName(fx_name)
  if fxTemplate == null
    return

  let lowestFxQuality = getTemplateComponent(*fxTemplate, "effect__lowestFxQuality") ?? 0
  if int(get_fx_target()) < (1 << lowestFxQuality)
    return

  if allow_paint_from_biome && (getTemplateComponent(*fxTemplate, "paint_from_biome") ?? false)
    createEntity("hit_fx_readback_info") <| $(init)
      init |> set("transform", tm)
      init |> set("hit_fx_name", fx_name)
      if !empty(desired_biome)
        init |> set("biome_query__desiredBiomeName", desired_biome)
  else
    createEntity(fx_name) <| $(init)
      init |> set("transform", tm)


def count_tree_inside_radius(pos : float3; radius : float) : int
  let box = BBox3(pos - float3(radius), pos + float3(radius))
  var count = 0

  rendinst_foreachTreeInBox(box) <| $ [unused_argument(coll_info)] (coll_info : CollisionInfo)
    count++
  return count

def spawn_ground_wave_fx(cur_shell_impulse : float; fx_up_dir : float3; gun_forward_dir : float3; gun_pos : float3)
  find_query() <| $ [es] (global_ground_wave_fx__effectGroups : Array; global_ground_wave_fx__maxImpulses : FloatList)
    for elem, maxImpulse in global_ground_wave_fx__effectGroups, global_ground_wave_fx__maxImpulses
      if cur_shell_impulse > maxImpulse
        continue

      let effectGroup = elem as Object
      if effectGroup == null
        continue

      let defaultFx = effectGroup?.defaultFx ?? ""
      if empty(defaultFx)
        return true

      let maxDistanceFromGun = effectGroup?.maxDistanceFromGun ?? 1.0
      let leavesCheckRadius = effectGroup?.leavesCheckRadius ?? 10.0
      var dist = maxDistanceFromGun
      var pmid = -1
      var norm = float3()
      let traceDir = float3(0, -1, 0)

      using() <| $(var riDesc : RendInstDesc#)
        traceray_normalized(gun_pos, traceDir, dist, pmid, norm, ETF_DEFAULT, riDesc, -1)
        if dist == maxDistanceFromGun
          return

        let fxs = get_ecs_StringList(effectGroup?.fxs)
        var fx : string
        if fxs == null || pmid < 0
          fx = defaultFx
        else
          fx = string((*fxs)[pmid])
          if empty(fx)
            fx = defaultFx

        var pos = gun_pos
        pos.y -= dist

        let riexHandle = riDesc.riExtraHandle
        let isPaintFxOnHit = riex_isRiGenExtraValid(riexHandle) ? riex_isPaintFxOnHit(riexHandle) : true
        spawn_ground_wave_fx_aux(gun_forward_dir, fx_up_dir, pos, fx, isPaintFxOnHit)
        let grassFx = effectGroup?.grassFx ?? ""
        let leavesFx = effectGroup?.leavesFx ?? ""
        if !empty(grassFx) && riexHandle == RIEX_HANDLE_NULL
          spawn_ground_wave_fx_aux(gun_forward_dir, fx_up_dir, pos, grassFx, true, "grass")
        if !empty(leavesFx) && riexHandle == RIEX_HANDLE_NULL && count_tree_inside_radius(pos, leavesCheckRadius) > 0
          spawn_ground_wave_fx_aux(gun_forward_dir, fx_up_dir, pos, leavesFx, true)

      return true
    return true


def spawn_dust_fx(fx_name : string; animchar : AnimcharBaseComponent; node_ids : IntList)
  let fxTemplate = getTemplateByName(fx_name)
  if fxTemplate == null
    return

  let lowestFxQuality = getTemplateComponent(*fxTemplate, "effect__lowestFxQuality") ?? 0
  if int(get_fx_target()) < (1 << lowestFxQuality)
    return

  for nodeId in node_ids
    var dustTm : float3x4
    geomtree_getNodeWtmScalar(*animchar.nodeTree, nodeId, dustTm)

    createEntity(fx_name) <| $(var init : ComponentsInitializer)
      set(init, "transform", dustTm)


[soa_es, es(tag=render, on_event=ParallelUpdateFrameDelayed, before=clear_gun_launch_events_es, after=after_guns_update_sync)]
def turret_gun_fx_inserter_es(info : Event;
                              eid : EntityId;
                              animchar : AnimcharBaseComponent;
                              turretGunFx : TurretGunFx_SOA;
                              turret_control__gunEids : EidList;
                              transform : float3x4;
                              @shared_comp turret_gun_flash_fx__flashFxScale : Array;
                              turret_gun_fx__thresholdDistSq : float = 10000.0;
                              heroVehicle : Tag const?)
  let camTm = get_TMatrix(get_cur_cam_entity(), "transform")
  let tooFar = camTm == null ? false : distance_sq(transform[3], (*camTm)[3]) > turret_gun_fx__thresholdDistSq

  for gunEid, gunFx, fxScale in turret_control__gunEids, turretGunFx, turret_gun_flash_fx__flashFxScale
    if gunFx.turret_gun_fx__nodeId < 0 || empty(gunFx.turret_gun_fx__fxTemplate)
      continue

    query(gunEid) <| $ [es] (gun_launch_events : GunLaunchEvents;
                             gun__curShellImpulse : float;
                             turret_dust_fx__minImpulse : float;
                             turret_dust_fx__fxTemplate : string;
                             turret_dust_fx__nodeIds : IntList)
      for _launchEvent in gun_launch_events.launchEvents
        var tm : float3x4
        geomtree_getNodeWtmScalar(*animchar.nodeTree, gunFx.turret_gun_fx__nodeId, tm)
        let forwardDir = tm[0]
        tm = tm * get_mult_tm(fxScale ?? 1.0)

        createEntity(add_sub_template_name(string(gunFx.turret_gun_fx__fxTemplate),
            "autodelete_effect_entity")) <| $(var init : ComponentsInitializer)
          set(init, "transform", tm)
          set(init, "gun_fx__ownerEid", eid)
          set(init, "gun_fx__nodeId", gunFx.turret_gun_fx__nodeId)
        let isHeroVehicle = heroVehicle != null
        if !tooFar && !isHeroVehicle
          //We use tank's orientation to roughly determine the inclination of the ground under the turret.
          //This ignores any small unevenness of the ground, which is what we want
          spawn_ground_wave_fx(gun__curShellImpulse, transform[1], forwardDir, tm[3])
          if gun__curShellImpulse > turret_dust_fx__minImpulse
            spawn_dust_fx(turret_dust_fx__fxTemplate, animchar, turret_dust_fx__nodeIds)


[soa_es, es(tag=render, on_appear)]
def turret_gun_flash_fx_created_es(evt : Event;
                                   animchar : AnimcharBaseComponent;
                                   @shared_comp turret_gun_flash_fx__flashFx : Array;
                                   @shared_comp turret_gun_flash_fx__flashNodes : Array;
                                   @shared_comp turret_gun_flash_fx__flashFxScale : Array;
                                   var turretGunFx : TurretGunFx_SOA)
  if length(turret_gun_flash_fx__flashNodes) != length(turret_gun_flash_fx__flashFx) || length(turret_gun_flash_fx__flashFx) != length(turret_gun_flash_fx__flashFxScale)
    logerr("Lengths of turret_gun_flash_fx__flashNodes, turret_gun_flash_fx__flashFx and turret_gun_flash_fx__flashFxScale are not match to each other")
    return

  for flashFx, flashNode in turret_gun_flash_fx__flashFx, turret_gun_flash_fx__flashNodes
    let fx = flashFx ?? ""
    let node = flashNode ?? ""
    if empty(fx) || empty(node)
      push(turretGunFx, TurretGunFx(
        turret_gun_fx__fxTemplate = "",
        turret_gun_fx__nodeId = -1
      ))
      continue

    push(turretGunFx, TurretGunFx(
      turret_gun_fx__fxTemplate = fx,
      turret_gun_fx__nodeId = geomtree_findNodeIndex(*animchar.nodeTree, node)
    ))

[soa_def]
def get_tree_inside_radius(pos : float3; radius : float; var vegetationInfo : VegetationInfo_SOA) : int
  let box = BBox3(pos - float3(radius), pos + float3(radius))

  rendinst_foreachTreeInBox(box) <| $(coll_info : CollisionInfo)
    let height = coll_info.localBBox.width.y * coll_info.tm[1].y
    let riDesc = coll_info.desc
    let fxName = getRIGenDestrFxTemplateName(riDesc)
    if !empty(fxName)
      push(vegetationInfo, VegetationInfo(
        vegetation_info__posHeight = float4(coll_info.tm[3], height),
        vegetation_info__fxName = fxName,
        vegetation_info__rendinstPool = riDesc.pool
      ))
    else
      let riName = getRIGenResName(riDesc)
      logerr("RendInts vegetation <{riName}> has empty destrFxTemplate")


  return length(vegetationInfo)

def spawn_effect_aux(pos : float3; fx_name : string; rendinst_pool : int)
  var tm = IDENT_TM
  tm[3] = pos
  createEntity(fx_name) <| $(init)
    init |> set("transform", tm)
    init |> set("effect__riPoolUsedForColoring", rendinst_pool)

[soa_es, es(tag=render, on_appear, REQUIRE=effect__environmentDestruction)]
def spawn_enviroment_fx_from_expl_es(evt : Event;
                                     transform : float3x4;
                                     effect__environmentDestructionRadius : float;
                                     var vegetationInfo : VegetationInfo_SOA)
  if int(get_fx_target()) <= int(FxQuality.FX_QUALITY_LOW)
    return

  let tree_count = get_tree_inside_radius(transform[3], effect__environmentDestructionRadius, vegetationInfo)
  if tree_count == 0
    return
  for info in vegetationInfo
    let pos = info.vegetation_info__posHeight
    let resultPos = float3(pos.x, pos.y, pos.z)
    let rendinstPool = info.vegetation_info__rendinstPool
    let fxName = string(info.vegetation_info__fxName)
    spawn_effect_aux(resultPos, fxName, rendinstPool)
