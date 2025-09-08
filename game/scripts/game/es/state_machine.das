require ecs
require game.es.state_machine_common


[es(on_appear)]
def init_state_machine(evt : Event;
                       eid aka state_machine_eid : EntityId;
                       state_machine__stateTemplates : StringList;
                       state_machine__transitionTemplates : StringList;
                       var state_machine__states : EidList;
                       var state_machine__transitions : EidList)
  reserve(state_machine__states, length(state_machine__stateTemplates))
  for templateName in state_machine__stateTemplates
    push(state_machine__states, createEntity(string(templateName)))

  reserve(state_machine__transitions, length(state_machine__transitionTemplates))
  for templateName in state_machine__transitionTemplates
    let transition = createEntity(string(templateName)) <| $(init)
      set(init, "state_machine_transition__parentStateMachine", state_machine_eid)
    push(state_machine__transitions, transition)


[es(on_disappear)]
def cleanup_state_machine(evt : Event;
                          state_machine__currentState : EntityId;
                          state_machine__states : EidList;
                          state_machine__transitions : EidList)
  process_state_no_longer_current(state_machine__currentState)

  for state in state_machine__states
    destroyEntity(state)

  for transition in state_machine__transitions
    destroyEntity(transition)


[es(on_appear)]
def init_state_machine_transition(evt : Event;
                                  eid aka transition_eid : EntityId;
                                  state_machine_transition__requiredCurrentStateComps : StringList;
                                  state_machine_transition__requiredNextStateComps : StringList;
                                  state_machine_transition__triggerTemplates : StringList;
                                  var state_machine_transition__requiredCurrentStateCompsHashes : UInt32List;
                                  var state_machine_transition__requiredNextStateCompsHashes : UInt32List;
                                  var state_machine_transition__triggers : EidList)
  assume currentCompHashes = state_machine_transition__requiredCurrentStateCompsHashes
  assume currentCompNames = state_machine_transition__requiredCurrentStateComps

  assume nextCompHashes = state_machine_transition__requiredNextStateCompsHashes
  assume nextCompNames = state_machine_transition__requiredNextStateComps

  assume triggerTemplates = state_machine_transition__triggerTemplates
  assume triggers = state_machine_transition__triggers

  reserve(currentCompHashes, length(currentCompNames))
  for requiredCompName in currentCompNames
    push(currentCompHashes, ecs_hash(string(requiredCompName)))

  reserve(nextCompHashes, length(nextCompNames))
  for requiredCompName in nextCompNames
    push(nextCompHashes, ecs_hash(string(requiredCompName)))

  reserve(triggers, length(triggerTemplates))
  for templateName in triggerTemplates
    let trigger = createEntity(string(templateName)) <| $(init)
      set(init, "state_machine_transition_trigger__parentTransition", transition_eid)
    push(triggers, trigger)


[es(on_disappear)]
def cleanup_state_machine_transition(evt : Event;
                                     state_machine_transition__triggers : EidList)
  for trigger in state_machine_transition__triggers
    destroyEntity(trigger)
