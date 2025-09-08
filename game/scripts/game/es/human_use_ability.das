require ecs
require ecs.common
require ecs.safe
require app
require DngNet
require DngDm
require DagorSystem
require DngHuman
require game.events.events
require game.utils.net_utils
require game.events.events_active_matter
require game.events.events_game
require game.es.ability_common
require game.es.ability_enums_common

enum SkipAbilityLevel : int
  skippable
  exitable
  absolute


def pay_ability(eid : ecs::EntityId; initial_price : int; var needed : int&; dry_run = false) : bool
  needed = 0

  let price = roundi(float(initial_price))
  if price <= 0
    return true

  let activeMatterBalance = get_int(eid, "am_storage__value") ?? 0
  if activeMatterBalance >= price
    if !dry_run
      sendEventImmediate(eid, CmdChangeActiveMatterBalance(change = -price, reason = "use_ability"))
    return true
  needed = price - activeMatterBalance
  return false


def get_ability_cooldown(abilityObj : Object const?; hero_ability__abilitiesNextUseTime : Object; cooldown : float) : float
  if cooldown <= 0.0
    return 0.0
  let curTime = get_sync_time()
  let nextUse = get_float(hero_ability__abilitiesNextUseTime, get_string(abilityObj, "name", "")) ?? curTime
  return max(nextUse - curTime, 0.0)


def create_affect_entity(tmpl : string; duration : float; eid : ecs::EntityId;
                         setupTransform : bool; transform : float3x4;
                         phase : int; power : float; ability_name : string) : ecs::EntityId
  let res = createEntity(tmpl) <| $(var init : ComponentsInitializer)
    set(init, "game_effect__attachedTo", eid)
    set(init, "duration", duration)
    set(init, "ability_affect__power", power)
    set(init, "hero_ability__phase", phase)
    set(init, "hero_ability__name", ability_name)
    if setupTransform
      set(init, "transform", transform)
  return res


def schedule_ability_phase(var state : Array; stage : Object const?; name : string; phase : int; eid : EntityId; transform : float3x4)
  let tmplStr = get_ecs_string(stage, "affectTemplate")
  let hasDelay = get_float(stage, "delay") != null
  let delay = get_float(stage, "delay") ?? 0.0
  let duration = get_float(stage, "duration") ?? 0.0
  let setupTransform = get_bool(stage, "setupTransform") ?? false
  let activePhase = get_bool(stage, "activePhase") ?? false
  let isExit = get_bool(stage, "exit") ?? false
  let power = get_float(stage, "power") ?? 1f
  var effEntity = INVALID_ENTITY_ID
  if tmplStr != null && delay <= 0.0
    effEntity = create_affect_entity(string(deref(tmplStr)), duration, eid, setupTransform, transform, phase, power, name)

  push_to_array(state) <| $(var obj : Object)
    set(obj, "timeStart", get_sync_time())
    set(obj, "timeEnd", get_sync_time() + duration + delay)
    set(obj, "effectEntity", effEntity)
    set(obj, "name", name)
    set(obj, "phase", phase)
    set(obj, "activePhase", activePhase)
    set(obj, "duration", duration)
    set(obj, "setupTransform", setupTransform)
    set(obj, "exit", isExit)
    set(obj, "skippable", get_bool(stage, "skippable") ?? false)
    set(obj, "interruptible", get_bool(stage, "interruptible") ?? false)
    set(obj, "unskippableDuration", get_float(stage, "unskippableDuration") ?? 0.0)
    set(obj, "overlap", get_bool(stage, "overlap") ?? false)
    if tmplStr != null && !effEntity
      set(obj, "affectTemplate", string(deref(tmplStr)))
    if hasDelay
      set(obj, "delay", delay)

  let subStages = get_ecs_array(stage, "substages")
  if subStages != null
    let subStagesSize = length(*subStages)
    for i in range(0, subStagesSize)
      schedule_ability_phase(state, get_ecs_object(deref(subStages)[i]), name, -1, eid, transform)


