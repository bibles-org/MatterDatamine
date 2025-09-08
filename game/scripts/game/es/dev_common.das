module dev_common shared
options no_global_variables = false
require ecs
require ecs.common


var pauseTracker = false

//call from a sytem.
//once the system encounters the same eid twice it assumes it's in the next frame and outputs statistics
//then is stops until scripts are reloaded
def track_affected_entities(eid : EntityId)
  let hasTracker = find_query() <| $ [es] (var system_affects_entity_tracker__counts : Object;
                                           var system_affects_entity_tracker__eids : Object)
    if !pauseTracker
      if get_bool(system_affects_entity_tracker__eids, "{eid}") ?? false
        var total = 0
        for kv in system_affects_entity_tracker__counts
          print("TRACKED: {kv.key}\t= {*get_int(kv.value)}")
          total += *get_int(kv.value)
        print("TRACKED: total {total}")
        clear(system_affects_entity_tracker__counts)
        clear(system_affects_entity_tracker__eids)
        pauseTracker = true
        return true
      set(system_affects_entity_tracker__eids, "{eid}", true)
      let tmplName = getEntityTemplateName(eid)
      let existingCount = get_int(system_affects_entity_tracker__counts, tmplName) ?? 0
      set(system_affects_entity_tracker__counts, tmplName, existingCount + 1)
    return true
  if !hasTracker
    createEntitySync("system_affects_entity_tracker")
    track_affected_entities(eid)
