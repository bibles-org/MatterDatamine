require ecs
require AnimV20
require DagorSystem
require GeomNodeTree
require game.es.ecs_common
require game.events.events_active_matter
require active_matter.game.es.check_ammo_common


[es(tag=gameClient, on_appear)]
def gun_check_weapon_controller_init(evt : Event;
                                     eid : EntityId;
                                     animchar : AnimcharBaseComponent;
                                     gun_check_weapon__ammoNodeName : string;
                                     gun_check_weapon__bulletInsideNodeName : string;
                                     gun_check_weapon__firemodeNodeName : string;
                                     var gun_check_weapon__ammoNodeId : int&;
                                     var gun_check_weapon__bulletInsideNodeId : int&;
                                     var gun_check_weapon__firemodeNodeId : int&)
  gun_check_weapon__ammoNodeId = *animchar.nodeTree |> geomtree_findNodeIndex(gun_check_weapon__ammoNodeName)
  if gun_check_weapon__ammoNodeId < 0
    logerr("[WEAPON CHECK ANIM] {get_entity_info(eid)}: Invalid ammo node name={gun_check_weapon__ammoNodeName}")
  gun_check_weapon__bulletInsideNodeId = *animchar.nodeTree |> geomtree_findNodeIndex(gun_check_weapon__bulletInsideNodeName)
  if gun_check_weapon__bulletInsideNodeId < 0
    logerr("[WEAPON CHECK ANIM] {get_entity_info(eid)}: Invalid ammo node name={gun_check_weapon__bulletInsideNodeName}")
  gun_check_weapon__firemodeNodeId = *animchar.nodeTree |> geomtree_findNodeIndex(gun_check_weapon__firemodeNodeName)
  if gun_check_weapon__firemodeNodeId < 0
    logerr("[WEAPON CHECK ANIM] {get_entity_info(eid)}: Invalid firemode node name={gun_check_weapon__firemodeNodeName}")
  // gun_check_weapon__firerangeNodeId = *animchar.nodeTree |> geomtree_findNodeIndex(gun_check_weapon__firerangeNodeName)
  // if gun_check_weapon__firerangeNodeId < 0
  //   logerr("[WEAPON CHECK ANIM] {get_entity_info(eid)}: Invalid firerange node name={gun_check_weapon__firerangeNodeName}")


