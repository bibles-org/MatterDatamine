require ecs
require ecs.safe
require ecs.common
require net
require strings
require game.es.ecs_common
require game.events.events_active_matter
require DagorMath
require DagorMathUtils
require math.base
require game.es.state_machine_common
require game.es.onboarding_common
require game.es.item_equip_common
require game.events.player_events
require game.utils.sound_utils
require game.es.nexus_loadout_common
require DagorInput
require DngHuman
require DngActor
require DagorSystem
require active_matter.game.es.objectives.objective_common
require DagorDataBlock


def count_completed_onboarding_stages(player_profile__unlocks : StringList)
  var onboardingStagesCompleted = 0
  assume onboardingUnlocksPrefix = "onboarding_"
  for unlock in player_profile__unlocks
    if starts_with(string(unlock), onboardingUnlocksPrefix)
      onboardingStagesCompleted += 1
  return onboardingStagesCompleted


[es(REQUIRE=hero, on_appear)]
def trigger_onboarding_on_hero_appear(evt : Event)
  var isOnboardingDisabled = false
  dgs_get_settings() |> datablock_get_block("debug") <| $(blk)
    isOnboardingDisabled = datablock_getBool(blk, "skip_onboarding", false)
  if isOnboardingDisabled
    return

  find_query() <| $ [es] (player_profile__isLoaded : bool; player_profile__unlocks : StringList)
    if !player_profile__isLoaded
      error("Hero created, but profile is not loaded")
      return true
    let needOnboarding = !has_value(player_profile__unlocks, "onboarding_finished")
    if needOnboarding
      createEntity("onboarding_state_machine")
    return true


[es(on_appear, before=init_state_machine_transition, REQUIRE=onboarding_load_from_profile_server)]
def load_onboarding_state_from_profile_server(evt : Event;
                                              onboarding_load_from_profile_server__stageList : StringList;
                                              var state_machine_transition__requiredNextStateComps : StringList)
  find_query() <| $ [es] (player_profile__unlocks : StringList)
    if (has_value(player_profile__unlocks, "unlock_monolith_gate")
      && !has_value(player_profile__unlocks, "unlock_monolith_path_choosed"))
      push(state_machine_transition__requiredNextStateComps, "onboarding_phase_monolith_selection")
      return true
    let onboardingStagesCompleted = count_completed_onboarding_stages(player_profile__unlocks)
    if onboardingStagesCompleted >= length(onboarding_load_from_profile_server__stageList)
      print("All onboarding stages already completed. Starting anyway")
      return false

    assume chosenStageName = onboarding_load_from_profile_server__stageList[onboardingStagesCompleted]
    push(state_machine_transition__requiredNextStateComps, chosenStageName)
    return true


[es(tag=gameClient, REQUIRE=hero)]
def request_onboarding_raid(evt : CmdRequestOnboardingRaid;
                            eid aka hero_eid : EntityId)
  broadcastEvent(CmdHideUiMenu(menuName = "OnboardingRaid"))

  createEntity("onboarding_extraction_sequence_affect") <| $(init)
    set(init, "game_effect__attachedTo", hero_eid)


[es(tag=gameClient, REQUIRE=onboarding_extraction_sequence_final_stage, on_appear)]
def onboarding_extraction_sequence_final_stage(evt : Event;
                                               game_effect__attachedTo : EntityId)
  removeSubTemplate(game_effect__attachedTo, "militant_extraction_sequence_scale_animation")

  find_query() <| $ [es(REQUIRE=onboarding_state_machine)] (state_machine__currentState : EntityId)
    if has(state_machine__currentState, "onboarding_phase_monolith")
      query() <| $ [es(REQUIRE=onboarding_portal_activated)] (state_machine_transition_trigger__parentTransition : EntityId)
        trigger_state_machine_transition(state_machine_transition_trigger__parentTransition)
    elif has(state_machine__currentState, "onboarding_phase_monolith_selection")
      if (find_query() <| $ [es(REQUIRE=onboarding_fame_door_trigger)] () => true)
        query() <| $ [es(REQUIRE=onboarding_fame_door_selected)] (state_machine_transition_trigger__parentTransition : EntityId)
          trigger_state_machine_transition(state_machine_transition_trigger__parentTransition)
      else
        query() <| $ [es(REQUIRE=onboarding_portal_activated)] (state_machine_transition_trigger__parentTransition : EntityId)
          trigger_state_machine_transition(state_machine_transition_trigger__parentTransition)
    elif has(state_machine__currentState, "onboarding_phase_base_first_time")
      query() <| $ [es(REQUIRE=onboarding_miniraid_activated)] (state_machine_transition_trigger__parentTransition : EntityId)
        trigger_state_machine_transition(state_machine_transition_trigger__parentTransition)
    return true


[es(tag=gameClient, REQUIRE=onboarding_extraction_sequence_final_stage, on_disappear)]
def onboarding_extraction_sequence_final_stage_disappear(evt : Event;
                                                         game_effect__attachedTo : EntityId)
  createEntity("spawn_sequence_affect") <| $(init)
    set(init, "game_effect__attachedTo", game_effect__attachedTo)


