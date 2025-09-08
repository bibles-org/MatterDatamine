require ecs
require ecs.common
require ecs.safe
require DngNet
require Dacoll
require DagorMath
require math.base
require GeomNodeTree
require Gun
require game.es.level_common
require game.events.events_game
require game.events.vehicle_events
require game.es.ecs_common
require game.es.human_weap_common
require game.es.status_tip_common
require DagorDataBlock
require Gun
require DngPhys
require DngWeapon
require AnimV20
require HumanPhys
require PhysDecl
require PhysVars
require AnimatedPhys
require PhysMat
require DngHuman
require DagorDebug3D
require DagorDebug3DSolid
require game.es.human.human_gun_common
require game.events.events_active_matter


[es(on_appear)]
def gun_attach__mainSlotId_init(evt : Event;
                                gun_attach__slot : string;
                                var gun_attach__mainSlotId : int&)
  gun_attach__mainSlotId = animchar_getSlotId(gun_attach__slot)


[es(on_appear)]
def gun_attach__holsterSlotsIds_init(evt : Event;
                                     gun_attach__holsterSlots : Array const?;
                                     var gun_attach__holsterSlotsIds : IntList)
  gun_attach__holsterSlotsIds |> resize(int(HUWeaponSlots.EWS_NUM))
  var i = 0

  if gun_attach__holsterSlots != null
    let holsterSlotsCount = length(*gun_attach__holsterSlots)
    verify(holsterSlotsCount <= int(HUWeaponSlots.EWS_NUM))

    while i < holsterSlotsCount
      let slotName = get_ecs_string((*gun_attach__holsterSlots)[i])
      gun_attach__holsterSlotsIds[i] = (slotName != null
                                          ? animchar_getSlotId(*slotName |> string())
                                          : -1)
      ++i

  while i < int(HUWeaponSlots.EWS_NUM)
    gun_attach__holsterSlotsIds[i] = -1
    ++i


[es(REQUIRE=(animchar_render__enabled, gun__propsId),
    REQUIRE_NOT=skip_common_weap_phys_update)]
def human_gun_es(evt : CmdWeapPhysUpdate;
                 eid : EntityId;
                 human_gun_attached : bool)
  if !human_gun_attached
    return

  let atTime = evt.atTime
  let isForReal = evt.isForReal
  let gctrl = evt.gctrl
  let gloc = evt.gloc
  let rndSeed = phys_time_to_seed(atTime)
  sendEventImmediate(eid, CmdGunUpdate(atTime = atTime, isForReal = isForReal, seed = rndSeed, gctrl = gctrl, gloc = gloc))


[es(no_order, REQUIRE=animchar_render__enabled)]
def human_gun_attach_es(evt : CmdWeapAttach;
                        gun_attach__mainSlotId : int;
                        gun_attach__holsterSlotsIds : IntList const?;
                        var human_gun_attached : bool&;
                        var slot_attach__slotId : int&;
                        var slot_attach__attachedTo : EntityId&;
                        var slot_attach__visible : bool&)
  let attachFlag = evt.isAttached
  let slotId = evt.slotId
  let weaponHolster = (gun_attach__holsterSlotsIds != null
                      ? ((*gun_attach__holsterSlotsIds)[slotId] >= 0)
                      : false)

  var ownerEid = evt.toEid
  query(evt.toEid) <| $ [es] (attachable_suit_controller__holsterAttachedAnimchars : StringList;
                              attachable_suit_controller__attachedAnimcharEids : Object)
    // Holster slot on the suit animchar
    if !attachFlag && weaponHolster
      if slotId >= length(attachable_suit_controller__holsterAttachedAnimchars)
        return

      assume holsterAnimcharName = attachable_suit_controller__holsterAttachedAnimchars[slotId]
      if holsterAnimcharName == ""
        return

      let attachedAnimcharEid = attachable_suit_controller__attachedAnimcharEids[string(holsterAnimcharName)] ?? INVALID_ENTITY_ID
      if attachedAnimcharEid != INVALID_ENTITY_ID
        ownerEid = attachedAnimcharEid

  if ownerEid == INVALID_ENTITY_ID
    return

  slot_attach__visible = (attachFlag || weaponHolster)
  if attachFlag
    slot_attach__attachedTo = ownerEid
    slot_attach__slotId = gun_attach__mainSlotId
  elif weaponHolster
    slot_attach__attachedTo = ownerEid
    slot_attach__slotId = (*gun_attach__holsterSlotsIds)[slotId]
  else
    slot_attach__attachedTo = INVALID_ENTITY_ID
    slot_attach__slotId = -1

  human_gun_attached = attachFlag


