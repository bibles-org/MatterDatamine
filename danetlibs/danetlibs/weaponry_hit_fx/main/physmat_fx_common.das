module physmat_fx_common shared

require ecs
require ecs.safe
require strings
require DagorSystem
require PhysMat

def for_each_physmat_data(data : Object; group_prefix : string; cb : block<(pmid : int; data : ChildComponent) : void>)
  let pmidCount = physMatCount()

  find_query() <| $ [es] (global_fx__materialGroups : Object)
    let groupPrefixLen = length(group_prefix)
    var pmidSet : array<bool>
    resize(pmidSet, pmidCount)

    for elem in data
      if starts_with(elem.key, group_prefix) //If key starts with groupPrefix, we're dealing with a material group
        let matGroupName = slice(elem.key, groupPrefixLen)
        let matGroup = get_ecs_StringList(global_fx__materialGroups[matGroupName])
        if matGroup == null
          logerr("for_each_physmat_data: failed to find material group '{matGroupName}'")
          continue
        for matName in *matGroup
          let pmid = get_material_id(string(matName))
          if pmid < 0
            logerr("for_each_physmat_data: non-existent material '{matName}' in group '{matGroupName}'")
            continue
          //If we already encountered this pmid then we don't change data for it
          if pmidSet[pmid]
            continue
          invoke(cb, pmid, elem.value)
          pmidSet[pmid] = true
      else //If key does not start with group_prefix, we're dealing with a single material
        let pmid = get_material_id(elem.key)
        if pmid < 0
          logerr("for_each_physmat_data: non-existent material '{get_material_name(get_material(pmid))}'")
          continue
        //Set the effects for this pmid (or change them, if they were already set as part of material group)
        //In other words, settings for a single material have higher priority than settings for material groups
        invoke(cb, pmid, elem.value)
        pmidSet[pmid] = true

    return true

def is_physmat_in_group(physmat_name : string; physmat_group_name : string)
  var res = false
  find_query() <| $ [es] (global_fx__materialGroups : Object)
    let matGroup = get_ecs_StringList(global_fx__materialGroups[physmat_group_name])
    if matGroup == null
      return true
    res = has_value(*matGroup, physmat_name)
    return true
  return res

def is_physmat_in_group(pmid : int; physmat_group_name : string)
  return uint(pmid) < uint(physMatCount()) && is_physmat_in_group(get_material_name(get_material(pmid)), physmat_group_name)
