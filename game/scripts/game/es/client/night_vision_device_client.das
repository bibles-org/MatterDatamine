require ecs
require ecs.safe
require ecs.common
require math.base
require AnimV20
require DagorConsole
require DagorSystem
require PhysVars
require game.es.action_common
require game.es.client.postfx_fade_common
require game.events.events_game
require game.es.flashlights.flashlight_common
require game.events.inventory_events
require DngActor
require DngHuman
require Dacoll
require GeomNodeTree


def get_night_vision_device_postfx_fade_layer_hash()
  return int(ecs_hash("binoculars"))


def set_night_vision_device_visibility(eid : EntityId; is_enable : bool)
  let isReplayTpsCam = find_query() <| $ [es(REQUIRE=replayCamera)] (camera__active, isTpsView : bool)
    return camera__active && isTpsView
  if !isReplayTpsCam
    query(eid) <| $ [es] (var slot_attach__visible : bool?; var animchar_render__enabled : bool&)
      // "slot_attach__visible" component is not present when entity is not equipped.
      // In such a case, toggle render directly
      if slot_attach__visible != null
        *slot_attach__visible = is_enable
      else
        animchar_render__enabled = is_enable

def get_night_vision_device_actor(night_vision_device_attached_to : EntityId)
  var res = night_vision_device_attached_to
  query(night_vision_device_attached_to) <| $ [es(REQUIRE=equipment_item)] (slot_attach__attachedTo : EntityId)
    res = slot_attach__attachedTo

  return res


[es(tag=gameClient, on_disappear, REQUIRE=(night_vision_device, slot_attach__attachedTo))]
def night_vision_device_detached_client(evt : Event;
                                        slot_attach__attachedTo : EntityId;
                                        night_vision_device__isOn : bool)
  if night_vision_device__isOn
    let heroEid = get_night_vision_device_actor(slot_attach__attachedTo)
    query(heroEid) <| $ [es] (watchedByPlr : EntityId const?;
                              attaches_list : EidList)
      if watchedByPlr != null
        query() <| $ [es(REQUIRE=screenNightVisionEffect)] (var screen_night_vision__enabled : bool&)
          screen_night_vision__enabled = false

      for attachEid in attaches_list
        query(attachEid) <| $ [es] (attached_flashlight_controller__entityEid : EntityId;
                                    flashlight_device__type : int)
          if flashlight_device__type != int(FlashlightType.INFRARED)
            return
          query(attached_flashlight_controller__entityEid) <| $ [es] (var attached_flashlight__isOn : bool&)
            attached_flashlight__isOn = false


[es(tag=gameClient, on_appear)]
def night_vision_animation_effect_appear(evt : Event;
                                         nvd_animation__nvdDevice, game_effect__attachedTo : EntityId;
                                         game_effect__forceAnimState, nvd_animation__sequenceName : string)
  query(nvd_animation__nvdDevice) <| $ [es] (var animchar : AnimcharBaseComponent)
    assume animGraph = animchar.animGraph
    if animGraph == null
      return
    let stateIdx = *animGraph |> anim_graph_getStateIdx(game_effect__forceAnimState)
    *animGraph |> anim_graph_enqueueState(*animchar.animState, stateIdx)
    if game_effect__attachedTo |> has("watchedByPlr")
      createEntity(nvd_animation__sequenceName) <| $(var init)
        init |> set("nvd_visual_sequence__nvdDevice", nvd_animation__nvdDevice)


[es(tag=gameClient, no_order, REQUIRE=nvd_visual_sequence__isDown)]
def night_vision_down_visual_sequence_apply(act : UpdateStageInfoAct;
                                            eid, nvd_visual_sequence__nvdDevice : EntityId;
                                            var nvd_visual_sequence__state : int&;
                                            var nvd_visual_sequence__curTime : float&)
  nvd_visual_sequence__curTime += act.dt
  if nvd_visual_sequence__curTime == act.dt
    nvd_visual_sequence__nvdDevice |> set_night_vision_device_visibility(true)
  elif nvd_visual_sequence__state == 0 && nvd_visual_sequence__curTime >= 0.55 // TODO: maybe usage IRQ is better?
    postfx_fadein(float4(Color4(E3DCOLOR(0xFF010201))), 0.15, get_night_vision_device_postfx_fade_layer_hash())
    nvd_visual_sequence__state = 1
  elif nvd_visual_sequence__state == 1 && nvd_visual_sequence__curTime >= 0.75
    nvd_visual_sequence__state = 2
    nvd_visual_sequence__nvdDevice |> set_night_vision_device_visibility(false)
  elif nvd_visual_sequence__state == 2 && nvd_visual_sequence__curTime >= 0.875
    postfx_fadeout(0.3, get_night_vision_device_postfx_fade_layer_hash())
    ecs::query() <| $ [es(REQUIRE=screenNightVisionEffect)] (var screen_night_vision__enabled : bool&)
      screen_night_vision__enabled = true
    destroyEntity(eid)


