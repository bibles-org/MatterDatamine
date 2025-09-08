require ecs
require math.base
require game.events.events_active_matter
require fx


[es(tag=render, on_appear)]
def game_trigger_processor_start_effect_init(evt : Event;
                                             game_trigger_processor_start_effect__name : string;
                                             var game_trigger_processor_start_effect__type : int&)
  game_trigger_processor_start_effect__type = get_type_by_name(game_trigger_processor_start_effect__name)


[es(tag=render)]
def game_trigger_processor_start_effect(evt : EventGameTrigger;
                                        transform : float3x4;
                                        game_trigger_processor__onTriggerHash : int;
                                        game_trigger_processor_start_effect__type : int;
                                        game_trigger_processor_start_effect__important : bool;
                                        game_trigger_processor_start_effect__scale : float;
                                        game_trigger_processor_start_effect__fxTm : float3x4)
  if evt.triggerHash != game_trigger_processor__onTriggerHash
    return
  start_effect(game_trigger_processor_start_effect__type,
               transform,
               game_trigger_processor_start_effect__fxTm,
               game_trigger_processor_start_effect__important) <| $(var fx : AcesEffect)
    fx |> setFxScale(game_trigger_processor_start_effect__scale)