[es(tag=gameClient, on_event=(CmdRequestOnboardingReportContract, CmdRequestOnboardingBuyMonolithAccess))]
def request_onboarding_report_contract(evt : Event)
  broadcastEvent(CmdHideAllUiMenus())

  find_query() <| $ [es(REQUIRE=(watchedPlayerItem, key_miniraid_item))] (eid : EntityId)
    destroyEntity(eid)
    return true


[es(REQUIRE=trigger_transition_on_game_trigger, after=game_trigger_processor_open_player_note)]
def trigger_transition_from_game_trigger(evt : EventGameTrigger;
                                         game_trigger_processor__onTriggerHash : int;
                                         state_machine_transition_trigger__parentTransition : EntityId)
  if evt.triggerHash == game_trigger_processor__onTriggerHash
    trigger_state_machine_transition(state_machine_transition_trigger__parentTransition)


[es(tag=gameClient, on_event=CmdRequestOnboardingReportContract)]
def onboarding_contract_game_trigger(evt : Event; eid aka trigger_eid : EntityId; onboarding_contract_trigger__emitTrigger : string)
  find_query() <| $ [es(REQUIRE=hero)] (eid aka hero_eid : EntityId)
    broadcast_net_event(EventGameTrigger(source = trigger_eid, target = hero_eid, triggerHash = int(ecs_hash(onboarding_contract_trigger__emitTrigger))))
    return true


[es(tag=gameClient, on_event=CmdRequestOnboardingBuyMonolithAccess)]
def onboarding_monolith_access_game_trigger(evt : Event; eid aka trigger_eid : EntityId; onboarding_monolith_access_trigger__emitTrigger : string)
  find_query() <| $ [es(REQUIRE=hero)] (eid aka hero_eid : EntityId)
    broadcast_net_event(EventGameTrigger(source = trigger_eid, target = hero_eid, triggerHash = int(ecs_hash(onboarding_monolith_access_trigger__emitTrigger))))
    return true


[es(on_disappear)]
def phase_temporary_entities_cleanup(evt : Event; phase_temporary_entities__list : EidList)
  for eid in phase_temporary_entities__list
    destroyEntity(eid)


[es(REQUIRE=onboarding_portal, track=nexus_portal__state)]
def onboarding_trigger_on_portal_activation(evt : Event; nexus_portal__state : int)
  if nexus_portal__state == 0
    return

  query() <| $ [es(REQUIRE=hero)] (eid aka hero_eid : EntityId)
    createEntity("onboarding_extraction_sequence_affect") <| $(var init : ComponentsInitializer)
      init |> set("game_effect__attachedTo", hero_eid)
      init |> set("extraction_sequence_affect__testMode", true)


[es(REQUIRE=onboarding_monolith_portal, on_appear)]
def on_monolith_portal_appear(evt : Event; eid : EntityId)
  let foundTemporaryEntities = find_query() <| $ [es] (var phase_temporary_entities__list : EidList)
    push(phase_temporary_entities__list, eid)
    return true

  // current phase is probably already over. This will happen
  // when phase is changed via console command
  if !foundTemporaryEntities
    destroyEntity(eid)


[es(REQUIRE=onboarding_monolith_portal, on_disappear)]
def on_monolith_portal_disappear(evt : Event)
  query() <| $ [es] (turn_off_light_on_monolith_portal_appear__previousBrightness : float;
                     var light__brightness : float&)
    light__brightness = turn_off_light_on_monolith_portal_appear__previousBrightness


[es(no_order)]
def onboarding_monolith_portal_additional_effects(update : ParallelUpdateFrameDelayed;
                                                  nexus_portal__activationProgressDisplayed : float;
                                                  nexus_portal__totalActivationTime : float;
                                                  onboarding_monolith_portal__additionalEffects : Array;
                                                  var onboarding_monolith_portal__additionalEffectEntities : EidList;
                                                  var onboarding_monolith_portal__previousProgress : float&)
  let progressRatio = nexus_portal__activationProgressDisplayed / nexus_portal__totalActivationTime
  if progressRatio < onboarding_monolith_portal__previousProgress
    onboarding_monolith_portal__previousProgress = 0.0
    for eid in onboarding_monolith_portal__additionalEffectEntities
      destroyEntity(eid)
    clear(onboarding_monolith_portal__additionalEffectEntities)
    return

  for effect in onboarding_monolith_portal__additionalEffects
    let effectObj = effect as Object
    if effectObj == null
      continue
    let startsAt = effectObj?.startsAt ?? 0.0
    if progressRatio > startsAt && onboarding_monolith_portal__previousProgress <= startsAt
      let effectTemplate = effectObj?.templateName ?? ""
      let effectEid = createEntity(effectTemplate)
      push(onboarding_monolith_portal__additionalEffectEntities, effectEid)
  onboarding_monolith_portal__previousProgress = progressRatio


[es(on_disappear)]
def onboarding_monolith_portal_clear_additional_effects(evt : Event; onboarding_monolith_portal__additionalEffectEntities : EidList)
  for eid in onboarding_monolith_portal__additionalEffectEntities
    destroyEntity(eid)