[es(tag=gameClient, on_appear, on_event=EventCheckAmmoInMark, track=(check_ammo_controller__state, isAlive))]
def human_hero_check_ammo_controller_update_mark(evt : Event;
                                                 eid : EntityId;
                                                 isAlive : bool;
                                                 human_weap__currentGunEid : EntityId;
                                                 check_ammo_controller__state : int;
                                                 human_hero_check_weapon_controller__markTemplate : string;
                                                 check_ammo_controller__ammoInspectionProgress : float;
                                                 check_ammo_controller__ammoInspectionProgressInMarkStart : float;
                                                 check_ammo_controller__ammoInspectionProgressIdleEnd : float;
                                                 var human_hero_check_weapon_controller__markEids : EidList&)
  assume ammoInspectionProgress = check_ammo_controller__ammoInspectionProgress
  assume ammoInspectionProgressInMarkStart = check_ammo_controller__ammoInspectionProgressInMarkStart
  assume ammoInspectionProgressIdleEnd = check_ammo_controller__ammoInspectionProgressIdleEnd

  let isMarkAvailableState = (check_ammo_controller__state == int(CheckAmmoState.IDLE) ||
                             check_ammo_controller__state == int(CheckAmmoState.IN))
  let markNeeded = (isAlive &&
                   isMarkAvailableState &&
                   ammoInspectionProgressInMarkStart >= 0.0 &&
                   ammoInspectionProgress >= ammoInspectionProgressInMarkStart &&
                   ammoInspectionProgress < ammoInspectionProgressIdleEnd)

  let markExists = length(human_hero_check_weapon_controller__markEids) != 0

  if markNeeded == markExists
    return

  if markNeeded
    query(human_weap__currentGunEid) <| $ [es] (gun__ammo : int;
                                                gun__firingModeName : string;
                                                gun_mods__curModInSlots : Object const?;
                                                gun_boxed_ammo_reload__reloadState : int const?;
                                                gun__maxAmmo = 0)
      let isBoxedLoadingWeapon = gun_boxed_ammo_reload__reloadState != null
      let isBulletInBarrel = gun__ammo > 0
      let currentAmmo = max(0, isBoxedLoadingWeapon ? gun__ammo : gun__ammo - 1)
      var maxAmmo = gun__maxAmmo
      if gun_mods__curModInSlots != null
        for weaponMod in *gun_mods__curModInSlots
          query(get_Eid(weaponMod.value) ?? INVALID_ENTITY_ID) <| $ [es(REQUIRE=ammo_holder__templateName)] (item_holder__maxItemCount : int)
            maxAmmo = item_holder__maxItemCount

      let ammoMarkEid = createEntity(human_hero_check_weapon_controller__markTemplate) <| $(var init)
        init |> set("check_weapon_mark__loc", "check_weapon_mark/ammo")
        using() <| $(var ammoData : Object)
          ammoData |> set("curAmmo", currentAmmo)
          ammoData |> set("maxAmmo", maxAmmo)
          init |> set("check_weapon_mark__locData", ammoData)
      sendEvent(eid, EventCheckWeaponMarker())
      human_hero_check_weapon_controller__markEids |> push(ammoMarkEid)

      if isBoxedLoadingWeapon
        human_hero_check_weapon_controller__markEids |> push(INVALID_ENTITY_ID) // to save order of mark eids
      else
        let bulletInsideMarkEid = createEntity(human_hero_check_weapon_controller__markTemplate) <| $(var init)
          init |> set("check_weapon_mark__loc", isBulletInBarrel ? "check_weapon_mark/bulletInside" : "check_weapon_mark/noBulletInside")
        human_hero_check_weapon_controller__markEids |> push(bulletInsideMarkEid)

      let firemodeMarkEid = createEntity(human_hero_check_weapon_controller__markTemplate) <| $(var init)
        init |> set("check_weapon_mark__loc", "firing_mode/firingModeFull")
        using() <| $(var firemodeData : Object)
          firemodeData |> set("mode", "firing_mode/{gun__firingModeName}")
          init |> set("check_weapon_mark__locData", firemodeData)
      human_hero_check_weapon_controller__markEids |> push(firemodeMarkEid)
  else
    for markEid in human_hero_check_weapon_controller__markEids
      destroyEntity(markEid)
    human_hero_check_weapon_controller__markEids |> clear()


[es(tag=gameClient, after=after_animchar_update_sync)]
def human_hero_check_ammo_controller_update(act : UpdateStageInfoAct;
                                            human_weap__currentGunEid : EntityId;
                                            human_hero_check_weapon_controller__markEids : EidList)
  if length(human_hero_check_weapon_controller__markEids) == 0
    return

  if length(human_hero_check_weapon_controller__markEids) != 3
    logerr("[WEAPON CHECK ANIM] Wrong human_hero_check_weapon_controller__markEids size, expected <3> has <{length(human_hero_check_weapon_controller__markEids)}>")
    return

  query(human_weap__currentGunEid) <| $ [es] (animchar : AnimcharBaseComponent;
                                              gun_check_weapon__ammoNodeId : int;
                                              gun_check_weapon__bulletInsideNodeId : int;
                                              gun_check_weapon__firemodeNodeId : int;
                                              gun_check_weapon__ammoNodeOffset : float3;
                                              gun_check_weapon__bulletInsideNodeOffset : float3;
                                              gun_check_weapon__firemodeNodeOffset : float3)
    query(human_hero_check_weapon_controller__markEids[0]) <| $ [es] (var transform : float3x4)
      *animchar.nodeTree |> geomtree_getNodeWtmScalar(gun_check_weapon__ammoNodeId, transform)
      transform[3] += rotate(transform, gun_check_weapon__ammoNodeOffset)

    query(human_hero_check_weapon_controller__markEids[1]) <| $ [es] (var transform : float3x4)
      *animchar.nodeTree |> geomtree_getNodeWtmScalar(gun_check_weapon__bulletInsideNodeId, transform)
      transform[3] += rotate(transform, gun_check_weapon__bulletInsideNodeOffset)

    query(human_hero_check_weapon_controller__markEids[2]) <| $ [es] (var transform : float3x4)
      *animchar.nodeTree |> geomtree_getNodeWtmScalar(gun_check_weapon__firemodeNodeId, transform)
      transform[3] += rotate(transform, gun_check_weapon__firemodeNodeOffset)