[es(tag=server)]
def human_use_ability_use_index(evt : RqUseAbility; eid : ecs::EntityId const;
                                isAlive, isDowned : bool; transform : float3x4;
                                hero_ability__disableTimeEnd : float;
                                cooldown_reduction_permanent__value : float = 0.0;
                                hero_ability__disabledIndefinitely : bool;
                                var hero_ability__abilities : Array;
                                var hero_ability__abilitiesCooldown : Object;
                                var hero_ability__abilitiesSpentCharges : Object;
                                var hero_ability__abilitiesNextUseTime : Object;
                                var hero_ability__lastUsedAbility : das_string;
                                var hero_ability__abilitiesState : Array)
  if evt.idx < 0 || evt.idx >= length(hero_ability__abilities)
    logerr("Required wrong ability idx, got {evt.idx}, available abilities count {length(hero_ability__abilities)} {eid}<{getEntityTemplateName(eid)}>")
    return

  use_ability(evt.idx, eid, evt.physTick, isAlive, isDowned, transform,
              cooldown_reduction_permanent__value, hero_ability__abilities,
              hero_ability__abilitiesCooldown, hero_ability__abilitiesSpentCharges,
              hero_ability__abilitiesNextUseTime, hero_ability__lastUsedAbility, hero_ability__abilitiesState,
              hero_ability__disableTimeEnd, hero_ability__disabledIndefinitely)


def use_ability(var index : int; eid : ecs::EntityId; tick : int;
                isAlive, isDowned : bool; transform : float3x4;
                cooldown_reduction_permanent__value : float;
                var hero_ability__abilities : Array;
                var hero_ability__abilitiesCooldown : Object;
                var hero_ability__abilitiesSpentCharges : Object;
                var hero_ability__abilitiesNextUseTime : Object;
                var hero_ability__lastUsedAbility : das_string;
                var hero_ability__abilitiesState : Array;
                hero_ability__disableTimeEnd : float;
                hero_ability__disabledIndefinitely : bool;
                dry_run : bool = false)
  if !isAlive || isDowned
    return
  if index < 0 || index >= length(hero_ability__abilities)
    logerr("Required wrong ability index, got {index}, available abilities count {length(hero_ability__abilities)} {eid}<{getEntityTemplateName(eid)}>")
    return

  let curTime = get_sync_time()

  var abilityObj = getRW_ecs_object(hero_ability__abilities[index])
  var name = get_string(abilityObj, "name", "")
  for it in hero_ability__abilitiesState
    let data = get_ecs_object(it)
    if name == get_string(data, "name", "")
      return

  var abilityCooldown = get_float(hero_ability__abilitiesCooldown, name) ?? get_float(abilityObj, "cooldown") ?? 0.0
  let currentCooldown = get_ability_cooldown(abilityObj, hero_ability__abilitiesNextUseTime, abilityCooldown)
  var disableAbilitiesCooldown = hero_ability__disableTimeEnd - curTime
  if currentCooldown > disableAbilitiesCooldown
    disableAbilitiesCooldown = 0.0
  let maxCharges = abilityObj |> get_int("maxCharges") ?? 0
  var spendCharge = false
  if maxCharges > 0
    let spentCharges = get_int(hero_ability__abilitiesSpentCharges, name) ?? 0
    if spentCharges < maxCharges
      spendCharge = true
    else
      if disableAbilitiesCooldown > 0.0
        return
      if currentCooldown > 0.0
        return
      let rechargeAbility = get_string(abilityObj, "rechargeAbility", "")
      if empty(rechargeAbility)
        return
      let rechargeAbilityIndex = get_ability_index_by_name(hero_ability__abilities, rechargeAbility)
      if rechargeAbilityIndex < 0 || rechargeAbilityIndex >= length(hero_ability__abilities)
        logerr("Unknown rechargeAbility, got {rechargeAbility} for {eid}<{getEntityTemplateName(eid)}>")
        return
      index = rechargeAbilityIndex
      abilityObj = getRW_ecs_object(hero_ability__abilities[index])
      name = get_string(abilityObj, "name", "")

  if disableAbilitiesCooldown > 0.0 || hero_ability__disabledIndefinitely
    return

  if !is_ability_prereqs_valid(eid, index, abilityObj)
    return

  if currentCooldown > 0.0
    send_net_event(eid, AbilityUseFailed(ability_name := name,
                                           reason = int(AbilityUseFailedReason.COOLDOWN)))
    return

  var needed = 0
  let activeMatterPrice = get_int(abilityObj, "activeMatterPrice") ?? 0
  if !pay_ability(eid, activeMatterPrice, needed, dry_run)
    return

  if dry_run
    return

  if maxCharges > 0
    if spendCharge
      hero_ability__abilitiesSpentCharges |> set(name, get_int(hero_ability__abilitiesSpentCharges, name) ?? 0 + 1)
    let useDischarged = get_int(hero_ability__abilitiesSpentCharges, name) ?? 0 == maxCharges
    let fallbackCooldown = get_float(abilityObj, "cooldown") ?? 0f
    let baseCooldown = useDischarged ? get_float(abilityObj, "dischargedCooldown") ?? fallbackCooldown : fallbackCooldown
    abilityCooldown = get_reduced_cooldown(baseCooldown, cooldown_reduction_permanent__value)
    hero_ability__abilitiesCooldown |> set(name, abilityCooldown)
  else
    hero_ability__abilitiesCooldown |> set(name, abilityCooldown)

  if tick > 0
    //Immediate to minimize the chance of missing the requested tick
    sendEventImmediate(eid, CmdSetAbilityParam(name = name, physTick = tick))

  //let posessedPlrEid = get_Eid(eid, "possessedByPlr") ?? INVALID_ENTITY_ID
    //sendEvent(posessedPlrEid, [[CmdAddUserstats name= "used_ability_" + name, change = 1.0f]])
  hero_ability__lastUsedAbility := name
  //elif abilityType == FIRST_ABILITY_TYPE
  //  sendEvent(posessedPlrEid, [[CmdAddUserstats name= "used_" + name, change = 1.0f]])

  let hideAfterFirstUse = abilityObj?.hide_ui_after_first_use ?? false
  if hideAfterFirstUse
    set(*abilityObj, "show_in_ui", false)

  set(hero_ability__abilitiesNextUseTime, name, curTime + abilityCooldown)
  let stages = get_ecs_array(abilityObj, "stages")
  if stages != null
    for st in *stages
      let stage = get_ecs_object(st)
      schedule_ability_phase(hero_ability__abilitiesState, stage, name, 0, eid, transform)
      sendEventImmediate(eid, EventInterruptItemUse())
      break