[es(on_appear)]
def init_onboarding_monolith_portal(evt : Event;
                                    onboarding_monolith_portal_circling_energy__numLights : int;
                                    onboarding_monolith_portal_circling_energy__lightsTemplate : string;
                                    var onboarding_monolith_portal_circling_energy__portal : EntityId&;
                                    var onboarding_monolith_portal_circling_energy__lights : EidList)
  find_query() <| $ [es(REQUIRE=onboarding_portal)] (eid : EntityId; transform : float3x4)
    onboarding_monolith_portal_circling_energy__portal = eid
    for _ in range(onboarding_monolith_portal_circling_energy__numLights)
      let effect = createEntity(onboarding_monolith_portal_circling_energy__lightsTemplate) <| $(init)
        set(init, "transform", transform)
      push(onboarding_monolith_portal_circling_energy__lights, effect)
    return true


[es(no_order, tag=gameClient)]
def render_onoboarding_portal_lights(update : ParallelUpdateFrameDelayed;
                                     onboarding_monolith_portal_circling_energy__portal : EntityId;
                                     onboarding_monolith_portal_circling_energy__lightsRadiusMinMax : float2;
                                     onboarding_monolith_portal_circling_energy__lightsSpeed : float;
                                     onboarding_monolith_portal_circling_energy__lights : EidList)
  let numLights = length(onboarding_monolith_portal_circling_energy__lights)
  query(onboarding_monolith_portal_circling_energy__portal) <| $ [es] (transform aka portal_transform : float3x4;
                                                                       nexus_portal__activationProgressDisplayed : float;
                                                                       nexus_portal__totalActivationTime : float)
    let portalProgress = nexus_portal__activationProgressDisplayed / nexus_portal__totalActivationTime

    assume minMaxRadius = onboarding_monolith_portal_circling_energy__lightsRadiusMinMax
    let radius = minMaxRadius.x + portalProgress * (minMaxRadius.y - minMaxRadius.x)

    let right = float3(0.0, 0.0, 1.0)
    let up = float3(0.0, 1.0, 0.0)
    for eid, index in onboarding_monolith_portal_circling_energy__lights, iter_range(onboarding_monolith_portal_circling_energy__lights)
      query(eid) <| $ [es] (var transform : float3x4&)
        let orbitAngle = 2.0 * PI * (float(index * index) / float(numLights))
        var rotTm : float3x4
        make_tm(right, orbitAngle, rotTm)
        let orbitNormal = rotTm * up

        let horizontalAngle = 2.0 * PI * (float(index) / float(numLights)) + update.curTime * onboarding_monolith_portal_circling_energy__lightsSpeed
        var angleS : float
        var angleC : float
        sincos(horizontalAngle, angleS, angleC)
        let x = angleC * radius
        let y = angleS * radius
        transform[3] = portal_transform[3] + x * right + y * cross(right, orbitNormal)


[es(on_disappear)]
def clear_portal_floating_lights(evt : Event; onboarding_monolith_portal_circling_energy__lights : EidList)
  for eid in onboarding_monolith_portal_circling_energy__lights
    destroyEntity(eid)


[es(on_appear, REQUIRE=disable_player_profile)]
def onboarding_disable_profile_server(evt : Event)
  find_query() <| $ [es(REQUIRE=player_profile__isLoaded)] (eid : EntityId)
    destroyEntity(eid)
    return true


[es(on_appear, REQUIRE=enable_player_profile)]
def onboarding_enable_profile_server(evt : Event)
  let profileExists = find_query() <| $ [es(REQUIRE=player_profile__isLoaded)] ()
    return true
  if !profileExists
    createEntity("player_profile")


[es(REQUIRE=hero, on_event=EventEntityDied)]
def on_died_during_onboarding(evt : Event;
                              eid : EntityId;
                              onboarding_death_processor__template : string)
  createEntity(onboarding_death_processor__template) <| $(var init)
    init |> set("onboarding_respawn_on_disappear__oldHeroEid", eid)


[es(REQUIRE=miniraid_death_effect, on_event=EventOnboardingRaidExit)]
def onboarding_miniraid_afterdeath_do_respawn(evt : Event; eid : EntityId)
  destroyEntity(eid)


[es(on_disappear)]
def onboarding_afterdeath_do_respawn(evt : Event; onboarding_respawn_on_disappear__oldHeroEid : EntityId)
  // 1. Clean old body
  hero_clean_all_equipment_and_gun_slots(onboarding_respawn_on_disappear__oldHeroEid)
  destroyEntity(onboarding_respawn_on_disappear__oldHeroEid)

  // 2. Create new body
  find_query() <| $ [es] (eid : EntityId; is_local : bool)
    if !is_local
      return false
    send_net_event(eid, PlayerRequestSpawnInWorld())
    return true


[es(on_appear, tag=input)]
def onboarding_init_custom_action(evt : Event;
                                  onboarding_custom_action__name : string;
                                  var onboarding_custom_action__handle : uint16&)
  onboarding_custom_action__handle = get_action_handle(onboarding_custom_action__name, TYPEGRP_DIGITAL)


[es(no_order, tag=input)]
def onboarding_process_custom_action(update : UpdateStageInfoAct;
                                     eid : EntityId;
                                     onboarding_custom_action__handle : uint16)
  assume customAction = onboarding_custom_action__handle
  if is_action_active(customAction) && get_digital_action_state(customAction).bState
    broadcast_net_event(EventGameTrigger(source = eid, triggerHash = int(ecs_hash("onboarding_custom_action"))))