[es]
def reattach_weapons(evt : EventReattachWeapons;
                     eid aka actor_eid : EntityId;
                     human_weap__gunEids : EidList;
                     human_weap__currentGunSlot : int)
  update_weapons_attachment(actor_eid, human_weap__gunEids, human_weap__currentGunSlot)


[es]
def reattach_weapon(evt : EventReattachWeapon;
                    eid aka actor_eid : EntityId;
                    human_weap__gunEids : EidList;
                    human_weap__currentGunSlot : int)
  update_weapon_attachment(actor_eid, evt.slot, human_weap__gunEids, human_weap__currentGunSlot)


[es(on_appear, REQUIRE=suit_attachable_animchar)]
def suit_attachable_animchar_on_appear(evt : Event;
                                       slot_attach__attachedTo : EntityId)
  if getEntityTemplateName(slot_attach__attachedTo) != ""
    sendEvent(slot_attach__attachedTo, EventReattachWeapons())


[es(on_disappear, REQUIRE=(human_gun_attached, item__invisible), after=unhide_animchar)]
def human_gun_unhide_animchar(evt : Event;
                              slot_attach__attachedTo : EntityId;
                              item__containerOwnerEid : EntityId;
                              item__humanOwnerEid : EntityId;
                              var slot_attach__visible : bool&;
                              var animchar_render__enabled : bool&)
  // Gun equipped - show it if attached
  if item__containerOwnerEid == INVALID_ENTITY_ID && item__humanOwnerEid != INVALID_ENTITY_ID
    slot_attach__visible = slot_attach__attachedTo != INVALID_ENTITY_ID
    animchar_render__enabled = slot_attach__visible


[es(tag=render)]
def human_gun_detach_es(evt : CmdWeapDetach;
                        var animchar : AnimcharBaseComponent;
                        var ragdoll : PhysRagdoll;
                        var transform : float3x4)
  var rootTm = IDENT_TM
  animchar |> animchar_get_tm(rootTm)
  transform = rootTm

  if distance_sq(transform[3], get_hidden_pos()) > 1.0
    ragdoll |> ragdoll_startRagdoll(1, -1, animchar.nodeTree)
    animchar |> animchar_setPostController(ragdoll)


[es(tag=server, track=(human_weap__currentGunSlot, human_weap__gunEids))]
def human_gun_deflect_es(evt : Event;
                         human_weap__currentGunSlot : int;
                         human_weap__gunEids : EidList;
                         var human_weap__bulletDeflectionAngle : float&;
                         var human_weap__bulletDeflectionArmor : float&)
  let gun = human_weap__currentGunSlot >= 0 ? human_weap__gunEids[human_weap__currentGunSlot] : INVALID_ENTITY_ID
  query(gun) <| $ [es] (bulletDeflectAngle : float = 0.0;
                        bulletDeflectArmor : float = 0.0)
    human_weap__bulletDeflectionAngle = bulletDeflectAngle
    human_weap__bulletDeflectionArmor = bulletDeflectArmor


[es(tag=server, no_order)]
def human_gun_reset_reload_anim_es(evt : CmdWeapAttach;
                                   var gun__holsterGen : int&)
  let attachFlag = evt.isAttached
  if !attachFlag
    ++gun__holsterGen


def reset_reload_anim(gun_anim__reloadVarId : int;
                      gun_anim__singleReloadVarId : int;
                      var physVars : PhysVars;
                      var animchar : AnimcharBaseComponent;
                      var animPhys : AnimatedPhys)
  physVars |> setVar(gun_anim__reloadVarId, -1.0)
  physVars |> setVar(gun_anim__singleReloadVarId, -1.0)
  animPhys |> anim_phys_update(animchar, physVars)
  animchar |> animchar_act(0.01, true)


[es(before=before_animchar_update_sync)]
def human_gun_reset_reload_anim_client_es(info : UpdateStageInfoAct;
                                          eid : EntityId;
                                          gun_anim__reloadVarId : int;
                                          gun_anim__singleReloadVarId : int;
                                          gun__holsterGen : int;
                                          var gun__prevHolsterGen : int&;
                                          var phys_vars : PhysVars;
                                          var animchar : AnimcharBaseComponent;
                                          var anim_phys : AnimatedPhys)
  if gun__holsterGen != gun__prevHolsterGen
    gun__prevHolsterGen = gun__holsterGen
    reset_reload_anim(gun_anim__reloadVarId, gun_anim__singleReloadVarId, phys_vars, animchar, anim_phys)
    set_weapon_operation_state(int(GunOperationState.BOLTACTION), eid)


