require ecs
require ecs.safe
require app
require AnimV20
require math.base
require GeomNodeTree
require game.es.flashlights.flashlight_common
require DagorMath
require DagorSystem
require DagorRandom
require game.events.events_game
require HumanPhys
require DngHuman
require danetlibs.weapons.melee_events


[es(tag=server, on_appear)]
def init_weapon_flashlight_controller_server(evt : Event;
                                             eid aka weapon_eid : EntityId;
                                             weapon_flashlight_controller__templateName : string;
                                             var weapon_flashlight_controller__entityEid : EntityId&)
  if weapon_flashlight_controller__entityEid == INVALID_ENTITY_ID
    weapon_flashlight_controller__entityEid = createEntity(weapon_flashlight_controller__templateName) <| $(init)
      init |> set("attached_flashlight__actorEid", weapon_eid)
      init |> set("slot_attach__attachedTo", weapon_eid)
      init |> set("attached_flashlight__controllerEid", weapon_eid)


[es(tag=render, after=after_animchar_update_sync, before=animchar_before_render_es)]
def update_weapon_flashlight_hero(act : UpdateStageInfoAct;
                                  attached_flashlight__controllerEid : EntityId;
                                  attached_flashlight__lightScale : float;
                                  attached_flashlight__isOn : bool;
                                  attached_flashlight__extraRotationQuat : float4;
                                  var transform : float3x4)
  if !attached_flashlight__isOn
    return
  query(attached_flashlight__controllerEid) <| $[es(REQUIRE=gun__melee)] (animchar : AnimcharBaseComponent;
                                                                          weapon_flashlight_controller__nodeName : string;
                                                                          weapon_flashlight_controller__offset = float3(0.0))
    let nodeId = *animchar.nodeTree |> geomtree_findNodeIndex(weapon_flashlight_controller__nodeName)
    if nodeId < 0
      logerr("Flashlight weapon unknown position: {weapon_flashlight_controller__nodeName} nodeId < 0")
      return
    var flashlightTm : float3x4
    *animchar.nodeTree |> geomtree_getNodeWtmScalar(nodeId, flashlightTm)

    let forwardDir = flashlightTm[2]
    let finalQuat = dir_to_quat(forwardDir) * quat(attached_flashlight__extraRotationQuat)
    var tm : float3x4
    make_tm(finalQuat, flashlightTm[3], tm)
    assume offset = weapon_flashlight_controller__offset
    tm[3] += tm[0] * offset.x + tm[1] * offset.y + tm[2] * offset.z
    transform = tm * scale_tm(attached_flashlight__lightScale)


[es]
def update_flashlight_weapon_noise_on_punch(evt : EventMeleeAttackHit;
                                            human_weap__currentGunEid : EntityId)
  query(human_weap__currentGunEid) <| $[es(REQUIRE=gun__melee)] (weapon_flashlight_controller__entityEid : EntityId)
    query(weapon_flashlight_controller__entityEid) <| $[es] (weapon_flashlight__noisePeriod : float;
                                                             var weapon_flashlight__noiseEndAt : float&;
                                                             var light__brightness : float&)
      weapon_flashlight__noiseEndAt = get_sync_time() + weapon_flashlight__noisePeriod
      light__brightness = 0.0f


[es]
def update_weapon_flashlight_brightness_on_punch(evt : CmdWeapPhysUpdate;
                                                 eid aka weapon_eid : EntityId)
  query() <| $[es] (attached_flashlight__controllerEid : EntityId;
                    attached_flashlight__isOn : bool;
                    attached_flashlight__normalBrightness : float;
                    weapon_flashlight__noisePeriod : float;
                    weapon_flashlight__brightnessCoef : float;
                    weapon_flashlight__powerRange : float2;
                    weapon_flashlight__powerAdditionCoef : float2;
                    weapon_flashlight__noiseEndAt : float;
                    var weapon_flashlight__previousBrightness : float&;
                    var light__brightness : float&)
    if attached_flashlight__controllerEid != weapon_eid || !attached_flashlight__isOn
      return

    if evt.atTime < weapon_flashlight__noiseEndAt
      let progress = (evt.atTime - (weapon_flashlight__noiseEndAt - weapon_flashlight__noisePeriod)) / weapon_flashlight__noisePeriod
      let rangePow = weapon_flashlight__powerRange
      let currPow = lerp(rangePow.x, rangePow.y, progress)
      let currCoef = cvt(pow(2.f, currPow), pow(2.f, rangePow.x), pow(2.f, rangePow.y), 0.0f, 1.0f)
      var noiseBright = attached_flashlight__normalBrightness * currCoef
      noiseBright += attached_flashlight__normalBrightness * rnd_float(weapon_flashlight__powerAdditionCoef.x, weapon_flashlight__powerAdditionCoef.y)
      noiseBright = clamp(noiseBright, 0.0f, attached_flashlight__normalBrightness)

      weapon_flashlight__previousBrightness = light__brightness
      light__brightness = lerp(light__brightness, noiseBright, weapon_flashlight__brightnessCoef)
    else
      weapon_flashlight__previousBrightness = light__brightness
      light__brightness = lerp(light__brightness, attached_flashlight__normalBrightness, weapon_flashlight__brightnessCoef)