[es(on_appear, tag=input)]
def onboarding_look_around_input_init(evt : Event;
                                      game_effect__attachedTo : EntityId;
                                      var onboarding_look_around__initialVertDir : float3&;
                                      var onboarding_look_around__initialForwardDir : float3&;
                                      var onboarding_look_around__lookAroundAction : uint16&;
                                      var onboarding_look_around__angles : float2&)
  onboarding_look_around__lookAroundAction = get_action_handle("Human.Aim", TYPEGRP_STICK)
  query(game_effect__attachedTo) <| $ [es] (human_net_phys : HumanActor;
                                            transform : float3x4)
    onboarding_look_around__initialVertDir = transform[1]
    onboarding_look_around__initialForwardDir = transform[0]
    onboarding_look_around__angles = basis_aware_dir_to_angles(human_net_phys.phys.appliedCT.wishLookDir, onboarding_look_around__initialVertDir, onboarding_look_around__initialForwardDir)


[es(no_order, tag=input)]
def onboarding_look_around_input(update : UpdateStageInfoAct;
                                 game_effect__attachedTo : EntityId;
                                 onboarding_look_around__lookAroundAction : uint16;
                                 onboarding_look_around__horizontalAngleDegreeLimits : float2;
                                 onboarding_look_around__verticalAngleDegreeLimits : float2;
                                 onboarding_look_around__smoothStart : bool;
                                 onboarding_look_around__smoothStartThreshold : float;
                                 onboarding_look_around__smoothStartViscosity : float;
                                 onboarding_look_around__initialVertDir : float3;
                                 onboarding_look_around__initialForwardDir : float3;
                                 var onboarding_look_around__angles : float2&)
  query(game_effect__attachedTo) <| $ [es] (var human_net_phys : HumanActor&)
    let minMaxHorAngle = float2(
      deg_to_rad(onboarding_look_around__horizontalAngleDegreeLimits.x),
      deg_to_rad(onboarding_look_around__horizontalAngleDegreeLimits.y)
    )

    let minMaxVertAngle = float2(
      deg_to_rad(onboarding_look_around__verticalAngleDegreeLimits.x),
      deg_to_rad(onboarding_look_around__verticalAngleDegreeLimits.y)
    )

    assume inputLook = onboarding_look_around__lookAroundAction
    let asLook = get_analog_stick_action_state(inputLook)
    if asLook.bActive
      let clampedAngles = float2(
        clamp(onboarding_look_around__angles.x, minMaxHorAngle.x, minMaxHorAngle.y),
        clamp(onboarding_look_around__angles.y, minMaxVertAngle.x, minMaxVertAngle.y)
      )

      if onboarding_look_around__smoothStart && distance(clampedAngles, onboarding_look_around__angles) > onboarding_look_around__smoothStartThreshold
        onboarding_look_around__angles = approach(onboarding_look_around__angles, clampedAngles, update.dt, onboarding_look_around__smoothStartViscosity)
      else
        onboarding_look_around__angles = float2(
          clamp(onboarding_look_around__angles.x + asLook.x, minMaxHorAngle.x, minMaxHorAngle.y),
          clamp(onboarding_look_around__angles.y + asLook.y, minMaxVertAngle.x, minMaxVertAngle.y)
        )

      let wishLookDir = basis_aware_angles_to_dir(onboarding_look_around__angles, onboarding_look_around__initialVertDir, onboarding_look_around__initialForwardDir)
      human_net_phys.phys.producedCT |> human_control_state_set_wish_look_dir(wishLookDir)


[es(on_appear, REQUIRE=onboarding_show_action_hint)]
def onboarding_show_action_hint_init(evt : Event)
  find_query() <| $ [es] (var onboarding_custom_action__showHint : bool&)
    onboarding_custom_action__showHint = true
    return true


[es(on_disappear, REQUIRE=onboarding_show_action_hint)]
def onboarding_show_action_hint_destroy(evt : Event)
  find_query() <| $ [es] (var onboarding_custom_action__showHint : bool&)
    onboarding_custom_action__showHint = false
    return true


[es(on_disappear)]
def onboarding_start_input_disappear(evt : Event;
                                     game_effect__attachedTo : EntityId;
                                     onboarding_look_around__initialForwardDir : float3;
                                     onboarding_look_around__angles : float2)
  query(game_effect__attachedTo) <| $ [es] (human_net_phys__prevRootDir : float3; human_net_phys__prevVertDir : float3; var human_input__aimAngle : float2&)
    let anglesOffset = basis_aware_dir_to_angles(onboarding_look_around__initialForwardDir, human_net_phys__prevVertDir, human_net_phys__prevRootDir)
    human_input__aimAngle = onboarding_look_around__angles + anglesOffset


[es(on_appear)]
def onboarding_teleport_to_tag_on_appear(evt : Event;
                                         eid aka teleportee_eid : EntityId;
                                         onboarding_teleport_to_tag_on_spawn__tag : string)
  assume componentName = onboarding_teleport_to_tag_on_spawn__tag
  let componentHash = ecs_hash(componentName)

  find_query() <| $ [es] (eid : EntityId; transform : float3x4)
    if !has(eid, componentName, componentHash)
      return false
    teleport_phys_actor(teleportee_eid, transform)
    return true


