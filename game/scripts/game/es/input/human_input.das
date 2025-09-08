require app
require ecs
require ecs.safe
require net
require strings
require AnimV20
require math.base
require GeomNodeTree
require game.events.events
require game.events.input_events
require DagorInput
require DagorSystem
require DagorMath
require DagorMathUtils
require HumanPhys
require HumanPhys
require TouchInput
require DngHuman
require game.utils.net_utils
require game.events.events_active_matter
require game.es.human.human_use_object_common
require game.events.events_game


let MOVE_THRESHOLD = 0.1f


def init(var human_input__aim : int&;
         var human_input__aimDelta : int&;
         var human_input__look : int&;
         var human_input__move : int&;
         var human_input__leanLeft : int&;
         var human_input__leanRight : int&;
         var human_input__sprint : int&;
         var human_input__holdBreath : int&;
         var human_input__aim1 : int&;
         var human_input__aim2 : int&;
         var human_input__zoom : int&;
         var human_input__sightNext : int&;
         var human_input__sightPrev : int&;
         var human_input__use : int&;
         var human_input__useAlt : int&)
  human_input__aim = int(get_action_handle("Human.Aim", TYPEGRP_STICK))
  human_input__aimDelta = int(get_action_handle("Human.AimDelta", TYPEGRP_STICK))
  human_input__look = int(get_action_handle("Human.Look", TYPEGRP_STICK))
  human_input__move = int(get_action_handle("Human.Move", TYPEGRP_STICK))
  human_input__leanLeft = int(get_action_handle("Human.LeanLeft", TYPEGRP_DIGITAL))
  human_input__leanRight = int(get_action_handle("Human.LeanRight", TYPEGRP_DIGITAL))

  human_input__sprint = int(get_action_handle("Human.Sprint", TYPEGRP_DIGITAL))
  human_input__holdBreath = int(get_action_handle("Human.HoldBreath", TYPEGRP_DIGITAL))
  human_input__aim1 = int(get_action_handle("Human.Aim1", TYPEGRP_DIGITAL))
  human_input__aim2 = int(get_action_handle("Human.Aim2", TYPEGRP_DIGITAL))
  human_input__zoom = int(get_action_handle("Human.Zoom", TYPEGRP_DIGITAL))

  human_input__sightNext = int(get_action_handle("Human.SightNext", TYPEGRP_DIGITAL))
  human_input__sightPrev = int(get_action_handle("Human.SightPrev", TYPEGRP_DIGITAL))

  human_input__use = int(get_action_handle("Human.Use", TYPEGRP_DIGITAL))
  human_input__useAlt = int(get_action_handle("Human.UseAlt", TYPEGRP_DIGITAL))



def reset(var human_input__aim : int&;
          var human_input__aimDelta : int&;
          var human_input__look : int&;
          var human_input__move : int&;
          var human_input__leanLeft : int&;
          var human_input__leanRight : int&;
          var human_input__sprint : int&;
          var human_input__holdBreath : int&;
          var human_input__aim1 : int&;
          var human_input__aim2 : int&;
          var human_input__zoom : int&;
          var human_input__sightNext : int&;
          var human_input__sightPrev : int&;
          var human_input__use : int&;
          var human_input__useAlt : int&)
  human_input__aim = int(BAD_ACTION_HANDLE)
  human_input__aimDelta = int(BAD_ACTION_HANDLE)
  human_input__look = int(BAD_ACTION_HANDLE)
  human_input__move = int(BAD_ACTION_HANDLE)
  human_input__leanLeft = int(BAD_ACTION_HANDLE)
  human_input__leanRight = int(BAD_ACTION_HANDLE)
  human_input__sprint = int(BAD_ACTION_HANDLE)
  human_input__holdBreath = int(BAD_ACTION_HANDLE)
  human_input__aim1 = int(BAD_ACTION_HANDLE)
  human_input__aim2 = int(BAD_ACTION_HANDLE)
  human_input__zoom = int(BAD_ACTION_HANDLE)
  human_input__sightNext = int(BAD_ACTION_HANDLE)
  human_input__sightPrev = int(BAD_ACTION_HANDLE)
  human_input__use = int(BAD_ACTION_HANDLE)
  human_input__useAlt = int(BAD_ACTION_HANDLE)

[es(tag=input, REQUIRE=human_input)]
def human_input_is_singular_es(evt : EventCheckHumanInputIsSingular; eid : EntityId)
  let thisEid = eid
  ecs::query() <| $ [es(REQUIRE=human_input)] (eid : EntityId)
    if eid != thisEid
      logerr("Created > 1 human_input component {int(uint(thisEid))} and {int(uint(eid))}")

