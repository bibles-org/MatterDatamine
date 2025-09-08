require ecs
require ecs.safe
require app
require DngNet
require ecs.common
require DagorInput
require DagorSystem
require DngHuman
require game.events.input_events
require game.events.events_active_matter
require game.es.ability_common
require game.es.ability_enums_common


def initActions(var human_input__useAbility1, human_input__useAbility2, human_input__useAbility3 : int&)
  human_input__useAbility1 = int(get_action_handle("Human.UseAbility1", TYPEGRP_DIGITAL))
  human_input__useAbility2 = int(get_action_handle("Human.UseAbility2", TYPEGRP_DIGITAL))
  human_input__useAbility3 = int(get_action_handle("Human.UseAbility3", TYPEGRP_DIGITAL))


def resetActions(var human_input__useAbility1, human_input__useAbility2, human_input__useAbility3 : int&)
  human_input__useAbility1 = int(BAD_ACTION_HANDLE)
  human_input__useAbility2 = int(BAD_ACTION_HANDLE)
  human_input__useAbility3 = int(BAD_ACTION_HANDLE)


[es(tag=input)]
def human_use_ability_input_setup(evt : EventDaInputInit; var human_input__useAbility1, human_input__useAbility2, human_input__useAbility3 : int&)
  if evt.init
    initActions(human_input__useAbility1, human_input__useAbility2, human_input__useAbility3)
  else
    resetActions(human_input__useAbility1, human_input__useAbility2, human_input__useAbility3)

[es(tag=input, on_appear)]
def human_use_ability_input_appear(evt : Event; var human_input__useAbility1, human_input__useAbility2, human_input__useAbility3 : int&)
  initActions(human_input__useAbility1, human_input__useAbility2, human_input__useAbility3)

[es(tag=input, on_event=(EventComponentsDisappear, EventEntityDestroyed))]
def human_use_ability_input_disappear(evt : Event; var human_input__useAbility1, human_input__useAbility2, human_input__useAbility3 : int&)
  resetActions(human_input__useAbility1, human_input__useAbility2, human_input__useAbility3)


def initAbilitityHandles(hero_ability__abilities : Array;
                         var hero_ability__abilitiesActionHandles : IntList)

  hero_ability__abilitiesActionHandles |> resize(length(hero_ability__abilities))

  for ability, abilityHandle in hero_ability__abilities, hero_ability__abilitiesActionHandles
    let abilityObj = ability as Object
    let actionHandleName = abilityObj?.actionHandleName
    if actionHandleName != null
      abilityHandle = int(get_action_handle(actionHandleName ?? "", TYPEGRP_DIGITAL))
    else
      abilityHandle = int(BAD_ACTION_HANDLE)


[es(tag=input, on_appear)]
def human_use_ability_handles_appear(evt : Event;
                                     hero_ability__abilities : Array;
                                     var hero_ability__abilitiesActionHandles : IntList)
  initAbilitityHandles(hero_ability__abilities, hero_ability__abilitiesActionHandles)

[es(tag=input, on_event=(EventComponentsDisappear, EventEntityDestroyed))]
def human_use_ability_handles_disappear(evt : Event;
                                        var hero_ability__abilitiesActionHandles : IntList)
  hero_ability__abilitiesActionHandles |> clear()


[es(tag=input)]
def human_use_ability_handles_setup(evt : EventDaInputInit;
                                    hero_ability__abilities : Array;
                                    var hero_ability__abilitiesActionHandles : IntList)
  if evt.init
    initAbilitityHandles(hero_ability__abilities, hero_ability__abilitiesActionHandles)
  else
    hero_ability__abilitiesActionHandles |> clear()


def request_use_ability(actor_eid : EntityId;
                        ability_idx : int;
                        ability_name : string;
                        phys_tick : int)
  sendEventImmediate(actor_eid, PreRqUseAbility(idx = ability_idx, physTick = phys_tick))
  send_net_event(actor_eid, RqUseAbility(idx = ability_idx, physTick = phys_tick))
  sendEvent(actor_eid, CmdSetAbilityParam(name = ability_name, physTick = phys_tick))