[es(REQUIRE_NOT=disableUpdate, no_order)]
def update_flashlight_weapon_switch_off_time(evt : UpdateStageInfoAct;
                                             human_net_phys : HumanActor;
                                             human_weap__currentGunEid : EntityId)
  assume weapEquipState = human_net_phys.phys.currentState.weapEquipState
  query(human_weap__currentGunEid) <| $[es] (weapon_flashlight_controller__entityEid : EntityId;
                                             weapon_flashlight_controller__checkPeriod : float;
                                             var weapon_flashlight_controller__checkAt : float&)
    if weapon_flashlight_controller__checkAt > evt.curTime
      return
    if weapEquipState.curState == HUWeaponEquipState.EES_HOLSTERING || weapEquipState.curState == HUWeaponEquipState.EES_EQUIPING
      weapon_flashlight_controller__checkAt = evt.curTime + weapon_flashlight_controller__checkPeriod
      query(weapon_flashlight_controller__entityEid) <| $[es] (var weapon_flashlight__isTurningOnOffAt : float&;
                                                               var weapon_flashlight__isTurningOn : bool&;
                                                               weapon_flashlight__onPeriod : float;
                                                               weapon_flashlight__offPeriod : float)
        let delay = weapEquipState.curState == HUWeaponEquipState.EES_HOLSTERING ? weapon_flashlight__offPeriod : weapon_flashlight__onPeriod
        weapon_flashlight__isTurningOn = weapEquipState.curState == HUWeaponEquipState.EES_HOLSTERING ? false : true
        weapon_flashlight__isTurningOnOffAt = evt.curTime + delay


// Since the flashlight on depends on the animation,
// in cases when it is not played the flashlight remains off.
// Like putting it in the slot, the animation doesn't play.
[es(track=(item__containerOwnerEid, gun__owner), REQUIRE=(gun__melee))]
def move_flashlight_weapon_to_backpack(evt : Event;
                                       eid aka flashlight_weapon_eid : EntityId;
                                       item__containerOwnerEid : EntityId;
                                       gun__owner : EntityId;
                                       weapon_flashlight_controller__entityEid : EntityId)
  query(weapon_flashlight_controller__entityEid) <| $[es] (var attached_flashlight__isOn : bool&)
    var isCurrentGun = false
    query(gun__owner) <| $[es] (human_weap__currentGunEid : EntityId)
      isCurrentGun = flashlight_weapon_eid == human_weap__currentGunEid
    attached_flashlight__isOn = !item__containerOwnerEid && isCurrentGun


[es(no_order)]
def switch_off_weapon_flashlight(evt : UpdateStageInfoAct;
                                 weapon_flashlight__isTurningOn : bool;
                                 var weapon_flashlight__isTurningOnOffAt : float&;
                                 var attached_flashlight__isOn : bool&)
  if weapon_flashlight__isTurningOnOffAt > 0.f && weapon_flashlight__isTurningOnOffAt < evt.curTime
    weapon_flashlight__isTurningOnOffAt = -1.f
    attached_flashlight__isOn = weapon_flashlight__isTurningOn


[es(tag=render, no_order)]
def changed_color_flashlight_weapon_client(evt : UpdateStageInfoAct;
                                           attached_flashlight__normalBrightness : float;
                                           attached_flashlight__controllerEid : EntityId;
                                           attached_flashlight__isOn : bool;
                                           light__color : E3DCOLOR;
                                           light__brightness : float)
  query(attached_flashlight__controllerEid) <| $ [es(REQUIRE=gun__melee)] (var dynamic_material_channels_arr : Array&)
    for channel in dynamic_material_channels_arr
      let clr = float4(Color4(light__color)).xyz
      if attached_flashlight__isOn
        let emissiveValue = float4(clr, light__brightness / attached_flashlight__normalBrightness)
        *((channel as Object)?.dynmat_param__emissive_color ?as float4) = emissiveValue
      else
        *((channel as Object)?.dynmat_param__emissive_color ?as float4) = float4(0.0)