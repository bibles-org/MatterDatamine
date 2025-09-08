module entity_mods_common shared
require ecs
require ecs.safe
require DagorSystem
require daslib/strings_boost


def calc_change_mult_attr(map : Object)
  var mult = 1.0
  for mod in map
    mult *= mod.value ?? 1.0
  return mult


def calc_diminishing_change_mult_attr(map : Object)
  var mods : array<float>
  for mod in map
    mods |> push(mod.value ?? 1.0)
  if length(mods) == 0
    return 1.0
  sort(mods) <| $(lhs, rhs : float)
    return lhs > rhs
  var mult = 1.0
  for i in iter_range(mods)
    mult *= pow(mods[i], 1.0 / float(i + 1))
  return mult


def calc_change_add_attr(map : Object)
  var add = 0f
  for mod in map
    add += mod.value ?? 0.
  return add


def calc_diminishing_change_add_attr(map : Object)
  var mods : array<float>
  for mod in map
    mods |> push(mod.value ?? 0.0)
  if length(mods) == 0
    return 0.0
  sort(mods) <| $(lhs, rhs : float)
    return lhs > rhs
  var add = 0f
  for i in iter_range(mods)
    add += pow(mods[i], 1.0 / float(i + 1))
  return add


def add_mod_effects_to_object(entity_mod_effects : Object; key : string; var entity_mods : Object&)
  for entityModEffect in entity_mod_effects
    let modInfo <- entityModEffect.key |> split("+")
    let modName = length(modInfo) > 0 ? modInfo[0] : ""
    let modCalcType = length(modInfo) > 1 ? modInfo[1] : "add"
    let effectValue = entityModEffect.value ?? 0.0

    var modObject = entity_mods[modName] ?as Object
    if modObject == null
      using() <| $(var new_mod_object : Object&)
        using() <| $(var new_mod_calc_object : Object&)
          new_mod_calc_object |> set(key, effectValue)
          new_mod_object |> set(modCalcType, new_mod_calc_object)
          entity_mods |> set(modName, new_mod_object)
    else
      var modCalcObject = (*modObject)[modCalcType] ?as Object
      if modCalcObject == null
        using() <| $(var new_mod_calc_object : Object&)
          new_mod_calc_object |> set(key, effectValue)
          *modObject |> set(modCalcType, new_mod_calc_object)
      else
        *modCalcObject |> set(key, effectValue)


def remove_mod_effects_from_object(entity_mod_effects : Object; key : string; var entity_mods : Object&)
  for entityModEffect in entity_mod_effects
    let modInfo <- entityModEffect.key |> split("+")
    let modName = length(modInfo) > 0 ? modInfo[0] : ""
    let modCalcType = length(modInfo) > 1 ? modInfo[1] : "add"

    var modObject = entity_mods[modName] ?as Object
    if modObject != null
      var modCalcObject = (*modObject)[modCalcType] ?as Object
      if modCalcObject != null
        *modCalcObject |> erase(key)


def get_mod_value(mod_name : string; entity_mod_values : Object; default_value : float)
  return (entity_mod_values[mod_name] ?as Object)?.value ?? default_value
