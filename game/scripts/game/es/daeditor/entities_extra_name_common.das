module entities_extra_name_common shared
require ecs

def get_entity_extra_name_common(eid : EntityId)
  var extraName = ""
  query(eid) <| $ [es] (ri_extra__name : string = "";
                        floatingRiGroup__resName : string = "";
                        ri_gpu_object__name : string = "";
                        dagdp__name : string = "";
                        groupName : string = "")
    let compsUsedAsExtraName = fixed_array(
      ri_extra__name,
      floatingRiGroup__resName,
      ri_gpu_object__name,
      dagdp__name,
      groupName
    )
    // select first non empty one
    for comp in compsUsedAsExtraName
      if comp != ""
        extraName = comp
        return

  return extraName
