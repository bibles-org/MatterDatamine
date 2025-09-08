module state_machine_common shared

require ecs
require game.events.events_active_matter


def process_state_became_current(state : EntityId)
  query(state) <| $ [es] (state_machine_state__createEntitiesWhenCurrent : StringList;
                          var state_machine_state__createdEntities : EidList)
    for templateName in state_machine_state__createEntitiesWhenCurrent
      push(state_machine_state__createdEntities, createEntity(string(templateName)))


def process_state_no_longer_current(state : EntityId)
  query(state) <| $ [es] (var state_machine_state__createdEntities : EidList)
    for entity in state_machine_state__createdEntities
      sendEventImmediate(entity, CmdClearStateMachineEffectImmediately())
      destroyEntity(entity)
    clear(state_machine_state__createdEntities)


def do_state_machine_transition(state_machine : EntityId; new_state : EntityId; transition : EntityId = INVALID_ENTITY_ID)
  sendEventImmediate(transition, EventStateMachineTransition())
  query(state_machine) <| $ [es] (state_machine__states : EidList; var state_machine__currentState : EntityId&)
    // transition to the same state is allowed
    assert(has_value(state_machine__states, new_state))

    process_state_no_longer_current(state_machine__currentState)
    process_state_became_current(new_state)
    state_machine__currentState = new_state

    sendEvent(state_machine, EventStateMachineStateChanged(stateEid = new_state))


def check_entity_has_components(entity : EntityId; compNames : StringList; compHashes : UInt32List)
  assert(length(compNames) == length(compHashes))
  for i in iter_range(compNames)
    if !has(entity, string(compNames[i]), compHashes[i])
      return false
  return true


def trigger_state_machine_transition(transition : EntityId)
  query(transition) <| $ [es] (state_machine_transition__parentStateMachine : EntityId;
                               state_machine_transition__requiredCurrentStateComps : StringList;
                               state_machine_transition__requiredCurrentStateCompsHashes : UInt32List;
                               state_machine_transition__requiredNextStateComps : StringList;
                               state_machine_transition__requiredNextStateCompsHashes : UInt32List)
    query(state_machine_transition__parentStateMachine) <| $ [es] (state_machine__currentState : EntityId; state_machine__states : EidList)
      if !check_entity_has_components(state_machine__currentState,
                                      state_machine_transition__requiredCurrentStateComps,
                                      state_machine_transition__requiredCurrentStateCompsHashes)
        return
      for potentialState in state_machine__states
        if check_entity_has_components(potentialState,
                                       state_machine_transition__requiredNextStateComps,
                                       state_machine_transition__requiredNextStateCompsHashes)
          do_state_machine_transition(state_machine_transition__parentStateMachine, potentialState, transition)
          return
      print("No valid next state for transition <{transition}> ({getEntityTemplateName(transition)}) in state machine <{state_machine_transition__parentStateMachine}> ({getEntityTemplateName(state_machine_transition__parentStateMachine)})")