[es(tag=gameClient, no_order, REQUIRE=nvd_visual_sequence__isUp)]
def night_vision_up_visual_sequence_apply(act : UpdateStageInfoAct;
                                          eid, nvd_visual_sequence__nvdDevice : EntityId;
                                          var nvd_visual_sequence__state : int&;
                                          var nvd_visual_sequence__curTime : float&)
  nvd_visual_sequence__curTime += act.dt
  if nvd_visual_sequence__curTime == act.dt
    postfx_fadein(float4(Color4(E3DCOLOR(0xFF010201))), 0.1, get_night_vision_device_postfx_fade_layer_hash())
  elif nvd_visual_sequence__state == 0 && nvd_visual_sequence__curTime >= 0.05
    nvd_visual_sequence__nvdDevice |> set_night_vision_device_visibility(true)
    ecs::query() <| $ [es(REQUIRE=screenNightVisionEffect)] (var screen_night_vision__enabled : bool&)
      screen_night_vision__enabled = false
    nvd_visual_sequence__state = 1
  elif nvd_visual_sequence__state == 1 && nvd_visual_sequence__curTime >= 0.35
    postfx_fadeout(0.3, get_night_vision_device_postfx_fade_layer_hash())
    nvd_visual_sequence__state = 2
  elif nvd_visual_sequence__state == 2 && nvd_visual_sequence__curTime >= 1.0
    nvd_visual_sequence__nvdDevice |> set_night_vision_device_visibility(false)
    destroyEntity(eid)


[es(tag=gameClient, REQUIRE=(watchedByPlr, attaches_list), on_disappear)]
def night_vision_effect_on_spectator_disappear(evt : Event)
  ecs::query() <| $ [es(REQUIRE=screenNightVisionEffect)] (var screen_night_vision__enabled : bool&)
    screen_night_vision__enabled = false


[es(tag=gameClient, REQUIRE=watchedByPlr, on_appear)]
def night_vision_effect_on_spectator_appear(evt : Event;
                                            attaches_list : EidList)
  for attach in attaches_list
    query(attach) <| $ [es] (equipment_mods__curModInSlots : Object)
      for modInSlotData in equipment_mods__curModInSlots
        let modEid = modInSlotData.value ?? INVALID_ENTITY_ID
        query(modEid) <| $ [es] (night_vision_device__isOn : bool)
          if night_vision_device__isOn
            ecs::query() <| $ [es(REQUIRE=screenNightVisionEffect)] (var screen_night_vision__enabled : bool&)
              screen_night_vision__enabled = true


def is_screen_night_vision_enabled()
  var result = false
  ecs::query() <| $ [es(REQUIRE=screenNightVisionEffect)] (screen_night_vision__enabled : bool)
    result = screen_night_vision__enabled
  return result


[es(tag=gameClient, REQUIRE=night_vision_device, track=night_vision_device__isOn)]
def night_vision_device_track_on(evt : Event;
                                 eid aka night_vision_device_eid : EntityId;
                                 night_vision_device__isOn : bool;
                                 slot_attach__attachedTo : EntityId;
                                 night_vision_device__obstacleTracesInterval : float;
                                 attached_flashlight_controller__entityEid : EntityId;
                                 var night_vision_device__nextObstacleTraceAt : float&)
  let heroEid = get_night_vision_device_actor(slot_attach__attachedTo)
  query(heroEid) <| $ [es(REQUIRE_NOT=hero)] ()
    query(attached_flashlight_controller__entityEid) <| $ [es] (var attached_flashlight__isOn : bool&)
      let infraredFlashlightOn = night_vision_device__isOn && is_screen_night_vision_enabled()
      attached_flashlight__isOn = infraredFlashlightOn

      if infraredFlashlightOn
        night_vision_device__nextObstacleTraceAt = eid_frnd(night_vision_device_eid) * night_vision_device__obstacleTracesInterval


