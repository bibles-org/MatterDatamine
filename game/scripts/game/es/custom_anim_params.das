require ecs
require AnimV20
require ecs.safe
require game.es.ecs_common
require DagorRandom
require DagorSystem


[es(on_appear)]
def apply_custom_anim_params(evt : Event; custom_anim_params : Object; var animchar : AnimcharBaseComponent)
  assume animGraph = animchar.animGraph
  assume animState = animchar.animState
  for animParam in custom_anim_params
    let paramId = *animGraph |> anim_graph_getParamId(animParam.key, int(PT_ScalarParam))
    if paramId >= 0
      let paramValueRng = animParam.value ?? int2(0, 0)
      let paramValue = rnd_int(paramValueRng.x, paramValueRng.y)
      *animState |> anim_state_holder_setParam(paramId, float(paramValue))


[es(on_appear)]
def game_effect_anim_state_holder_set_param(evt : Event;
                                            eid aka game_effect_eid : EntityId;
                                            game_effect__attachedTo : EntityId;
                                            game_effect__animStateHolderSetParamName : string;
                                            game_effect__animStateHolderSetParamValue : float)
  query(game_effect__attachedTo) <| $ [es] (var animchar : AnimcharBaseComponent)
    assume animGraph = animchar.animGraph
    assume animState = animchar.animState
    let paramId = *animGraph |> anim_graph_getParamId(game_effect__animStateHolderSetParamName, int(PT_ScalarParam))
    if paramId >= 0
      *animState |> anim_state_holder_setParam(paramId, game_effect__animStateHolderSetParamValue)
    else
      logerr("{get_entity_info(game_effect_eid)}: Unknown anim param '{game_effect__animStateHolderSetParamName}'")