[es(tag=input)]
def human_use_ability(evt : EventDaInputActionTriggered;
                      eid : EntityId;
                      input__enabled : bool;
                      human_input__useAbility1, human_input__useAbility2, human_input__useAbility3 : int;
                      hero_ability__abilities, hero_ability__abilitiesState : Array;
                      hero_ability__abilitiesNextUseTime : Object;
                      hero_ability__abilitiesSpentCharges : Object;
                      hero_ability__abilitiesActionHandles : IntList;
                      var hero_ability__tmpSpentChanges : Object?;
                      var hero_ability__tmpResetAt : Object?;
                      human_net_phys : HumanActor const?)
  let tick = human_net_phys.phys.currentState.atTick
  var abilityIdx = -1

  if input__enabled
    abilityIdx = find_index(hero_ability__abilitiesActionHandles, int(evt.action))

    if abilityIdx < 0
      if int(evt.action) == human_input__useAbility1
        abilityIdx = 0
      elif int(evt.action) == human_input__useAbility2
        abilityIdx = 1
      elif int(evt.action) == human_input__useAbility3
        abilityIdx = 2

      // Abilities with custom input shouldn't be available by default useAbility actions
      if (abilityIdx >= 0 && abilityIdx < length(hero_ability__abilitiesActionHandles)
        && hero_ability__abilitiesActionHandles[abilityIdx] != int(BAD_ACTION_HANDLE))
        abilityIdx = -1

  if abilityIdx >= 0 && length(hero_ability__abilities) > abilityIdx
    let name = get_string(get_ecs_object(hero_ability__abilities[abilityIdx]), "name", "")
    let hasActiveAbility = has_ability_state_by_name(hero_ability__abilitiesState, name)
    if hasActiveAbility
      send_net_event(eid, RqCancelAbility(idx = abilityIdx))
      return
    let nextUse = get_float(hero_ability__abilitiesNextUseTime, name) ?? .0
    let curTime = get_sync_time()
    if nextUse > curTime
      send_net_event(eid, AbilityUseFailed(ability_name := name,
                                           reason = int(AbilityUseFailedReason.COOLDOWN)))
      return

    //For abilities like dash which are triggered on both the client and the server separately,
    //It is important that we can detect on the client that the ability will fail.
    //If the ping is high we may send several requests before we get the first response.
    //So remember these request and subtract them from available charges.

    //This isn't full AAS model, for simplicity the information about charges is reset after a short delay.
    //This will only matter if the player uses the last charge but the server rejects it.
    //In this rare case this logic will block the player from attempting again for resetDelay seconds.
    if hero_ability__tmpSpentChanges != null && hero_ability__tmpResetAt != null
      var abilityObj = get_ecs_object(hero_ability__abilities[abilityIdx])
      if !is_ability_prereqs_valid(eid, abilityIdx, abilityObj)
        return
      let spentCharges = get_int(hero_ability__abilitiesSpentCharges, name) ?? 0
      let tempResetAt = get_float(*hero_ability__tmpResetAt, name) ?? .0
      let clientSpentCharges = tempResetAt < curTime ? 0 : get_int(*hero_ability__tmpSpentChanges, name) ?? 0
      let maxCharges = abilityObj |> get_int("maxCharges") ?? 1
      let availableCharges = maxCharges - spentCharges - clientSpentCharges
      if availableCharges > 0
        request_use_ability(eid, abilityIdx, name, tick)

        let resetDelay = abilityObj |> get_float("clientResetDelay") ?? 0.5
        set(*hero_ability__tmpSpentChanges, name, clientSpentCharges + 1)
        set(*hero_ability__tmpResetAt, name, curTime + resetDelay)
    else
      request_use_ability(eid, abilityIdx, name, tick)
