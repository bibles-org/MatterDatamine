require ecs
require strings
require math.base
require game.es.onboarding_common
require game.events.events_active_matter
require game.es.player_base_common
require game.es.door_operations_common
require DagorMath


def update_player_base_door_state(door_eid : EntityId;
                                  door_name : string;
                                  is_onboarding : bool;
                                  immediate : bool = false)
  query(door_eid) <| $ [es] (sliding_rendinst : Tag const?;
                             var locked__isLocked : bool&;
                             var locked__statusTip : das_string;
                             var door_operations__reqState : int&;
                             var door_operations__state : int&)
    if is_onboarding
      locked__isLocked = true

      if immediate || sliding_rendinst != null
        set_sliding_door_state_immediate(door_eid, int(DoorState.CLOSED))

      if sliding_rendinst != null
        locked__statusTip := "status_tip_access_denied"
      else
        locked__statusTip := "status_tip_key_required"
    else
      if (door_name == "southern_inner_gateway" ||
          door_name == "northern_outer_gateway")
        locked__isLocked = true
        locked__statusTip := "status_tip_another_closed_portal"
      elif door_name == "gym_gateway"
        locked__isLocked = true
        locked__statusTip := "status_tip_gym_in_construction"
      elif (door_name == "stash" || door_name == "shooting_range_gateway" ||
            door_name == "monolith_gateway" ||
            door_name == "flasks")
        locked__isLocked = false

        if immediate
          set_sliding_door_state_immediate(door_eid, int(DoorState.OPENED))
        else
          door_operations__reqState = int(DoorState.OPENED)
          door_operations__state = int(DoorState.OPENED)
      elif door_name == "bedroom" || door_name == "bathroom"
        locked__isLocked = false


def update_player_base_light_state(light_eid : EntityId;
                                   is_onboarding : bool)
  query(light_eid) <| $ [es] (player_base_light__defaultBrightness : float;
                              player_base_light__onboardingBrightness : float;
                              var light__brightness : float&)
    if is_onboarding
      light__brightness = player_base_light__onboardingBrightness
    else
      light__brightness = player_base_light__defaultBrightness


def update_player_base_animchar_emission_state(animchar_eid : EntityId;
                                               is_onboarding : bool)
  query(animchar_eid) <| $ [es] (player_base_animchar_with_dynamic_emission__defaultBrightness : float;
                                 player_base_animchar_with_dynamic_emission__defaultColor : E3DCOLOR;
                                 player_base_animchar_with_dynamic_emission__onboardingBrightness : float;
                                 player_base_animchar_with_dynamic_emission__onboardingColor : E3DCOLOR;
                                 var animchar_with_dynamic_emission__brightness : float&;
                                 var animchar_with_dynamic_emission__color : E3DCOLOR&;
                                 var animchar_render__enabled : bool&)
    if is_onboarding
      animchar_with_dynamic_emission__brightness = player_base_animchar_with_dynamic_emission__onboardingBrightness
      animchar_with_dynamic_emission__color = player_base_animchar_with_dynamic_emission__onboardingColor
    else
      animchar_with_dynamic_emission__brightness = player_base_animchar_with_dynamic_emission__defaultBrightness
      animchar_with_dynamic_emission__color = player_base_animchar_with_dynamic_emission__defaultColor

    animchar_render__enabled = (animchar_with_dynamic_emission__brightness > 0.0)


[es(tag=gameClient)]
def player_base_door_controller_init(evt : EventDoorControllerInited;
                                     door_controller__doorEid : EntityId;
                                     door_controller__name : string)
  update_player_base_door_state(door_controller__doorEid, door_controller__name, is_onboarding(false), true)


[es(tag=gameClient, on_event=CmdRequestOnboardingReportContract)]
def player_base_onboarding_open_monolith_door(evt : Event)
  find_query() <| $ [es] (door_controller__doorEid : EntityId; door_controller__name : string)
    if door_controller__name == "monolith_gateway"
      update_player_base_door_state(door_controller__doorEid, door_controller__name, false, false)
      return true
    return false