[es(tag=server, REQUIRE_NOT=hero_ability__customCanceling)]
def human_cancel_ability_idx_req_es(evt : RqCancelAbility;
                                    eid : ecs::EntityId const;
                                    var hero_ability__abilities : Array;
                                    isAlive : bool;
                                    transform : float3x4;
                                    var hero_ability__abilitiesState : Array;
                                    var hero_ability__abilitiesLastEndTime : Object)
  if !isAlive
    return
  if evt.idx < 0 || evt.idx >= length(hero_ability__abilities)
    return

  let cancelingAbilityName = (hero_ability__abilities[evt.idx] as Object)?.name ?? ""
  var stateIndex = -1
  for ability, index in hero_ability__abilitiesState, iter_range(hero_ability__abilitiesState)
    let curName = (ability as Object)?.name ?? ""
    if curName == cancelingAbilityName
      stateIndex = index
      break

  if stateIndex >= 0 && stateIndex < length(hero_ability__abilitiesState)
    let abilityName = (hero_ability__abilitiesState[stateIndex] as Object)?.name ?? ""
    skip_active_ability(eid, abilityName,
                        hero_ability__abilities, hero_ability__abilitiesState,
                        transform, hero_ability__abilitiesLastEndTime, true, SkipAbilityLevel.skippable)


