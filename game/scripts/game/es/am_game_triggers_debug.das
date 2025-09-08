options no_aot
require ecs
require DagorConsole
require DagorSystem
require strings
require game.es.server_debug_common
require game.events.events_active_matter
require daslib/strings_boost
require DngNet


def push_unique_trigger(var known_trigger_names : array<string>;
                        trigger_name : string;
                        trigger_names_limit : int;
                        trigger_name_starts_with : string)
  if length(known_trigger_names) >= trigger_names_limit
    return

  if trigger_name == "" || known_trigger_names |> has_value(trigger_name)
    return

  if trigger_name_starts_with != "" && !starts_with(trigger_name, trigger_name_starts_with)
    return

  known_trigger_names |> push(trigger_name)


[console_processor]
def game_trigger_invoke_processor(args : array<string>;
                                  collect : bool;
                                  var hints : ConsoleProcessorHints)
  let cmd = "game_trigger.invoke"
  let desc = "Invokes game_trigger with the specified name"
  if collect
    var knownTriggerNames : array<string>
    if starts_with(args[0], "{cmd} ")
      let inputs <- args[0] |> split(" ")
      let triggerName = length(inputs) >= 2 ? inputs[1] : ""

      let maxHintsCount = 20

      query() <| $ [es] (game_trigger_processor__onTrigger : string)
        knownTriggerNames |> push_unique_trigger(game_trigger_processor__onTrigger, maxHintsCount, triggerName)

      query() <| $ [es] (game_trigger_processor_transform_transition__forwardTrigger : string;
                         game_trigger_processor_transform_transition__backwardTrigger : string)
        knownTriggerNames |> push_unique_trigger(game_trigger_processor_transform_transition__forwardTrigger,
                                                maxHintsCount, triggerName)
        knownTriggerNames |> push_unique_trigger(game_trigger_processor_transform_transition__backwardTrigger,
                                                maxHintsCount, triggerName)

      for knownTriggerName in knownTriggerNames
        hints |> add_hint("{cmd} {knownTriggerName}", 0, 0, "", "Invokes '{knownTriggerName}' game trigger")

    if length(knownTriggerNames) == 0
      hints |> add_hint("{cmd}", 1, 1, "<trigger_name>", desc)

  elif args[0] == cmd
    if !is_server()
      var message : string
      for arg in args
        message += arg + " "
      exec_server_cmd(message)
    else
      let argc = args |> length()
      let triggerName = argc >= 2 ? args[1] : ""
      broadcast_net_event(EventGameTrigger(source = INVALID_ENTITY_ID, triggerHash = int(ecs_hash(triggerName))))

    return true

  return false
