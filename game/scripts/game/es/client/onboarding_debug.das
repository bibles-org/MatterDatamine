options no_aot

require ecs
require strings
require daslib/strings_boost
require DagorConsole
require danetlibs.console_commands.main.console_common
require game.es.state_machine_common
require net
require game.utils.net_utils
require game.events.events_active_matter
require game.es.notes_common
require game.es.unlocks_common
require game.es.net_console_macro


[console_cmd(name="onboarding.start")]
def onboarding_start()
  let onboardingActive = find_query() <| $ [es(REQUIRE=onboarding_state_machine)] ()
    return true

  if onboardingActive
    console_print("Onboarding is already in progress")
    return

  createEntity("onboarding_state_machine")


[console_cmd(name="onboarding.get_state")]
def onboarding_get_phase()
  let onboardingActive = find_query() <| $ [es(REQUIRE=onboarding_state_machine)] (state_machine__currentState : EntityId)
    console_print("Current onboarding state is {state_machine__currentState} ({getEntityTemplateName(state_machine__currentState)})")
    return true

  if !onboardingActive
    console_print("Onboarding is not in progress")


[console_processor]
def onboarding_set_phase(args : array<string>;
                         collect : bool;
                         var hints : ConsoleProcessorHints)
  assume cmd = "onboarding.set_phase"
  var processed = false
  if collect
    hints |> add_hint(cmd, /*minArgs=*/1, /*maxArgs=*/1, "<phase>")

  let onboardingActive = find_query() <| $ [es(REQUIRE=onboarding_state_machine)] (state_machine__stateTemplates : StringList;
                                                                                   state_machine__states : EidList;
                                                                                   eid aka state_machine_eid : EntityId)
    if collect
      let inputs <- args[0] |> split(" ")
      var possiblePhases : array<string>
      if length(inputs) > 1 && length(strip(inputs[1])) > 0
        for name in state_machine__stateTemplates
          if find(string(name), inputs[1]) != -1
            possiblePhases |> push(string(name))
      else
        for name in state_machine__stateTemplates
          possiblePhases |> push(string(name))

      for phase in possiblePhases
        hints |> add_hint("{cmd} {phase}", /*minArgs=*/0, /*maxArgs=*/0, "")

    elif args[0] == cmd
      processed = true
      let argc = args |> length()
      if argc != 2
        console_print("Wrong number of arguments. Expected 1, got {argc - 1}")
        return true
      let phase = args[1]
      if !has_value(state_machine__stateTemplates, phase)
        console_print("Unknown phase: \"{phase}\"")
        return true

      console_print("Setting onboarding phase to \"{phase}\"")
      let cmpName = phase
      let cmpHash = ecs_hash(cmpName)
      for state in state_machine__states
        if has(state, cmpName, cmpHash)
          do_state_machine_transition(state_machine_eid, state)
          return true

    return true

  if !onboardingActive && !collect && args[0] == cmd
    console_print("Onboarding is not in progress")

  return processed


[console_processor]
def onboarding_open_note(args : array<string>;
                         collect : bool;
                         var hints : ConsoleProcessorHints)
  assume cmd = "onboarding.open_note"
  var processed = false
  let noteIds = fixed_array<string>("onboarding_wish",
                         "onboarding_bunker_first_visit",
                         "onboarding_miniraid_start",
                         "onboarding_miniraid_body",
                         "onboarding_miniraid_wall",
                         "onboarding_miniraid_am",
                         "onboarding_miniraid_portal",
                         "onboarding_contracts",
                         "note_onboarding_bunker_end",
                         "distorted",
                         "invisible",
                         "flowerman",
                         "devourer",
                         "swarm",
                         "turnedSoldier",
                         "turnedOperative",
                         "thunderball",
                         "seeds",
                         "furnace",
                         "teleport",
                         "jumpPad")

  if collect
    let inputs <- args[0] |> split(" ")
    if length(inputs) > 1 && length(strip(inputs[1])) > 0
      for note in noteIds
        if find(string(note), inputs[1]) != -1
          hints |> add_hint("{cmd} {note}", /*minArgs=*/0, /*maxArgs=*/0, "")
    else
      hints |> add_hint(cmd, /*minArgs=*/1, /*maxArgs=*/1, "<note_id>")
  elif args[0] == cmd
    processed = true
    let argc = args |> length()
    if argc != 2
      console_print("Wrong number of arguments. Expected 1, got {argc - 1}")
      return processed
    let note = args[1]
    if empty(note)
      return processed

    console_print("Unlocking \"{note}\"")
    find_query() <| $ [es(REQUIRE=player)] (is_local : bool; eid : EntityId)
      if !is_local
        return false

      if !open_note_for_player(eid, note)
        console_print("Note \"{note}\" is already unlocked")

      return true

  return processed


[net_console_cmd(name="onboarding.start_smartwatch_cutscene")]
def start_smartwatch_cutscene()
  query() <| $ [es] (var interference_source__active : bool&)
    interference_source__active = true
  createEntity("onboarding_watch_cutscene_effect_creator")


[console_cmd(name="onboarding.finish")]
def onboarding_finish()
  let onboardingActive = find_query() <| $ [es(REQUIRE=onboarding_state_machine)] (eid : EntityId; state_machine__states : EidList)
    createEntity("onboarding_teleport_hero_to_base")
    do_state_machine_transition(eid, state_machine__states[length(state_machine__states) - 1])
    return true

  if !onboardingActive
    console_print("Onboarding is not in progress")
    return


[console_cmd(name="onboarding.finish_with_unlocks")]
def onboarding_finish_with_unlocks()
  onboarding_finish()
  let onboardingUnlocks = fixed_array<string>("onboarding_base_first_time",
                                   "onboarding_miniraid",
                                   "onboarding_base_key_insertion",
                                   "onboarding_finished")

  find_query() <| $ [es(REQUIRE=player)] (eid : EntityId; is_local : bool)
    if !is_local
      return false
    for unlock in onboardingUnlocks
      open_unlock_for_player(eid, unlock)
      console_command("profile.add_player_unlock \"{unlock}\"")
    return true