[es(on_appear)]
def onboarding_fake_player_contracts_on_appear(evt : Event; onboarding_miniraid_fake_player_contracts__contracts : Array)
  find_query() <| $ [es] (eid : EntityId; var player__loadoutRecieved : bool&)
    make_objective_entities(onboarding_miniraid_fake_player_contracts__contracts, eid)
    player__loadoutRecieved = true
    return true


[es(on_disappear, REQUIRE=onboarding_miniraid_fake_player_contracts__contracts)]
def onboarding_fake_player_contracts_on_disappear(evt : Event)
  find_query() <| $ [es] (eid : EntityId; var player__loadoutRecieved : bool&)
    player__loadoutRecieved = false
    destroy_player_objectives(eid)
    return true


[es(on_appear)]
def onboarding_create_on_appear(evt : Event; onboarding_create_on_appear__template : string)
  createEntity(onboarding_create_on_appear__template)


// This system is needed to ensure that debriefing is shown before the endgame controller is destroyed
[es(REQUIRE=endgame_controller__state)]
def onboarding_destroy_endgame_controller_on_miniraid_exit(evt : EventOnboardingRaidExit; eid : EntityId)
  destroyEntity(eid)


[es]
def onboarding_miniraid_extraction(evt : EventOnboardingRaidExit)
  let success = evt.success && check_hero_completed_onboarding_objective()
  if success
    query() <| $ [es(REQUIRE=onboarding_miniraid_extraction)] (state_machine_transition_trigger__parentTransition : EntityId)
      trigger_state_machine_transition(state_machine_transition_trigger__parentTransition)
  else
    query() <| $ [es(REQUIRE=onboarding_miniraid_failed)] (state_machine_transition_trigger__parentTransition : EntityId)
      trigger_state_machine_transition(state_machine_transition_trigger__parentTransition)


[es(REQUIRE=onboarding_extraction_sequence_final_stage, on_event=EventOnboardingRaidExit)]
def onboarding_destroy_extraction_sequence_final_stage_on_exit(evt : Event; eid : EntityId)
  destroyEntity(eid)


[es(REQUIRE=monolith_deadman_play_extraction_sound_for_hero, on_appear)]
def onboarding_play_extraction_sound_for_hero(evt : Event; game_effect__attachedTo : EntityId)
  query(game_effect__attachedTo) <| $ [es] (transform aka deadman_transform : float3x4)
    query() <| $ [es(REQUIRE=hero)] (eid : EntityId)
      send_net_sound(eid, "onBattleStart", deadman_transform[3])


[es(REQUIRE=relock_miniraid_doors, on_appear)]
def onboarding_miniraid_relock_doors(evt : Event)
  query() <| $ [es(REQUIRE=relock_on_miniraid_start)] (var door_operations__closeOnLock : bool&; var locked__isLocked : bool&)
    door_operations__closeOnLock = true
    locked__isLocked = true


[es(REQUIRE=create_miniraid_marker_entities, on_appear)]
def onboarding_miniraid_create_marker_entities(evt : Event)
  query() <| $ [es] (transform : float3x4;
                     onboarding_miniraid_marker__createTemplate : string;
                     var onboarding_miniraid_marker__entity : EntityId&)
    onboarding_miniraid_marker__entity = createEntity(onboarding_miniraid_marker__createTemplate) <| $(init)
      set(init, "transform", transform)


[es(REQUIRE=create_miniraid_marker_entities, on_event=CmdClearStateMachineEffectImmediately)]
def onboarding_miniraid_destroy_marker_entities(evt : Event)
  query() <| $ [es] (var onboarding_miniraid_marker__entity : EntityId&)
    if has(onboarding_miniraid_marker__entity, "watchedPlayerItem")
      addSubTemplate(onboarding_miniraid_marker__entity, "onboarding_miniraid_memory_item")
    else
      destroyEntity(onboarding_miniraid_marker__entity)
    onboarding_miniraid_marker__entity = INVALID_ENTITY_ID


[es(on_disappear, REQUIRE=onboarding_state_machine)]
def onboarding_cleanup_saved_memory_items(evt : Event)
  query() <| $ [es(REQUIRE=onboarding_miniraid_memory_item)] (eid : EntityId)
    destroyEntity(eid)


[es(on_appear, REQUIRE=clear_miniraid_memory_items)]
def clear_miniraid_memory_items(evt : Event)
  query() <| $ [es(REQUIRE=onboarding_miniraid_memory_item)] (eid : EntityId)
    destroyEntity(eid)


[es(REQUIRE=create_monolith_marker_entities, on_appear)]
def onboarding_monolith_create_marker_entities(evt : Event)
  query() <| $ [es] (transform : float3x4;
                     onboarding_monolith_marker__createTemplate : string;
                     var onboarding_monolith_marker__entity : EntityId&)
    onboarding_monolith_marker__entity = createEntity(onboarding_monolith_marker__createTemplate) <| $(init)
      set(init, "transform", transform)

  query() <| $ [es] (transform : float3x4;
                     onboarding_monolith_marker__createTemplates : StringList;
                     var onboarding_monolith_marker__entities : EidList&)
    reserve(onboarding_monolith_marker__entities, length(onboarding_monolith_marker__createTemplates))
    for templateName in onboarding_monolith_marker__createTemplates
      let entity = createEntity(string(templateName)) <| $(init)
        set(init, "transform", transform)
      push(onboarding_monolith_marker__entities, entity)