def skip_active_ability(eid : ecs::EntityId; ability_name_raw : string; var hero_ability__abilities : Array;
                        var hero_ability__abilitiesState : Array; transform : float3x4;
                        var hero_ability__abilitiesLastEndTime : Object; verbose = true; level = SkipAbilityLevel.skippable) : bool
  let ability_name = ability_name_raw |> clone_string() // make a copy, because we can clean this state later
  let abilitiesSize = length(hero_ability__abilities)
  let statesSize = length(hero_ability__abilitiesState)
  if statesSize == 0 || abilitiesSize == 0
    return false
  for i in range(0, statesSize)
    let abilityState = get_ecs_object(hero_ability__abilitiesState[i])
    if abilityState == null
      continue
    let name = get_string(*abilityState, "name", "") |> clone_string() // make a copy, because we can clean this state later
    if name != ability_name
      continue
    let phase = get_int(*abilityState, "phase") ?? 0
    if phase < 0
      continue
    if level == SkipAbilityLevel.skippable
      let skippable = get_bool(*abilityState, "skippable") ?? false
      if !skippable
        continue
      let unskippableDuration = get_float(*abilityState, "unskippableDuration") ?? 0.0
      let timeStart = get_float(*abilityState, "timeStart") ?? 0.0
      if get_sync_time() < timeStart + unskippableDuration
        continue
    for j in range(0, abilitiesSize)
      let abilityObj = get_ecs_object(hero_ability__abilities[j])
      if get_string(abilityObj, "name", "") == name
        let stages = get_ecs_array(abilityObj, "stages")
        if stages != null
          let size = length(*stages)
          var k = phase + 1
          while k < size
            let stage = get_ecs_object((*stages)[k])
            let isExit = get_bool(stage, "exit") ?? false
            let isSkipExit = get_bool(stage, "skipExit") ?? false
            if isExit || (isSkipExit && level == SkipAbilityLevel.skippable)
              end_state(*abilityState)
              erase(hero_ability__abilitiesState, i)
              cancel_sub_states(hero_ability__abilitiesState, ability_name, /*end_ability*/false)
              schedule_ability_phase(hero_ability__abilitiesState, stage, name, k, eid, transform)
              set(hero_ability__abilitiesLastEndTime, name, get_sync_time())
              if get_bool(abilityObj, "device_ability") ?? false
                hero_ability__abilities |> erase(j)
              return true
            k++
          if level == SkipAbilityLevel.absolute
            end_state(*abilityState)
            erase(hero_ability__abilitiesState, i)
            cancel_sub_states(hero_ability__abilitiesState, ability_name, /*end_ability*/true)
            if get_bool(abilityObj, "device_ability") ?? false
              hero_ability__abilities |> erase(j)
            return true

    if verbose
      logerr("{eid}: <{getEntityTemplateName(eid)}> ability '{name}' hasn't exit state")

  if verbose
    for i in range(0, abilitiesSize)
      let abilityObj = get_ecs_object(hero_ability__abilities[i])
      if get_string(abilityObj, "name", "") == ability_name
        let stages = get_ecs_array(abilityObj, "stages")
        if stages != null
          let size = length(*stages)
          for k in range(0, size)
            let stage = get_ecs_object((*stages)[k])
            let isExit = get_bool(stage, "exit") ?? false
            let isSkipExit = get_bool(stage, "skipExit") ?? false
            if isExit || isSkipExit
              break
        break
  return false

def cancel_sub_states(var hero_ability__abilitiesState : Array; ability_name : string; end_ability : bool)
  var i = 0
  while i < length(hero_ability__abilitiesState)
    let abilityState = get_ecs_object(hero_ability__abilitiesState[i])
    if abilityState == null
      i++
      continue
    let name = get_string(*abilityState, "name", "")
    if name != ability_name
      i++
      continue
    let phase = get_int(*abilityState, "phase") ?? 0
    if phase >= 0
      i++
      continue
    if !end_ability && get_bool(*abilityState, "overlap") ?? false
      i++
      continue
    end_state(*abilityState)
    erase(hero_ability__abilitiesState, i)


[es(tag=server, track=isDowned, before=hero_abilities_effect_track_es)]
def hero_abilities_effect_downed_track_es(evt : Event; eid : EntityId; isDowned : bool; transform : float3x4;
                                          var hero_ability__abilities : Array;
                                          var hero_ability__abilitiesState : Array;
                                          var hero_ability__abilitiesLastEndTime : Object)
  if isDowned
    for it in hero_ability__abilitiesState
      let state = get_ecs_object(it)
      skip_active_ability(eid, get_string(state, "name", ""), hero_ability__abilities,
                          hero_ability__abilitiesState, transform, hero_ability__abilitiesLastEndTime, false, SkipAbilityLevel.exitable)


