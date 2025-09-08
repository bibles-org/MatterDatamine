require ecs
require ecs.safe
require game.events.events_game
require game.events.sound_events
require active_matter.game.es.check_ammo_common


[es(tag=sound, on_appear, before=anim_init_irq_listener_es)]
def gun_ammo_inspection_sound_in_irqs_appear(evt : Event;
                                             gun_ammo_inspection_sound__inIrqs : Object;
                                             var anim_irq__eventNames : Object)
  for inIrqData in gun_ammo_inspection_sound__inIrqs
    using <| $(var irq : Object)
      irq |> set("irqName", inIrqData.key)
      irq |> set("irqId", -1)
      anim_irq__eventNames |> set(inIrqData.key, irq)


[es(tag=sound)]
def human_hero_check_ammo_controller_anim_irq(evt : EventAnimIrq;
                                              eid : EntityId;
                                              anim_irq__eventNames : Object;
                                              gun_ammo_inspection_sound__inIrqs : Object;
                                              gun__owner : EntityId)
  query(gun__owner) <| $ [es] (check_ammo_controller__state : int)
    for event in anim_irq__eventNames
      let eventObj = get_ecs_object(event.value)
      if eventObj != null
        for inIrqData in gun_ammo_inspection_sound__inIrqs
          if inIrqData.key == event.key
            let inIrqObj = inIrqData.value as Object
            if evt.irqType == ((*eventObj).irqId ?? -1)
              var irq = ""
              if check_ammo_controller__state == int(CheckAmmoState.IN)
                irq = inIrqObj?.frw ?? ""
              elif check_ammo_controller__state == int(CheckAmmoState.IN_REVERSE)
                irq = inIrqObj?.inv ?? ""

              if irq != ""
                sendEventImmediate(eid, CmdSoundGenIrqSim(irq = irq))
            break