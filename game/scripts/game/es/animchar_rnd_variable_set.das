require ecs
require AnimV20
require DagorSystem
require DagorRandom


[es(on_appear)]
def animchar_set_rnd_var_on_appear(evt : Event;
                                   animchar__rndVarOnAppearName : string;
                                   animchar__rndVarOnAppearRng : float2;
                                   var animchar : AnimcharBaseComponent&)
  if animchar__rndVarOnAppearRng.x > animchar__rndVarOnAppearRng.y
    logerr("[Animchar] animchar__rndVarOnAppearRng <{animchar__rndVarOnAppearRng.x}>..<{animchar__rndVarOnAppearRng.y}> is wrong")
    return
  let value = rnd_float(animchar__rndVarOnAppearRng.x, animchar__rndVarOnAppearRng.y)

  assume animGraph = animchar.animGraph
  let paramId = *animchar.animGraph |> anim_graph_getParamId(animchar__rndVarOnAppearName, int(PT_ScalarParam))
  if paramId < 0
    logerr("[Animchar] animchar__rndVarOnAppearName <{animchar__rndVarOnAppearName}> not exist")
    return
  *animchar.animState |> anim_state_holder_setParam(paramId, value)