[es(tag=gameClient, on_appear, track=screen_night_vision__enabled)]
def screen_night_vision_track_enabled(evt : Event;
                                      screen_night_vision__enabled : bool)
  query() <| $ [es] (attached_flashlight__type : int;
                     var attached_flashlight__isOn : bool&)
    if attached_flashlight__type == int(FlashlightType.INFRARED)
      attached_flashlight__isOn = screen_night_vision__enabled


[es(tag=gameClient, on_appear)]
def attached_infrared_flashlight_init(evt : Event;
                                      attached_flashlight__type : int;
                                      var attached_flashlight__isOn : bool&)
  if attached_flashlight__type == int(FlashlightType.INFRARED)
    if !is_screen_night_vision_enabled()
      attached_flashlight__isOn = false


[es(tag=gameClient, REQUIRE=night_vision_device, no_order)]
def night_vision_device_obstacle_traces(act : UpdateStageInfoAct;
                                        night_vision_device__isOn : bool;
                                        night_vision_device__maxObstacleTraceDistance : float;
                                        night_vision_device__flashlightBrightnessRange : float2;
                                        night_vision_device__obstacleTracesInterval : float;
                                        night_vision_device__flashlightAdaptationFactor : float;
                                        night_vision_device__obstacleTraceSphereRadius : float;
                                        attached_flashlight_controller__entityEid : EntityId;
                                        var night_vision_device__nextObstacleTraceAt : float&;
                                        var night_vision_device__flashlightTargetBrightness : float&)
  assume maxObstacleTraceDistance = night_vision_device__maxObstacleTraceDistance
  assume flashlightBrightnessRange = night_vision_device__flashlightBrightnessRange
  assume obstacleTracesInterval = night_vision_device__obstacleTracesInterval
  assume flashlightAdaptationFactor = night_vision_device__flashlightAdaptationFactor
  assume obstacleTraceSphereRadius = night_vision_device__obstacleTraceSphereRadius
  assume flashlightTargetBrightness = night_vision_device__flashlightTargetBrightness

  if night_vision_device__isOn && is_screen_night_vision_enabled()
    query(attached_flashlight_controller__entityEid) <| $ [es] (transform : float3x4;
                                                                var light__brightness : float&)
      // Obstacle trace
      if act.curTime >= night_vision_device__nextObstacleTraceAt
        night_vision_device__nextObstacleTraceAt = act.curTime + obstacleTracesInterval
        let tracePos = transform[3]
        let traceDir = transform[2]

        var distToObstacle = maxObstacleTraceDistance
        var out = ShapeQueryOutput()
        if sphere_cast(tracePos, tracePos + traceDir * maxObstacleTraceDistance, obstacleTraceSphereRadius, out)
          distToObstacle = out.t * maxObstacleTraceDistance

        let flashlightDistanceFactor = distToObstacle / maxObstacleTraceDistance
        flashlightTargetBrightness = max(0.0, lerp(flashlightBrightnessRange.x,
                                          flashlightBrightnessRange.y,
                                          flashlightDistanceFactor))
      // Adjust brightness
      light__brightness = lerp(light__brightness, flashlightTargetBrightness, flashlightAdaptationFactor * act.dt)


def process_nvd_equipped(nvd_eid : EntityId;
                         watched_by_player : bool)
  query(nvd_eid) <| $ [es] (var slot_attach__ignoreParentVisibility : bool&)
    if watched_by_player
      slot_attach__ignoreParentVisibility = true
      set_night_vision_device_visibility(nvd_eid, false)


def process_nvd_unequipped(nvd_eid : EntityId;
                           watched_by_player : bool)

  query(nvd_eid) <| $ [es] (var slot_attach__ignoreParentVisibility : bool&)
    if watched_by_player
      slot_attach__ignoreParentVisibility = false
      set_night_vision_device_visibility(nvd_eid, true)

      query() <| $ [es(REQUIRE=screenNightVisionEffect)] (var screen_night_vision__enabled : bool&)
        screen_night_vision__enabled = false


