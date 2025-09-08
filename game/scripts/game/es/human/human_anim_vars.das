require ecs
require PhysVars
require AnimV20

[es(on_appear)]
def init_selected_weapon_var(evt : Event;
                             human_weap__unarmedEnum : string;
                             var human_anim__selectedWeaponVarId : int&;
                             var phys_vars : PhysVars;
                             var human_weap__unarmedEnumValue : int&)
  human_weap__unarmedEnumValue = animV20_get_enum_value_by_name(human_weap__unarmedEnum)
  human_anim__selectedWeaponVarId = phys_vars |> registerVar("weapon_selected", float(human_weap__unarmedEnumValue))
