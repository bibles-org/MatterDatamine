require ecs
require fx
require math.base
require game.events.events
require DagorMath
require DagorSystem


[es(tag=gameClient, track=isAlive)]
def death_game_effect_invoke(evt : Event;
                             transform : float3x4;
                             isAlive : bool;
                             death_game_effect__name : string;
                             death_game_effect__important : bool = false;
                             death_game_effect__scale : float = 1.0)
  if isAlive
    return

  let fxType = get_type_by_name(death_game_effect__name)
  start_effect(fxType,
               transform,
               IDENT_TM,
               death_game_effect__important) <| $(var fx : AcesEffect)
    fx |> setFxScale(death_game_effect__scale)