[es(tag=input, on_appear, REQUIRE=human_input)]
def human_input_appear_es(evt : Event;
                          eid : EntityId;
                          transform : float3x4 const?;
                          var human_input__aimAngle : float2&;
                          var human_input__aim : int&;
                          var human_input__aimDelta : int&;
                          var human_input__look : int&;
                          var human_input__move : int&;
                          var human_input__leanLeft : int&;
                          var human_input__leanRight : int&;
                          var human_input__sprint : int&;
                          var human_input__holdBreath : int&;
                          var human_input__aim1 : int&;
                          var human_input__aim2 : int&;
                          var human_input__zoom : int&;
                          var human_input__sightNext : int&;
                          var human_input__sightPrev : int&;
                          var human_input__use : int&;
                          var human_input__useAlt : int&)
  // While entity is just [re]created, there still can be other entities yet in the recreation process still with human_input
  sendEvent(eid, EventCheckHumanInputIsSingular())

  human_input__aimAngle = dir_to_angles((transform ?? IDENT_TM)[0])

  init(human_input__aim, human_input__aimDelta, human_input__look, human_input__move,
       human_input__leanLeft, human_input__leanRight, human_input__sprint, human_input__holdBreath, human_input__aim1,
       human_input__aim2, human_input__zoom, human_input__sightNext, human_input__sightPrev,
       human_input__use, human_input__useAlt)


[es(tag=input, on_disappear, REQUIRE=human_input)]
def human_input_destroyed_es(evt : Event;
                             var human_input__aim : int&;
                             var human_input__aimDelta : int&;
                             var human_input__look : int&;
                             var human_input__move : int&;
                             var human_input__leanLeft : int&;
                             var human_input__leanRight : int&;
                             var human_input__sprint : int&;
                             var human_input__holdBreath : int&;
                             var human_input__aim1 : int&;
                             var human_input__aim2 : int&;
                             var human_input__zoom : int&;
                             var human_input__sightNext : int&;
                             var human_input__sightPrev : int&;
                             var human_input__use : int&;
                             var human_input__useAlt : int&)
  reset(human_input__aim, human_input__aimDelta, human_input__look, human_input__move,
        human_input__leanLeft, human_input__leanRight, human_input__sprint, human_input__holdBreath, human_input__aim1,
        human_input__aim2, human_input__zoom, human_input__sightNext, human_input__sightPrev,
        human_input__use, human_input__useAlt)


[es(tag=input, REQUIRE=human_input)]
def human_input_init_es(evt : EventDaInputInit;
                        input__enabled : bool;
                        var human_input__aim : int&;
                        var human_input__aimDelta : int&;
                        var human_input__look : int&;
                        var human_input__move : int&;
                        var human_input__leanLeft : int&;
                        var human_input__leanRight : int&;
                        var human_input__sprint : int&;
                        var human_input__holdBreath : int&;
                        var human_input__aim1 : int&;
                        var human_input__aim2 : int&;
                        var human_input__zoom : int&;
                        var human_input__sightNext : int&;
                        var human_input__sightPrev : int&;
                        var human_input__use : int&;
                        var human_input__useAlt : int&)
  if !input__enabled
    return
  if evt.init
    init(human_input__aim, human_input__aimDelta, human_input__look, human_input__move,
         human_input__leanLeft, human_input__leanRight, human_input__sprint, human_input__holdBreath, human_input__aim1,
         human_input__aim2, human_input__zoom, human_input__sightNext, human_input__sightPrev,
         human_input__use, human_input__useAlt)
  else
    reset(human_input__aim, human_input__aimDelta, human_input__look, human_input__move,
          human_input__leanLeft, human_input__leanRight, human_input__sprint, human_input__holdBreath, human_input__aim1,
          human_input__aim2, human_input__zoom, human_input__sightNext, human_input__sightPrev,
          human_input__use, human_input__useAlt)

[es(tag=input, after=human_input_es)]
def human_input_aim_in_crawling_es(info : UpdateStageUpdateInput;
                                   human_input__move : int;
                                   human_input__standState : int;
                                   human_input__aim2 : int;
                                   var human_net_phys : HumanActor&;
                                   var human_input__wishMove : bool&;
                                   var human_input__wishAim : bool&;
                                   var human_input__crawlingReject : bool&)
  if human_input__standState != int(HumanPhysControlType.HCT_CRAWL)
    human_input__wishAim = false
    human_input__wishMove = false
    human_input__crawlingReject = false
    return

  let isAim = is_action_active(uint16(human_input__aim2)) ? get_digital_action_state(uint16(human_input__aim2)).bState : false
  let moveState = get_analog_stick_action_state(uint16(human_input__move))
  let isMove = moveState.x > MOVE_THRESHOLD || moveState.x < -MOVE_THRESHOLD || moveState.y > MOVE_THRESHOLD || moveState.y < -MOVE_THRESHOLD

  if isMove && isAim && (human_input__wishMove || human_input__wishAim)
    if human_input__wishAim
      human_input__crawlingReject = true
    elif human_input__wishMove
      human_input__crawlingReject = false
    human_input__wishMove = false
    human_input__wishAim = false

  elif !isMove
    human_input__wishMove = true

  elif !isAim
    human_input__wishAim = true
    human_input__crawlingReject = false

  if isMove && !human_input__crawlingReject && isAim
    human_net_phys.phys.producedCT |> human_control_state_set_control_bit((HumanPhysControlType.HCT_ZOOM_VIEW), false)