[es(REQUIRE=create_monolith_marker_entities, on_event=CmdClearStateMachineEffectImmediately)]
def onboarding_monolith_destroy_marker_entities(evt : Event)
  query() <| $ [es] (var onboarding_monolith_marker__entity : EntityId&)
    destroyEntity(onboarding_monolith_marker__entity)
    onboarding_monolith_marker__entity = INVALID_ENTITY_ID

  query() <| $ [es] (var onboarding_monolith_marker__entities : EidList)
    for entity in onboarding_monolith_marker__entities
      destroyEntity(entity)
    clear(onboarding_monolith_marker__entities)


[es(on_event=EventStateMachineTransition)]
def advance_onboarding_phase(evt : Event; state_machine_transition__advanceProfileOnboardingTo : string; state_machine_transition__savePlayerItems : bool)
  find_query() <| $ [es(REQUIRE=hero)] (possessedByPlr : EntityId;
                                        human_weap__gunEids : EidList;
                                        inventories_owner__inventoryEids : EidList;
                                        human_equipment__slots : Object;
                                        human_equipment__ignoreSlotsOnExtraction : StringList;
                                        am_storage__value : int = 0)
    query(possessedByPlr) <| $ [es] (var player__unlocks : StringList;
                                     var player__newUnlocks : StringList)
      using() <| $(var data : Object)
        using() <| $(var unlocksList : StringList)
          unlocksList |> reserve(length(player__unlocks) + 1)
          push(unlocksList, state_machine_transition__advanceProfileOnboardingTo)
          for newUnlock in player__newUnlocks
            push(unlocksList, newUnlock)
            if !has_value(player__unlocks, newUnlock)
              push(player__unlocks, newUnlock)
          clear(player__newUnlocks)
          set(data, "unlocks", unlocksList)

          using() <| $(var extractionItems : Array)
            if state_machine_transition__savePlayerItems
              save_player_items(extractionItems, human_weap__gunEids, inventories_owner__inventoryEids, human_equipment__slots, human_equipment__ignoreSlotsOnExtraction)
            data |> set("items", extractionItems)
            sendEvent(possessedByPlr, EventOnboardingPhaseResult(amCount = am_storage__value, data = ecs_addr(data)))
    return true


[es(on_event=CmdClearStateMachineEffectImmediately, REQUIRE=onboarding_cleanup_items_in_world)]
def onboarding_cleanup_items_in_world(evt : Event)
  query() <| $ [es(REQUIRE=item_in_world, REQUIRE_NOT=showroom_item)] (eid : EntityId)
    destroyEntity(eid)


[es(on_appear, REQUIRE=onboarding_cleanup_items_in_world_on_appear)]
def onboarding_cleanup_items_in_world_on_appear(evt : Event)
  query() <| $ [es(REQUIRE=item_in_world, REQUIRE_NOT=showroom_item)] (eid : EntityId)
    destroyEntity(eid)


[es]
def onboarding_resend_event_to_self(evt : EventGameTrigger;
                                    eid : EntityId;
                                    onboarding_monolith__resendEventWithSelfOnTrigger : string;
                                    onboarding_monolith__resendEventWithSelfResendTrigger : string)
  if evt.triggerHash != int(ecs_hash(onboarding_monolith__resendEventWithSelfOnTrigger))
    return
  broadcast_net_event(EventGameTrigger(source = eid, target = eid, triggerHash = int(ecs_hash(onboarding_monolith__resendEventWithSelfResendTrigger))))


[es(on_appear)]
def monolith_add_smartwatch_subtemplate(evt : Event; monolith_smartwatch_attached_subtemplate__name : string)
  find_query() <| $ [es(REQUIRE=smartwatch_panel)] (eid : EntityId)
    addSubTemplate(eid, monolith_smartwatch_attached_subtemplate__name)
    return true


[es(on_appear, REQUIRE=smartwatch_panel)]
def monolith_add_smartwatch_subtemplate_late(evt : Event; eid : EntityId)
  query() <| $ [es] (monolith_smartwatch_attached_subtemplate__name : string)
    addSubTemplate(eid, monolith_smartwatch_attached_subtemplate__name)


[es(on_disappear)]
def monolith_remove_smartwatch_subtemplate(evt : Event; monolith_smartwatch_attached_subtemplate__name : string)
  find_query() <| $ [es(REQUIRE=smartwatch_panel)] (eid : EntityId)
    removeSubTemplate(eid, monolith_smartwatch_attached_subtemplate__name)
    return true


[es(on_appear)]
def onboarding_hide_player_base_init(evt : Event; var onboarding_hide_player_base__wasPlayerBase : bool&)
  find_query() <| $ [es(REQUIRE=player_base)] (eid : EntityId)
    onboarding_hide_player_base__wasPlayerBase = true
    destroyEntity(eid)
    return true