[es(tag=server, no_order)]
def hero_abilities_effect_track_es(info : UpdateStageInfoAct; eid : EntityId;
                                   var hero_ability__abilities : Array;
                                   var hero_ability__abilitiesState : Array; transform : float3x4;
                                   var hero_ability__abilitiesLastEndTime : Object)
  var i = 0
  var abilitiesToDelete : array<int>
  while i < length(hero_ability__abilitiesState)
    let abilityState = get_ecs_object(hero_ability__abilitiesState[i])
    if abilityState != null
      var delay = get_float(*abilityState, "delay") ?? -1.0
      if delay >= 0.0
        delay -= info.dt
        deref(getRW_float(getRW_ecs_object(hero_ability__abilitiesState[i]), "delay")) = delay
        if delay < 0.0
          let templateName = get_string(*abilityState, "affectTemplate", "")
          let duration = get_float(*abilityState, "duration") ?? -1.0
          if !empty(templateName) && duration > 0.0
            let oldEffEid = get_Eid(*abilityState, "effectEntity") ?? INVALID_ENTITY_ID
            destroyEntity(oldEffEid)
            let setupTransform = get_bool(*abilityState, "setupTransform") ?? false
            let curStatePhase = get_int(*abilityState, "phase") ?? 0
            let abilityName = get_string(abilityState, "name", "")
            let power = get_float(*abilityState, "power") ?? 1f
            let effEid = create_affect_entity(templateName, duration, eid, setupTransform, transform, curStatePhase, power, abilityName)
            deref(getRW_Eid(getRW_ecs_object(hero_ability__abilitiesState[i]), "effectEntity")) = effEid

      if info.curTime <= (get_float(abilityState, "timeEnd") ?? info.curTime)
        i++
      else
        end_state(*abilityState)
        let curStatePhase = get_int(*abilityState, "phase") ?? 0
        if curStatePhase >= 0
          // schedule next phase if there's one
          for it, abilityIdx in hero_ability__abilities, range(0, length(hero_ability__abilities))
            let abilityObj = get_ecs_object(it)
            let abilityName = get_string(abilityObj, "name", "")
            if abilityName == get_string(*abilityState, "name", "")
              let stages = get_ecs_array(abilityObj, "stages")
              if stages != null
                var nextPhase = curStatePhase + 1
                let curStage = get_ecs_object((*stages)[curStatePhase])
                let gotoStageName = curStage |> get_string("gotoStage", "")
                if !empty(gotoStageName)
                  for idx, st in iter_range(*stages), *stages
                    if get_ecs_object(st) |> get_string("label", "") == gotoStageName
                      nextPhase = idx
                      break
                if nextPhase < length(*stages)
                  let stage = get_ecs_object((*stages)[nextPhase])
                  schedule_ability_phase(hero_ability__abilitiesState, stage, abilityName, nextPhase, eid, transform)
                else
                  set(hero_ability__abilitiesLastEndTime, abilityName, get_sync_time())
                  if get_bool(abilityObj, "device_ability") ?? false
                    abilitiesToDelete |> push(abilityIdx)

                break
        erase(hero_ability__abilitiesState, i)

  abilitiesToDelete |> sort() <| $(a, b)
    return a > b
  for idx in abilitiesToDelete
    erase(hero_ability__abilities, idx)

[es(on_event=EventEntityDied, tag=server)]
def hero_with_abilities_died_es(evt : Event; eid : EntityId; transform : float3x4;
                                var hero_ability__abilities : Array;
                                var hero_ability__abilitiesState : ecs::Array;
                                var hero_ability__abilitiesLastEndTime : Object)
  let statesSize = length(hero_ability__abilitiesState)
  if statesSize == 0
    return
  var skipOnDeath = false
  for it in hero_ability__abilities
    let abilityObj = get_ecs_object(it)
    skipOnDeath = get_bool(abilityObj, "skipOnDeath") ?? false

  for it in hero_ability__abilitiesState
    let abilityState = get_ecs_object(it)
    if abilityState != null
      let phase = get_int(*abilityState, "phase") ?? 0
      let abilityName = get_string(*abilityState, "name", "")
      if phase >= 0
        let abilityStatVal = "death_while_in_ability_{abilityName}_{phase + 1}" // +1 for human readable format 1...3
        sendEvent(get_Eid(eid, "possessedByPlr") ?? INVALID_ENTITY_ID, CmdAddUserstats(name = abilityStatVal, change = 1.0f))
      if skipOnDeath
        skip_active_ability(eid, abilityName, hero_ability__abilities, hero_ability__abilitiesState, transform,
                            hero_ability__abilitiesLastEndTime, false, SkipAbilityLevel.exitable)
        break
      set(hero_ability__abilitiesLastEndTime, abilityName, get_sync_time())
      end_state(*abilityState)

  if !skipOnDeath
    clear(hero_ability__abilitiesState)


def end_state(abilityState)
  let effEid = get_Eid(abilityState, "effectEntity") ?? INVALID_ENTITY_ID
  destroyEntity(effEid)


[es(on_event=EventFirstContact, REQUIRE=hero_ability__stop_active_step_after_contact, tag=server)]
def stop_active_step_after_contact_es(evt : Event; var hero_ability__abilitiesState : Array)
  let statesSize = length(hero_ability__abilitiesState)
  if statesSize == 0
    return
  for i in range(0, statesSize)
    let abilityState = get_ecs_object(hero_ability__abilitiesState[i])
    if abilityState == null
      continue
    let phase = get_int(*abilityState, "phase") ?? 0
    if phase < 0
      continue
    deref(getRW_float(getRW_ecs_object(hero_ability__abilitiesState[i]), "timeEnd")) = get_sync_time()
    cancel_sub_states(hero_ability__abilitiesState, get_string(*abilityState, "name", ""), /*end_ability*/false)
    return