[es]
def human_gun_reset_reload_anim_on_vehicle_enter_client_es(evt : EventEnterVehicle;
                                                           eid : EntityId;
                                                           gun_anim__reloadVarId : int;
                                                           gun_anim__singleReloadVarId : int;
                                                           var phys_vars : PhysVars;
                                                           var animchar : AnimcharBaseComponent;
                                                           var anim_phys : AnimatedPhys)
  reset_reload_anim(gun_anim__reloadVarId, gun_anim__singleReloadVarId, phys_vars, animchar, anim_phys)
  set_weapon_operation_state(int(GunOperationState.BOLTACTION), eid)


[es(on_appear)]
def human_gun_anim_vars_setup(evt : Event;
                              animchar : AnimcharBaseComponent;
                              gun_aim_offset__animcharTraceCenterNodeName : string;
                              var gun_aim_offset__animcharTraceCenterNodeId : int&)
  if animchar.nodeTree != null
    gun_aim_offset__animcharTraceCenterNodeId = *animchar.nodeTree |> geomtree_findNodeIndex(gun_aim_offset__animcharTraceCenterNodeName)


[es(tag=gameClient, before=human_gun_anim_vars, REQUIRE=(hero, human_weap__checkObstaclesAround))]
def human_gun_anim_vars_check_obstacles_around(info : UpdateStageInfoAct;
                                               human_weap__currentGunEid : EntityId;
                                               gun_aim_offset__animcharTraceCenterNodeId : int;
                                               gun_aim_offset__gunOffsetAddNearWalls : float3;
                                               animchar : AnimcharBaseComponent;
                                               transform : float3x4;
                                               gun_aim_offset__leanAngles : float2;
                                               human_net_phys : HumanActor;
                                               var gun_aim_offset__gunOffsetAddWish : Object&;
                                               gun_aim_offset_debug : Tag const?)
  var sphereCheckRad = 1.0
  query(human_weap__currentGunEid) <| $ [es] (gun__length : float)
    sphereCheckRad += cvt(gun__length, 0.4, 1.5, 0.2, 1.0)
  dacoll_use_sphere_collision() <| $(var coll : CollisionObject)
    if gun_aim_offset__animcharTraceCenterNodeId == -1
      return
    if human_net_phys.phys.currentState.weapEquipState.curState == HUWeaponEquipState.EES_DOWN || sphereCheckRad == 0.0
      gun_aim_offset__gunOffsetAddWish |> erase("wallsCollision")
      return
    var tm = IDENT_TM
    tm[3] = geomtree_getNodeWpos(*animchar.nodeTree, gun_aim_offset__animcharTraceCenterNodeId)
    dacoll_set_collision_object_tm(coll, tm)
    dacoll_set_collision_sphere_rad(coll, sphereCheckRad)
    if gun_aim_offset_debug != null
      dacoll_draw_collision_object(coll)
    var haveCollision = false
    let pos = float3()
    let bsphere = BSphere3(pos, 2.0 * sphereCheckRad)
    test_collision_ri(coll, bsphere) <| $(contacts : array<CollisionContactData>#)
      for contact in contacts
        let dirVec = normalize(contact.wpos - tm[3])
        let angle = float2(dot(transform[1], dirVec), dot(transform[0], dirVec))
        if abs(angle.x) < gun_aim_offset__leanAngles.x && angle.y > gun_aim_offset__leanAngles.y
          haveCollision = true
          gun_aim_offset_debug
          if gun_aim_offset_debug == null
            break
          else
            draw_debug_line_buffered(tm[3], contact.wpos, E3DCOLOR(0xFF00FF00), 1)
            draw_debug_sphere_buffered(contact.wpos, 0.1, E3DCOLOR(0xFF00FF00), 6, 1)
            draw_debug_text_mark_buffered(contact.wpos, "{angle}", 1)
        elif gun_aim_offset_debug != null
          draw_debug_line_buffered(tm[3], contact.wpos, E3DCOLOR(0xFFFF0000), 1)
          draw_debug_sphere_buffered(contact.wpos, 0.1, E3DCOLOR(0xFFFF0000), 6, 1)
          draw_debug_text_mark_buffered(contact.wpos, "{angle}", 1)
    if haveCollision
      gun_aim_offset__gunOffsetAddWish |> set("wallsCollision", gun_aim_offset__gunOffsetAddNearWalls)


[es(tag=gameClient, before=human_gun_anim_vars, REQUIRE=hero)]
def human_gun_anim_vars_pull_on_shoot(info : UpdateStageInfoAct;
                                      human_weap__currentGunEid : EntityId;
                                      human_net_phys : HumanActor;
                                      human_net_phys__isAiming, isShootingAllowed : bool;
                                      gun_aim_offset__gunShootOffsetAdd : float3;
                                      gun_aim_offset__gunShootOffsetWaitTime : float;
                                      var gun_aim_offset__gunShootOffsetEnable : bool&;
                                      var gun_aim_offset__gunShootOffsetReturnAt : float&;
                                      var gun_aim_offset__gunOffsetAddWish : Object&)
  if gun_aim_offset__gunShootOffsetEnable
    if is_control_bit_set(human_net_phys.phys.appliedCT, HumanPhysControlType.HCT_SHOOT)
      gun_aim_offset__gunShootOffsetReturnAt = -1.0
    if !isShootingAllowed || human_net_phys__isAiming || !is_control_bit_set(human_net_phys.phys.appliedCT, HumanPhysControlType.HCT_SHOOT)
      if !human_net_phys__isAiming
        if gun_aim_offset__gunShootOffsetReturnAt < 0.0
          gun_aim_offset__gunShootOffsetReturnAt = info.curTime + gun_aim_offset__gunShootOffsetWaitTime
          return
        elif info.curTime < gun_aim_offset__gunShootOffsetReturnAt
          return
        gun_aim_offset__gunShootOffsetReturnAt = -1.0

      gun_aim_offset__gunShootOffsetEnable = false
      gun_aim_offset__gunOffsetAddWish |> erase("shoot")
  else
    let isStableWeapon = human_weap__currentGunEid |> has("gun_aim_offset__gunShootStableWeapon")
    if isShootingAllowed && !isStableWeapon && !human_net_phys__isAiming && is_control_bit_set(human_net_phys.phys.appliedCT, HumanPhysControlType.HCT_SHOOT)
      var offset = gun_aim_offset__gunShootOffsetAdd
      query(human_weap__currentGunEid) <| $ [es] (gun_aim_offset__gunShootOffsetCustomAdd : float3)
        offset = gun_aim_offset__gunShootOffsetCustomAdd
      gun_aim_offset__gunShootOffsetEnable = true
      gun_aim_offset__gunOffsetAddWish |> set("shoot", offset)


[unused_argument(human_weap__currentGunEid),
 es(tag=gameClient, before=human_gun_anim_vars, REQUIRE=hero, track=human_weap__currentGunEid)]
def human_gun_anim_vars_pull_on_weapon_change(evt : Event;
                                              human_weap__currentGunEid : EntityId;
                                              gun_aim_offset__gunShootOffsetEnable : bool;
                                              var gun_aim_offset__gunOffsetAddWish : Object&)
  if gun_aim_offset__gunShootOffsetEnable
    gun_aim_offset__gunOffsetAddWish |> erase("shoot")


[es(tag=gameClient, before=before_animchar_update_sync, REQUIRE_NOT=sleeping_monster)]
def human_gun_anim_vars(act : UpdateStageInfoAct;
                        human_weap__currentGunEid : EntityId;
                        gun_aim_offset__gunOffsetApproachViscosity : float;
                        gun_aim_offset__gunOffsetAlongId : int;
                        gun_aim_offset__gunOffsetAcrossId : int;
                        gun_aim_offset__gunOffsetUpId : int;
                        gun_aim_offset__gunOffsetAddWish : Object;
                        human_net_phys__standState : int;
                        var gun_aim_offset__gunOffsetCurrent : float3&;
                        var animchar : AnimcharBaseComponent)
  var weaponBaseOffset : float3
  var weaponDynamicPositionOffset : float3
  query(human_weap__currentGunEid) <| $ [es] (gun_aim_offset__gunOffsets : Point3List;
                                              gun_dynamic_position__offset : float3 = float3(0.0))
    if human_net_phys__standState < length(gun_aim_offset__gunOffsets)
      weaponBaseOffset = gun_aim_offset__gunOffsets[human_net_phys__standState]
    weaponDynamicPositionOffset = gun_dynamic_position__offset

  var gunOffsetAddWish : float3
  for offset in gun_aim_offset__gunOffsetAddWish
    gunOffsetAddWish += offset.value ?? float3(0.0)
  let targetOffset = weaponBaseOffset + gunOffsetAddWish + float3(weaponDynamicPositionOffset.z, weaponDynamicPositionOffset.y, weaponDynamicPositionOffset.x)
  gun_aim_offset__gunOffsetCurrent = approach(
    gun_aim_offset__gunOffsetCurrent, targetOffset, act.dt, gun_aim_offset__gunOffsetApproachViscosity
  )

  assume animState = animchar.animState
  if gun_aim_offset__gunOffsetAcrossId >= 0
    *animState |> anim_state_holder_setParam(gun_aim_offset__gunOffsetAcrossId, gun_aim_offset__gunOffsetCurrent.x)
  if gun_aim_offset__gunOffsetUpId >= 0
    *animState |> anim_state_holder_setParam(gun_aim_offset__gunOffsetUpId, gun_aim_offset__gunOffsetCurrent.y)
  if gun_aim_offset__gunOffsetAlongId >= 0
    *animState |> anim_state_holder_setParam(gun_aim_offset__gunOffsetAlongId, gun_aim_offset__gunOffsetCurrent.z)


[es]
def human_gun_collision_links_update(info : ParallelUpdateFrameDelayed;
                                     var human_net_phys : HumanActor&;
                                     var gun_aim_offset__lastShootAt : float&;
                                     gun_aim_offset__gunCollisionLinksShootPeriod : float;
                                     human_net_phys__isAiming : bool;
                                     human_weap__currentGunEid : EntityId)
  assume phys = human_net_phys.phys
  let currentTime = info.curTime
  query(human_weap__currentGunEid) <| $[es] (gun : Gun)
    if gun.curState.isPrevAppliedControlShoot
      gun_aim_offset__lastShootAt = currentTime
  let shootingWasRecent = gun_aim_offset__lastShootAt + gun_aim_offset__gunCollisionLinksShootPeriod > currentTime
  let activateCollisionLinks = human_net_phys__isAiming || shootingWasRecent

  let gunLen = max(0.001, phys.weaponParams[int(phys.currentState.weapEquipState.curSlot)].gunLen)
  let stands = [HUStandState.ESS_STAND, HUStandState.ESS_CROUCH, HUStandState.ESS_CRAWL]
  let standScales = [1.f, 1.f, 0.5f]
  for i in range(length(stands))
    let stand = stands[i]
    phys |> human_phys_getCollisionLinkData(stand, "weapon") <| $(var link : CollisionLinkData&)
      link.haveCollision = activateCollisionLinks
      if activateCollisionLinks
        let scale = phys.scale
        let standScale = standScales[i]
        link.offset = float3(gunLen, 0., 0.) * scale * standScale
      return true


[es(tag=(gameClient, net), track=gun__firingModeIndex)]
def human_gun_update_firing_mode_client_es(evt : Event;
                                           var gun : Gun;
                                           gun__firingModeIndex : int)
  gun |> gun_setFiringModeIndex(uint8(gun__firingModeIndex))


[es(tag=gameClient, on_appear, track=(gun__firingModeNames, gun__firingModeIndex))]
def human_gun_update_firing_mode_name_es(evt : Event;
                                         gun__firingModeNames : Array;
                                         gun__firingModeIndex : int;
                                         var gun__firingModeName : das_string)
  if gun__firingModeIndex >= 0
    gun__firingModeName := get_string(gun__firingModeNames[gun__firingModeIndex], "")
  else
    gun__firingModeName := ""


[es(tag=gameClient, track=gun__firingModeIndex, after=human_gun_update_firing_mode_name_es,
    REQUIRE=(gun__firingModeIndex, watchedPlayerItem))]
def human_gun_create_tip_on_firing_mode_change(evt : Event;
                                               gun__firingModeName : string)
  create_status_tip("status_tip_firing_mode_{gun__firingModeName}")


[es(on_appear)]
def human_weap_init_gun_trace(evt : Event;
                              human_weap__gunMat : string = "gunRay";
                              var human_weap__gunMatId : int&)
  human_weap__gunMatId = get_material_id(human_weap__gunMat)


[es(on_appear)]
def set_gun_aim_offset_ids(evt : Event;
                           animchar : AnimcharBaseComponent;
                           var gun_aim_offset__reyeOffsetFwd0Id : int&;
                           var gun_aim_offset__gunOffsetAlongId : int&;
                           var gun_aim_offset__gunOffsetAcrossId : int&;
                           var gun_aim_offset__gunOffsetUpId : int&)
  assume animGraph = animchar.animGraph
  gun_aim_offset__reyeOffsetFwd0Id = *animGraph |> anim_graph_getParamId("reye_offset_fwd0", int(PT_ScalarParam))
  gun_aim_offset__gunOffsetAlongId = *animGraph |> anim_graph_getParamId("gun_offset_along", int(PT_ScalarParam))
  gun_aim_offset__gunOffsetAcrossId = *animGraph |> anim_graph_getParamId("gun_offset_across", int(PT_ScalarParam))
  gun_aim_offset__gunOffsetUpId = *animGraph |> anim_graph_getParamId("gun_offset_up", int(PT_ScalarParam))