[es(on_disappear)]
def onboarding_hide_player_base_disappear(evt : Event; onboarding_hide_player_base__wasPlayerBase : bool&)
  if onboarding_hide_player_base__wasPlayerBase
    createEntity("player_base")


[es(REQUIRE=onboarding_phase_temporary_entity, on_appear)]
def onboarding_phase_temporary_entity_init(evt : Event; eid : EntityId)
  let found = find_query() <| $ [es] (var phase_temporary_entities__list : EidList)
    push(phase_temporary_entities__list, eid)
    return true
  if !found
    logwarn("Could not find phase_temporary_entities__list for temporary entity <{eid}>")


[es(track=human_weap__currentGunEid, tag=gameClient)]
def miniraid_trigger_on_gun_equip(evt : Event; human_weap__currentGunEid : EntityId; miniraid_trigger_on_gun_equip__triggerName : string)
  query(human_weap__currentGunEid) <| $ [es(REQUIRE=gun)] ()
    broadcast_net_event(EventGameTrigger(source = human_weap__currentGunEid, triggerHash = int(ecs_hash(miniraid_trigger_on_gun_equip__triggerName))))


[es(tag=gameClient)]
def miniraid_trigger_on_trap_triggered(evt : EventTrapTrigger;
                                       eid aka trap_eid : EntityId;
                                       miniraid_trigger_on_trap_triggered__triggerName : string)
  find_query() <| $ [es(REQUIRE=hero)] (eid : EntityId)
    broadcast_net_event(EventGameTrigger(source = trap_eid, target = eid, triggerHash = int(ecs_hash(miniraid_trigger_on_trap_triggered__triggerName))))
    return true


[es(tag=gameClient)]
def onboarding_change_ri_on_trigger(evt : EventGameTrigger;
                                    eid : EntityId;
                                    ri_preload__name : string;
                                    game_trigger_processor__onTriggerHash : int;
                                    var onboarding_change_ri_on_trigger__done : bool&)
  if onboarding_change_ri_on_trigger__done || evt.triggerHash != game_trigger_processor__onTriggerHash
    return

  onboarding_change_ri_on_trigger__done = true
  if ri_preload__name != ""
    send_net_event(eid, CmdReplaceRiExtraRes(
      riExtra := ri_preload__name,
      destroyPrevRi = true,
      addPrevRiToRestorables = true,
      createPrevRiDestr = false))


[es(tag=gameClient, on_appear)]
def override_zone_border_max_radius(evt : Event;
                                    monolith_override_zone_border_max_radius__new : float;
                                    var monolith_override_zone_border_max_radius__previous : float&)
  find_query() <| $ [es] (var gravity_zone_border__maxRadius : float&)
    monolith_override_zone_border_max_radius__previous = gravity_zone_border__maxRadius
    gravity_zone_border__maxRadius = monolith_override_zone_border_max_radius__new
    return true


[es(tag=gameClient, on_event=CmdClearStateMachineEffectImmediately)]
def restore_zone_border_max_radius(evt : Event; monolith_override_zone_border_max_radius__previous : float)
  find_query() <| $ [es] (var gravity_zone_border__maxRadius : float&)
    gravity_zone_border__maxRadius = monolith_override_zone_border_max_radius__previous
    return true


[es(tag=gameClient, on_appear, REQUIRE=end_onboarding)]
def end_onboarding(evt : Event)
  find_query() <| $ [es(REQUIRE=onboarding_state_machine)] (eid : EntityId)
    destroyEntity(eid)
    return true


[es(tag=gameClient, on_event=CmdStartOnboardingMemory)]
def start_onboarding_memory(evt : Event;
                            eid aka player_eid : EntityId;
                            var player__unlocks : StringList;
                            var player__newUnlocks : StringList;
                            var active_matter_player__unlockedNotes : StringList)
  sendEvent(player_eid, CmdStopAssistantSpeak())

  find_query() <| $ [es] (var player_profile__replicatorDevicesCount : int&;
                          var player_profile__amCleaningDevicesCount : int&;
                          var player_profile__alterIds : StringList;
                          var player_profile__alterIdsChanged : bool&)
    player_profile__replicatorDevicesCount = 0
    player_profile__amCleaningDevicesCount = 0
    clear(player_profile__alterIds)
    player_profile__alterIdsChanged = true
    return true
  // so all notes will play and journal will be empty
  clear(player__unlocks)
  clear(player__newUnlocks)
  clear(active_matter_player__unlockedNotes)
  print("starting onboarding memory")
  createEntity("onboarding_state_machine_memory")
  broadcastEvent(CmdHideAllUiMenus())


[es(tag=gameClient, on_event=CmdInterruptOnboardingMemory)]
def interrupt_onboarding_memory(evt : Event)
  find_query() <| $ [es(REQUIRE=onboarding_state_machine)] (eid : EntityId; state_machine__states : EidList)
    createEntity("create_entity_on_appear_with_delay") <| $(init)
      set(init, "create_entity_on_appear_with_delay__delay", 6.2)
      set(init, "create_entity_on_appear_with_delay__template", "onboarding_teleport_hero_to_base")
    createEntity("onboarding_disable_input_game_effect+game_effect_with_duration") <| $(init)
      set(init, "game_effect__timeToDestroy", 6.0)
    do_state_machine_transition(eid, state_machine__states[length(state_machine__states) - 1])
    return true