[es(on_event=EventFirstContact, REQUIRE=hero_ability__stop_active_step_after_contact, tag=server)]
def stop_velocity_after_contact_es(evt : Event; var human_net_phys : HumanActor)
  human_net_phys.phys.currentState.velocity = float3(0.0)


[es(tag=server, REQUIRE=hero_ability__sensitiveToDamage)]
def skip_ability_on_hero_damaged(evt : EventOnEntityHit;
                                 eid aka hero_eid : EntityId;
                                 transform : float3x4;
                                 var hero_ability__abilities : Array;
                                 var hero_ability__abilitiesState : Array;
                                 var hero_ability__abilitiesLastEndTime : Object)
  if evt.victim == hero_eid
    query() <| $ [es(REQUIRE=ability__cancelOnDamage)] (game_effect__attachedTo : EntityId; hero_ability__name : string;
                                                        hero_ability__cancelOnZoneDamage = true; hero_ability__cancelOnSelfCollDamage = true)
      if game_effect__attachedTo == hero_eid
        if (evt.damageType == int(DamageType.DM_ZONE) && !hero_ability__cancelOnZoneDamage)
          return
        if (evt.damageType == int(DamageType.DM_COLLISION) && !hero_ability__cancelOnSelfCollDamage && evt.offender == hero_eid)
          return
        skip_active_ability(hero_eid, hero_ability__name, hero_ability__abilities, hero_ability__abilitiesState, transform,
                            hero_ability__abilitiesLastEndTime, false, SkipAbilityLevel.absolute)


[es(tag=server)]
def on_force_skip_ability(evt : CmdSkipActiveAbility;
                          eid : EntityId;
                          transform : float3x4;
                          var hero_ability__abilities : Array;
                          var hero_ability__abilitiesState : Array;
                          var hero_ability__abilitiesLastEndTime : Object)
  skip_active_ability(eid, evt.ability_name, hero_ability__abilities, hero_ability__abilitiesState, transform,
                      hero_ability__abilitiesLastEndTime, false, SkipAbilityLevel.absolute)


[es(tag=server)]
def disable_active_abilities(evt : DisableActiveAbilities; eid : EntityId; var hero_ability__abilitiesState : Array; var hero_ability__abilities : Array;
                             transform : float3x4; var hero_ability__abilitiesLastEndTime : Object)
  var targets : array<string>
  for it in hero_ability__abilitiesState
    let data = get_ecs_object(it)
    let interruptible = get_bool(data, "interruptible") ?? false
    let name = get_string(data, "name", "")
    if interruptible && !empty(name)
      push(targets, name |> clone_string()) // make a copy, because we can clean this states later
  for t in targets
    skip_active_ability(eid, t, hero_ability__abilities, hero_ability__abilitiesState, transform,
                        hero_ability__abilitiesLastEndTime, false, SkipAbilityLevel.absolute)


[es(tag=server, no_order, REQUIRE=hero_ability__cancelOnSwitchedAwayFromUnarmed)]
def cancel_ability_on_weapon_switch(act : UpdateStageInfoAct; game_effect__attachedTo : EntityId; hero_ability__name : string)
  query(game_effect__attachedTo) <| $ [es] (human_net_phys : HumanActor;
                                            transform : float3x4;
                                            var hero_ability__abilities : Array;
                                            var hero_ability__abilitiesState : Array;
                                            var hero_ability__abilitiesLastEndTime : Object)
    assume weapEquipState = human_net_phys.phys.currentState.weapEquipState
    if weapEquipState.curSlot != weapEquipState.nextSlot && weapEquipState.nextSlot != HUWeaponSlots.EWS_UNARMED
      skip_active_ability(game_effect__attachedTo,
                          hero_ability__name,
                          hero_ability__abilities,
                          hero_ability__abilitiesState,
                          transform,
                          hero_ability__abilitiesLastEndTime,
                          true,
                          SkipAbilityLevel.absolute)


[es(tag=server, REQUIRE=item__interruptAbilityOnUse)]
def disable_abilities_on_start_item_use(evt : EventOnItemStartUse)
  query(evt.userEid) <| $ [es] (hero_ability__abilitiesState : Array)
    if length(hero_ability__abilitiesState) > 0
      sendEventImmediate(evt.userEid, DisableActiveAbilities())