[es(tag=input, after=human_input_es, REQUIRE=(block_aim_in_air, human_input))]
def human_input_block_aim_in_air(info : UpdateStageUpdateInput;
                                 human_net_phys__isInAir : bool;
                                 isInVehicle : bool;
                                 var human_net_phys : HumanActor&)
  let isInMotion = length(human_net_phys.phys.currentState.velocity) >= 1e-6f
  if human_net_phys__isInAir && !isInVehicle && isInMotion
    human_net_phys.phys.producedCT |> human_control_state_set_control_bit(HumanPhysControlType.HCT_ZOOM_VIEW, false)
    human_net_phys.phys.producedCT |> human_control_state_set_control_bit(HumanPhysControlType.HCT_AIM, false)


[es(tag=input, after=human_input_es)]
def human_input_disable_toggle_aim_es(info : UpdateStageUpdateInput;
                                      human_input__aim1 : int;
                                      human_input__zoom : int;
                                      human_weap__currentGunEid : EntityId;
                                      var human_net_phys : HumanActor)
  if get_bool(human_weap__currentGunEid, "gun__disableToggleAim") ?? false
    let isAim1 = is_action_active(uint16(human_input__aim1)) ? get_digital_action_state(uint16(human_input__aim1)).bState : false
    let isZoom = is_action_active(uint16(human_input__zoom)) ? get_digital_action_state(uint16(human_input__zoom)).bState : false
    human_net_phys.phys.producedCT |> human_control_state_set_control_bit((HumanPhysControlType.HCT_ZOOM_VIEW), isAim1 || isZoom)


def find_gunmod_with_toggle_aim_block(current_gun_mod_eids : EidList)
  for modEid in current_gun_mod_eids
    if get_bool(modEid, "gunmod__disableToggleAim") ?? false
      return true
  return false


[es(tag=input, after=human_input_es)]
def human_input_sneak(evt : EventDaInputActionTriggered;
                      human_input__sneak : int;
                      input__enabled : bool;
                      var human__sneaking : bool&)
  if !input__enabled
    return
  let action = int(evt.action)
  if action == human_input__sneak
    human__sneaking = !human__sneaking


[es(tag=input, track=human_weap__currentGunModEids)]
def disable_toggle_aim_by_gun_mod_es(evt : Event; human_weap__currentGunEid : EntityId; human_weap__currentGunModEids : EidList)
  var disableToggleAim = getRW_bool(human_weap__currentGunEid, "gun__disableToggleAim")
  if disableToggleAim != null
    *disableToggleAim = find_gunmod_with_toggle_aim_block(human_weap__currentGunModEids)


[es(tag=input, on_appear)]
def scope_create_es(evt : Event; gunmod__disableToggleAim : bool; slot_attach__attachedTo : EntityId)
  var disableToggleAim = getRW_bool(slot_attach__attachedTo, "gun__disableToggleAim")
  if disableToggleAim != null
    *disableToggleAim = *disableToggleAim || gunmod__disableToggleAim

[es(tag=input, on_event=EventHeroChanged, REQUIRE=human_net_phys)]
def human_input_hero_changed_es(evt : Event; human_input__aim1 : int; var human_input__hasValidState : bool&)
  human_input__hasValidState = false
  reset_digital_action_sticky_toggle(uint16(human_input__aim1))


[es(tag=input, track=interaction_menu_available)]
def track_interaction_menu_available(evt : Event;
                                     interaction_menu_available : bool)
  if !interaction_menu_available
    broadcastEvent(CmdHideUiMenu(menuName = "Interaction"))


[es(tag=input, REQUIRE_NOT=deadEntity)]
def human_use_object_input(evt : EventDaInputActionTriggered;
                           input__enabled : bool;
                           human_input__use : int;
                           eid : EntityId;
                           isDowned : bool = false;
                           isInVehicle : bool = false;
                           human_use_object__canUseSelected : bool;
                           human_use_object__selectedObject : EntityId)
  if int(evt.action) != human_input__use || !input__enabled || (isDowned && !isInVehicle)
    return
  if !doesEntityExist(human_use_object__selectedObject)
    return

  handle_use_object(eid, human_use_object__selectedObject, human_use_object__canUseSelected)


[es(tag=input, REQUIRE_NOT=deadEntity)]
def human_use_alt_object_input(evt : EventDaInputActionTriggered;
                               input__enabled : bool;
                               human_use_object__canUseSelected : bool;
                               human_input__useAlt : int;
                               eid : EntityId;
                               isDowned : bool = false;
                               isInVehicle : bool = false;
                               human_use_object__selectedObject : EntityId)
  if int(evt.action) != human_input__useAlt || !input__enabled || isDowned || isInVehicle
    return
  if !empty(get_string(human_use_object__selectedObject, "item__setCustomUseAltPrompt", ""))
    human_use_alt_object(eid, human_use_object__selectedObject)
  else
    handle_use_object(eid, human_use_object__selectedObject, human_use_object__canUseSelected)


[es(tag=input)]
def use_weapon_flashlight_input_handler(evt : EventDaInputActionTriggered;
                                        eid : EntityId;
                                        human_input__flashlight : int&)
  if int(evt.action) == human_input__flashlight
    send_net_event(eid, CmdUseFlashlight())