[es(on_appear, track=player_base_state_manager__state)]
def player_base_state_manager_track_state(evt : Event;
                                          eid aka player_base_state_manager_eid : EntityId;
                                          player_base_state_manager__state : int;
                                          player_base_state_manager__onboardingToNormalStateEffect : string;
                                          var player_base_state_manager__stateEffectEid : EntityId&)
  destroyEntity(player_base_state_manager__stateEffectEid)
  player_base_state_manager__stateEffectEid = INVALID_ENTITY_ID

  find_query() <| $ [es(REQUIRE=player_base_zone)] (transform aka player_base_zone_transform : float3x4;
                                                    sphere_zone__radius : float)
    let radiusSq = square(sphere_zone__radius)
    if player_base_state_manager__state == int(PlayerBaseState.NORMAL)
      // Turn light on
      query() <| $ [es(REQUIRE=light__brightness)] (eid aka light_eid : EntityId;
                                                    transform aka light_transform : float3x4)
        let distSq = distance_sq(player_base_zone_transform[3], light_transform[3])
        if distSq <= radiusSq
          update_player_base_light_state(light_eid, false)

      // Unlock base consoles
      query() <| $ [es] (transform aka console_transform : float3x4;
                         var locked__isLocked : bool&;
                         var use_object__enabled : bool&)
        let distSq = distance_sq(player_base_zone_transform[3], console_transform[3])
        if distSq <= radiusSq
          use_object__enabled = true
          locked__isLocked = false

      // Turn animchar emission on
      query() <| $ [es] (eid aka animchar_eid : EntityId;
                         transform aka animchar_transform : float3x4)
        let distSq = distance_sq(player_base_zone_transform[3], animchar_transform[3])
        if distSq <= radiusSq
          update_player_base_animchar_emission_state(animchar_eid, false)

      // Update doors
      query() <| $ [es] (door_controller__doorEid : EntityId;
                         door_controller__name : string)
        update_player_base_door_state(door_controller__doorEid, door_controller__name,
                                      is_onboarding(false), evt.eventName == "EventEntityCreated")
    elif player_base_state_manager__state == int(PlayerBaseState.ONBOARDING)
      // Turn light off
      query() <| $ [es(REQUIRE=light__brightness)] (eid aka light_eid : EntityId;
                                                    transform aka light_transform : float3x4)
        let distSq = distance_sq(player_base_zone_transform[3], light_transform[3])
        if distSq <= radiusSq
          update_player_base_light_state(light_eid, true)

      // Lock consoles
      query() <| $ [es] (transform aka console_transform : float3x4;
                         open_console_menu_on_use__menuName : string;
                         var locked__isLocked : bool&;
                         var locked__statusTip : das_string;
                         var use_object__enabled : bool&)
        let distSq = distance_sq(player_base_zone_transform[3], console_transform[3])
        if distSq <= radiusSq
          use_object__enabled = true
          if open_console_menu_on_use__menuName != "Raid"
            locked__isLocked = true
            locked__statusTip := "status_tip_access_denied"

      // Turn animchar emission off
      query() <| $ [es] (eid aka animchar_eid : EntityId;
                         transform aka animchar_transform : float3x4)
        let distSq = distance_sq(player_base_zone_transform[3], animchar_transform[3])
        if distSq <= radiusSq
          update_player_base_animchar_emission_state(animchar_eid, true)

      // Update doors
      query() <| $ [es] (door_controller__doorEid : EntityId;
                         door_controller__name : string)
        update_player_base_door_state(door_controller__doorEid, door_controller__name, is_onboarding(false), true)

      // Keycard
      query() <| $ [es(REQUIRE=player_base_keycard)] (var animchar_render__enabled : bool&)
        animchar_render__enabled = false

    elif player_base_state_manager__state == int(PlayerBaseState.ONBOARDING_TO_NORMAL)
      player_base_state_manager__stateEffectEid = createEntity(player_base_state_manager__onboardingToNormalStateEffect) <| $(var init : ComponentsInitializer)
        init |> set("game_effect__attachedTo", player_base_state_manager_eid)

      // Disable consoles
      query() <| $ [es(REQUIRE=open_console_menu_on_use__menuName)] (transform aka console_transform : float3x4;
                                                                     var use_object__enabled : bool&)
        let distSq = distance_sq(player_base_zone_transform[3], console_transform[3])
        if distSq <= radiusSq
          use_object__enabled = false

      // Keycard
      query() <| $ [es(REQUIRE=player_base_keycard)] (var animchar_render__enabled : bool&)
        animchar_render__enabled = true

    return true


[es(on_appear, REQUIRE=open_console_menu_on_use__menuName)]
def player_base_update_base_state_on_console_appear(evt : Event)
  find_query() <| $ [es] (var player_base_state_manager__state : int&)
    player_base_state_manager__state = is_onboarding(false) ? int(PlayerBaseState.ONBOARDING) : int(PlayerBaseState.NORMAL)
    return true


[es(tag=gameClient, REQUIRE=onboarding_state_machine, on_event=EventStateMachineStateChanged, on_appear)]
def player_base_update_base_state_by_oboarding_state_machine(evt : Event)
  find_query() <| $ [es] (var player_base_state_manager__state : int&)
    player_base_state_manager__state = is_onboarding(false) ? int(PlayerBaseState.ONBOARDING) : int(PlayerBaseState.ONBOARDING_TO_NORMAL)
    return true


[es(tag=gameClient, on_appear)]
def player_base_light_appear(evt : Event;
                             light__brightness : float;
                             var player_base_light__defaultBrightness : float&)
  player_base_light__defaultBrightness = light__brightness



[es(tag=gameClient, on_appear, after=animchar_with_dynamic_emission_appear)]
def player_base_animchar_with_dynamic_emission_appear(evt : Event;
                                                      eid aka animchar_eid : EntityId;
                                                      animchar_with_dynamic_emission__color : E3DCOLOR;
                                                      var player_base_animchar_with_dynamic_emission__defaultColor : E3DCOLOR&)
  player_base_animchar_with_dynamic_emission__defaultColor = animchar_with_dynamic_emission__color
  update_player_base_animchar_emission_state(animchar_eid, is_onboarding(false))


[es(tag=gameClient, on_appear)]
def player_base_state_onboarding_to_normal_step_appear(evt : Event;
                                                       player_base_state_onboarding_to_normal_step__index : int)
  query() <| $ [es] (eid aka object_eid : EntityId;
                     player_base_onboarding_object__stepIndex : int;
                     light__brightness : float const?;
                     animchar_with_dynamic_emission__brightness : float const?)
    if player_base_state_onboarding_to_normal_step__index == player_base_onboarding_object__stepIndex
      if light__brightness != null
        update_player_base_light_state(object_eid, false)
      elif animchar_with_dynamic_emission__brightness != null
        update_player_base_animchar_emission_state(object_eid, false)


[es(tag=gameClient, on_appear, REQUIRE=player_base_state_onboarding_to_normal_finish)]
def player_base_state_onboarding_to_normal_finish_appear(evt : Event)
  find_query() <| $ [es] (var player_base_state_manager__state : int&)
    player_base_state_manager__state = int(PlayerBaseState.NORMAL)
    return true
