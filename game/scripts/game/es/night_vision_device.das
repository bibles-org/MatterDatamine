require ecs
require ecs.safe
require ecs.common
require math.base
require AnimV20
require DagorConsole
require DagorSystem
require PhysVars
require game.es.action_common
require game.events.events_game
require game.es.flashlights.flashlight_common
require game.events.inventory_events
require game.es.inventory_equipment_common
require game.events.events
require game.events.events_active_matter
require DngActor
require DngHuman
require Dacoll
require DngNet
require GeomNodeTree


[es(on_appear, REQUIRE=night_vision_device__isOn)]
def night_vision_device_appear(evt : Event;
                               var animchar : AnimcharBaseComponent)
  var animGraph = animchar.animGraph
  if animGraph != null
    let stateIdx = *animGraph |> anim_graph_getStateIdx("nvd_up")
    *animGraph |> anim_graph_enqueueState(*animchar.animState, stateIdx)


[es(tag=server, on_event=CmdUseNightVisionDevice)]
def night_vision_device_use(evt : Event;
                            eid : EntityId;
                            attaches_list : EidList;
                            human_inventory__entityToUse : EntityId;
                            var human_anim__headAimOffsets : float2&)
  for attach in attaches_list
    query(attach) <| $ [es] (equipment_mods__curModInSlots : Object)
      for modInSlotData in equipment_mods__curModInSlots
        let modEid = modInSlotData.value ?? INVALID_ENTITY_ID
        query(modEid) <| $ [es] (var night_vision_device__isOn : bool&;
                                 var animchar : AnimcharBaseComponent)
          assume animGraph = animchar.animGraph
          if animGraph == null
            return
          createEntity(night_vision_device__isOn ? "nvd_up_animation" : "nvd_down_animation") <| $(var init)
            init |> set("game_effect__attachedTo", eid)
            init |> set("nvd_animation__nvdDevice", modEid)
          night_vision_device__isOn = !night_vision_device__isOn
          human_anim__headAimOffsets = night_vision_device__isOn ? float2(0.35, -0.3) : float2(0.0)

          if night_vision_device__isOn
            query(human_inventory__entityToUse) <| $ [es(REQUIRE=item__incompatibleWithNightVisionDevice)] ()
              sendEventImmediate(eid, EventInterruptItemUse())


[es(on_disappear, track=slot_attach__attachedTo, REQUIRE=(night_vision_device, slot_attach__attachedTo))]
def night_vision_device_detached(evt : Event;
                                 slot_attach__attachedTo : EntityId;
                                 var night_vision_device__isOn : bool&)
  if slot_attach__attachedTo == INVALID_ENTITY_ID
    night_vision_device__isOn = false


[es(tag=server, REQUIRE=watchedByPlr)]
def nvd_equipment_mod_unequipped_server(evt : EventOnEquipmentModUnequippedFromHero)
  query(evt.equipmentModEid) <| $ [es] (var night_vision_device__isOn : bool&)
    night_vision_device__isOn = false


[es(tag=server, REQUIRE=night_vision_device)]
def night_vision_device_on_drop_phys_server(evt : EventOnDropItemPhys;
                                            var night_vision_device__isOn : bool&)
  night_vision_device__isOn = false