[es(tag=gameClient, on_appear, REQUIRE=hide_base_ambient_sound)]
def hide_base_ambient_sound_on_appear(evt : Event)
  let eid = getSingletonEntity("base_ambient_sound")
  destroyEntity(eid)


[es(tag=gameClient, on_disappear, REQUIRE=hide_base_ambient_sound)]
def show_base_ambient_sound_on_disappear(evt : Event)
  let eid = getSingletonEntity("base_ambient_sound")
  if eid == INVALID_ENTITY_ID
    createEntity("base_ambient_sound")


[es(tag=gameClient)]
def onboarding_check_have_keycard_trigger(evt : EventGameTrigger;
                                          eid : EntityId;
                                          onboarding_check_have_keycard__onTrigger : string;
                                          onboarding_check_have_keycard__sendTrigger : string)
  if evt.triggerHash != int(ecs_hash(onboarding_check_have_keycard__onTrigger))
    return

  let hasKey = find_query() <| $ [es(REQUIRE=(watchedPlayerItem, key_miniraid_item))] ()
    return true

  if hasKey
    return

  broadcast_net_event(EventGameTrigger(source = eid, triggerHash = int(ecs_hash(onboarding_check_have_keycard__sendTrigger))))


[es(tag=gameClient, REQUIRE=base_first_time_override_raid_console, on_appear)]
def onboarding_base_first_time_override_raid_console_appear(evt : Event)
  query() <| $ [es] (eid : EntityId; open_console_menu_on_use__menuName : string)
    if open_console_menu_on_use__menuName != "Raid"
      return

    addSubTemplate(eid, "base_first_time_advance_phase_on_use")


[es(tag=gameClient, REQUIRE=base_first_time_override_raid_console, on_disappear)]
def onboarding_base_first_time_override_raid_console_disappear(evt : Event)
  query() <| $ [es(REQUIRE=base_first_time_advance_phase_on_use)] (eid : EntityId)
    removeSubTemplate(eid, "base_first_time_advance_phase_on_use")


[es(tag=gameClient, on_event=CmdUse, after=on_use_console_menu_ui, REQUIRE=base_first_time_advance_phase_on_use)]
def onboarding_start_miniraid_on_console_use(evt : Event)
  broadcastEvent(CmdRequestOnboardingRaid())
  broadcastEvent(CmdHideAllUiMenus())


[es(tag=gameClient, on_event=CmdClearStateMachineEffectImmediately, REQUIRE=onboarding_miniraid_disarm_traps_before_removal)]
def onboarding_miniraid_disarm_traps_before_removal(evt : Event)
  query() <| $ [es] (var anomaly_trap__triggerFx : das_string&; var trap_trigger_sound__path : das_string&)
    anomaly_trap__triggerFx := ""
    trap_trigger_sound__path := ""


[es(tag=gameClient, no_order)]
def onbnoarding_door_open_trigger(act : UpdateStageInfoAct;
                                  eid aka door_eid : EntityId;
                                  onboarding_door_trigger__requiredAngle : float;
                                  onboarding_door_trigger__sendTrigger : string;
                                  rendinst_axis_rotation__curAngle : float;
                                  rotating_door_sound__prevAngle : float)
  let triggered = rendinst_axis_rotation__curAngle >= onboarding_door_trigger__requiredAngle && rotating_door_sound__prevAngle < onboarding_door_trigger__requiredAngle
  if triggered
    find_query() <| $ [es(REQUIRE=hero)] (eid aka hero_eid : EntityId)
      broadcast_net_event(EventGameTrigger(source = door_eid, target = hero_eid, triggerHash = int(ecs_hash(onboarding_door_trigger__sendTrigger))))
      return true


[es(tag=gameClient, on_appear, REQUIRE=onboarding_state_machine)]
def disable_triggers_in_onboarding(evt : Event)
  query() <| $ [es(REQUIRE=disable_in_onboarding)] (eid : EntityId)
    addSubTemplate(eid, "game_trigger_processor_disabled")


[es(tag=gameClient, on_disappear, REQUIRE=onboarding_state_machine)]
def enable_triggers_after_onboarding(evt : Event)
  query() <| $ [es(REQUIRE=disable_in_onboarding)] (eid : EntityId)
    removeSubTemplate(eid, "game_trigger_processor_disabled")


[es(tag=gameClient, on_appear, REQUIRE=monolith_door)]
def init_monolith_doors(evt : Event; var door_operations__localizations : Object&)
  query() <| $ [es] (player__unlocks : StringList)
    if -1 == player__unlocks |> find_index("onboarding_base_first_time") // we are new player
      door_operations__localizations |> clear()


[es(tag=gameClient, on_disappear, REQUIRE=onboarding_monolith_enable_interaction)]
def onboarding_monolyth_enable_interaction(evt : Event)
  query() <| $ [es] (open_console_menu_on_use__menuName : string;
                     var locked__isLocked : bool&;
                     var locked__statusTip : das_string&)
    if open_console_menu_on_use__menuName == "monolithAccessWnd"
      locked__isLocked = false
      locked__statusTip := ""
