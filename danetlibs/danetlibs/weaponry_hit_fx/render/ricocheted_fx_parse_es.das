require ecs
require ecs.safe
require ecs.extra_set
require danetlibs.weaponry_hit_fx.main.physmat_fx_common
require danetlibs.weaponry_hit_fx.render.ricocheted_fx_common
require PhysMat
require DagorSystem
require daslib.algorithm


def private get_fx_name(field_name : string; info_for_material : Object; default_value : string)
  let fxName = info_for_material[field_name] ?as string
  if fxName == null
    return default_value

  return string(*fxName)

def private get_fx_float(field_name : string; info_for_material : Object; default_value : float)
  let fxValue = info_for_material[field_name] ?as float

  if fxValue == null
    return default_value

  return *fxValue


def private parse_effect_group(var effect_group : Object&)
  let infoForMats = effect_group.info ?as Object
  if infoForMats == null
    return

  var destroyedFxs, ricochetedFxs : array<string>
  var destroyedFxChance, ricochetedFxChance, destroyedFxVelocity, destroyedFxAngularSpeed, ricochetedFxVelocity, ricochetedFxAngularSpeed : array<float>
  let pmid_count = physMatCount()
  destroyedFxs |> resize(pmid_count)
  destroyedFxChance |> resize(pmid_count)
  destroyedFxVelocity |> resize(pmid_count)
  destroyedFxAngularSpeed |> resize(pmid_count)
  ricochetedFxs |> resize(pmid_count)
  ricochetedFxChance |> resize(pmid_count)
  ricochetedFxVelocity |> resize(pmid_count)
  ricochetedFxAngularSpeed |> resize(pmid_count)

  for_each_physmat_data(*infoForMats, /*group_prefix*/"group__") <| $(pmid : int; data : ChildComponent)
    let obj = data as Object
    if obj == null
      logerr("parse_effect_group: wrong value type for material {get_material_name(get_material(pmid))}; should be 'object'")
      return

    destroyedFxs[pmid] := get_fx_name("destroyedFxType", *obj, "")
    destroyedFxChance[pmid] := get_fx_float("destroyedFxChance", *obj, DEFAULT_CHANCE)
    destroyedFxVelocity[pmid] := get_fx_float("destroyedFxVelocity", *obj, DEFAULT_VELOCITY)
    destroyedFxAngularSpeed[pmid] := get_fx_float("destroyedFxAngularSpeed", *obj, DEFAULT_ANGULAR_SPEED)
    ricochetedFxs[pmid] := get_fx_name("ricochetedFxType", *obj, "")
    ricochetedFxChance[pmid] := get_fx_float("ricochetedFxChance", *obj, DEFAULT_CHANCE)
    ricochetedFxVelocity[pmid] := get_fx_float("ricochetedFxVelocity", *obj, DEFAULT_VELOCITY)
    ricochetedFxAngularSpeed[pmid] := get_fx_float("ricochetedFxAngularSpeed", *obj, DEFAULT_ANGULAR_SPEED)

  effect_group |> set("destroyedFxs", destroyedFxs)
  effect_group |> set("destroyedFxChance", destroyedFxChance)
  effect_group |> set("destroyedFxVelocity", destroyedFxVelocity)
  effect_group |> set("destroyedFxAngularSpeed", destroyedFxAngularSpeed)
  effect_group |> set("ricochetedFxs", ricochetedFxs)
  effect_group |> set("ricochetedFxChance", ricochetedFxChance)
  effect_group |> set("ricochetedFxVelocity", ricochetedFxVelocity)
  effect_group |> set("ricochetedFxAngularSpeed", ricochetedFxAngularSpeed)


[es(on_appear)]
def ricocheted_fx_init_es(evt : Event;
                          var global_hit_fx__effectGroups : Array&)
  for elem in global_hit_fx__effectGroups
    var effectGroup = elem as Object
    if effectGroup == null
      logerr("global_hit_fx_init_es: all elements in global_hit_fx__effectGroups should be 'object'")
      continue
    parse_effect_group(*effectGroup)
