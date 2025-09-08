require ecs
require ecs.safe
require game.events.events
require DngHuman
require DngWeapon
require game.events.inventory_events
require game.events.events_active_matter
require game.es.human.human_weap_mods_common


[es]
def human_optics_deviation_es(info : ParallelUpdateFrameDelayed;
                              eid : EntityId;
                              human_net_phys : HumanActor;
                              human_weap__currentGunEid : EntityId;
                              human_weap__currentGunModEids : ecs::EidList;
                              var entity_mods__shotDeviationMods : ecs::Object)
  var gunScopeEid = find_scope_eid(human_weap__currentGunModEids)
  let isIntegratedScope = get_bool(human_weap__currentGunEid, "gun__integratedScope") ?? false

  if isIntegratedScope && !gunScopeEid
    gunScopeEid = human_weap__currentGunEid

  var devMult = 1.0
  if human_net_phys.phys.currentState.isAiming
    query(gunScopeEid) <| $ [es] (gunmod__deviationMult : float)
      devMult = gunmod__deviationMult

  let itf = entity_mods__shotDeviationMods.optics_devitiation ?as float

  var changed = false
  if itf != null
    if (*itf) != devMult
      changed = true
  else
    changed = true

  entity_mods__shotDeviationMods |> set("optics_devitiation", devMult)

  if changed
    sendEvent(eid, EventOnModsChanged())


def get_scope_lens_zoom_factor(gunScopeEid : EntityId)
  var factor = 1.0
  query(gunScopeEid) <| $[es(REQUIRE_NOT=thermalScope)] (gunmod__lensActive : bool)
    if (gunmod__lensActive)
      query() <| $ [es] (camera__active : bool; camera__scopeWeaponLensZoomFactor : float)
        if camera__active
          factor = camera__scopeWeaponLensZoomFactor
  return factor


[es(REQUIRE=watchedByPlr, after=camera_set_sync, before=before_camera_sync)]
def human_optics_camera_es(info : UpdateStageInfoAct;
                           human_net_phys : HumanActor;
                           human_weap__currentGunEid : EntityId;
                           human_weap__currentGunModEids : EidList;
                           var camera__magnification : float&;
                           var human_weap__opticsAttached : bool&)
  var gunScopeEid = find_scope_eid(human_weap__currentGunModEids)
  let isIntegratedScope = get_bool(human_weap__currentGunEid, "gun__integratedScope") ?? false

  if isIntegratedScope && !gunScopeEid
    gunScopeEid = human_weap__currentGunEid

  if !human_weap__currentGunEid
    camera__magnification = 1.0
    return

  let interpK = get_phys_interpk_clamped(human_net_phys.phys, info.curTime)
  let aimPosition = lerp(human_net_phys.phys.previousState.aimPosition, human_net_phys.phys.currentState.aimPosition, interpK)

  let scopeWeapLensZoomFactor = get_scope_lens_zoom_factor(gunScopeEid)
  let zoomFactor = (get_float(gunScopeEid, "gunmod__zoomFactor") ?? 0.0) * scopeWeapLensZoomFactor
  let zoomPosition = lerp(human_net_phys.phys.previousState.zoomPosition,
                          human_net_phys.phys.currentState.zoomPosition, interpK)

  human_weap__opticsAttached = zoomFactor > 0.0

  if !human_weap__opticsAttached
    let gunMagnification = get_float(human_weap__currentGunEid, "gun__magnification") ?? 1.5
    camera__magnification = lerp(1.0, gunMagnification, zoomPosition)
    return

  camera__magnification = lerp(1.0, zoomFactor, lerp(0.0, zoomPosition, aimPosition))


[es(on_appear, REQUIRE=gunScope)]
def set_gun_optics_attached_on_init(evt : Event; slot_attach__attachedTo : EntityId)
  query(slot_attach__attachedTo) <| $ [es(REQUIRE=gun)] (var gun__opticsAttached : bool&)
    gun__opticsAttached = true


[es(REQUIRE=eid)]
def set_gun_optics_attached(evt : EventOnWeaponModEquipped)
  if !has(evt.weaponModEid, "gunScope")
    return
  query(evt.weaponEid) <| $ [es(REQUIRE=gun)] (var gun__opticsAttached : bool&)
    gun__opticsAttached = true


[es(REQUIRE=eid)]
def reset_gun_optics_attached(evt : EventOnWeaponModUnequipped)
  if !has(evt.weaponModEid, "gunScope")
    return
  query(evt.weaponEid) <| $ [es(REQUIRE=gun)] (var gun__opticsAttached : bool&)
    gun__opticsAttached = false
