module burning_common shared
require ecs
require DagorSystem
require DagorShaders
require DagorMaterials
require AnimV20

def set_burning_params_to_attaches(attach_list : EidList; hasBurningVarId : int; burn : float)
  for eid in attach_list
    query(eid) <| $ [es] (var burning_effect : float&;
                          var animchar_render : AnimcharRendComponent;
                          attaches_list : EidList const?)
      burning_effect = burn
      recreate_material(animchar_render) <| $(mat)
        mat |> set_int_param(hasBurningVarId, 1)
      if attaches_list != null
        set_burning_params_to_attaches(*attaches_list, hasBurningVarId, burn)


def set_burning_params(attaches_list : EidList;
                       burning_state : int)

  let hasBurningVarId = get_shader_variable_id("has_burning", true)
  var burn = 0.0
  query() <| $ [es] (burning_lerp_factor : FloatList)//singleton entity
    if 0 <= burning_state && burning_state < length(burning_lerp_factor)
      burn = burning_lerp_factor[burning_state]
    else
      logerr("burning_state = {burning_state} out of bound [0, {length(burning_lerp_factor)})")
  set_burning_params_to_attaches(attaches_list, hasBurningVarId, burn)