[es(tag=gameClient, on_appear, REQUIRE=(night_vision_device, watchedPlayerItem))]
def nvd_equipment_mod_appear_client(evt : Event;
                                    eid aka nvd_eid : EntityId;
                                    slot_attach__attachedTo aka mod_slot_attach__attachedTo : EntityId)
  query(slot_attach__attachedTo) <| $ [es(REQUIRE=equipment_item)] (slot_attach__attachedTo aka equipment_slot_attach__attachedTo : EntityId)
    if equipment_slot_attach__attachedTo != INVALID_ENTITY_ID
      process_nvd_equipped(nvd_eid, true)


[es(tag=gameClient)]
def nvd_equipment_mod_equipped_client(evt : EventOnEquipmentModEquippedToHero;
                                      watchedByPlr : EntityId const?)
  query(evt.equipmentModEid) <| $ [es(REQUIRE=night_vision_device)] ()
    process_nvd_equipped(evt.equipmentModEid, watchedByPlr != null)


[es(tag=gameClient, REQUIRE=watchedByPlr)]
def nvd_equipment_mod_unequipped_client(evt : EventOnEquipmentModUnequippedFromHero;
                                        watchedByPlr : EntityId const?)
  query(evt.equipmentModEid) <| $ [es(REQUIRE=night_vision_device)] ()
    process_nvd_unequipped(evt.equipmentModEid, watchedByPlr != null)


[es(tag=gameClient, on_appear, REQUIRE=enable_night_vision_affect)]
def enable_night_vision_affect_appear(evt : Event;
                                      game_effect__attachedTo : EntityId;
                                      enable_night_vision_affect__preset : Object;
                                      enable_night_vision_affect__fixed_exposure : float)
  query(game_effect__attachedTo) <| $ [es(REQUIRE=watchedByPlr)] ()
    query() <| $ [es(REQUIRE=screenNightVisionEffect)] (var shader_vars__vars : Object;
                                                        var screen_night_vision__fixed_exposure : float&;
                                                        var screen_night_vision__enabled : bool&)
      screen_night_vision__enabled = true
      shader_vars__vars := enable_night_vision_affect__preset
      screen_night_vision__fixed_exposure = enable_night_vision_affect__fixed_exposure


[es(tag=gameClient, on_disappear, REQUIRE=enable_night_vision_affect)]
def enable_night_vision_affect_disappear(evt : Event;
                                         game_effect__attachedTo : EntityId)
  query(game_effect__attachedTo) <| $ [es(REQUIRE=watchedByPlr)] ()
    query() <| $ [es(REQUIRE=screenNightVisionEffect)] (var screen_night_vision__enabled : bool&)
      screen_night_vision__enabled = false


[es(tag=gameClient, on_appear, REQUIRE=watchedByPlr)]
def actor_appear_update_enable_night_vision_affect(evt : Event;
                                                   eid : EntityId)
  find_query() <| $ [es(REQUIRE=enable_night_vision_affect)] (game_effect__attachedTo : EntityId;
                                                              enable_night_vision_affect__preset : Object;
                                                              enable_night_vision_affect__fixed_exposure : float)
    if game_effect__attachedTo == eid
      query() <| $ [es(REQUIRE=screenNightVisionEffect)] (var shader_vars__vars : Object;
                                                          var screen_night_vision__fixed_exposure : float&;
                                                          var screen_night_vision__enabled : bool&)
        screen_night_vision__enabled = true
        shader_vars__vars := enable_night_vision_affect__preset
        screen_night_vision__fixed_exposure = enable_night_vision_affect__fixed_exposure

      return true
    return false


[es(tag=gameClient, REQUIRE=night_vision_device)]
def night_vision_device_on_drop_phys_client(evt : EventOnDropItemPhys)
  query(evt.actorEid) <| $ [es(REQUIRE=watchedByPlr)] ()
    query() <| $ [es(REQUIRE=screenNightVisionEffect)] (var screen_night_vision__enabled : bool&)
      screen_night_vision__enabled = false