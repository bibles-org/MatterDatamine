require ecs
require DngNet
require ecs.common
require DagorInput
require DagorSystem
require game.events.input_events
require game.events.events_active_matter
require active_matter.game.es.ability_common


[es(tag=input)]
def human_use_check_ammo(evt : EventDaInputActionTriggered;
                         eid : EntityId;
                         input__enabled : bool;
                         human_input__checkAmmo : int;
                         human_weap__currentGunEid : EntityId)
  if !input__enabled
    return

  var isReloadInProgress = false
  query(human_weap__currentGunEid) <| $ [es] (gun_anim__reloadProgress : float;
                                              gun_jamming__fixJammingEndAt = -1.0)
    isReloadInProgress = gun_anim__reloadProgress > 0.0 && gun_anim__reloadProgress < 1.0 || gun_jamming__fixJammingEndAt > 0.0
  if isReloadInProgress
    return

  let action = int(evt.action)

  if action == human_input__checkAmmo
    send_net_event(eid, RqCheckAmmo(value = true))


[es(tag=input)]
def human_cancel_check_ammo(evt : EventDaInputActionTerminated;
                            eid : EntityId;
                            input__enabled : bool;
                            human_input__checkAmmo : int)
  if !input__enabled
    return

  let action = int(evt.action)

  if action == human_input__checkAmmo
    send_net_event(eid, RqCheckAmmo(value = false))