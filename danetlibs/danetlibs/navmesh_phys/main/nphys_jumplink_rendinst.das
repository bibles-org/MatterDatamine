require ecs
require danetlibs.navmesh_phys.main.nphys_events
require pathfinder


[es(tag=server)]
def on_ri_destroyed(evt : EventRendinstDestroyed)
  if (find_query() <| $ [es(REQUIRE=navPhysJumpLinksDisabler)] () => true)
    return
  squash_jumplinks(evt.riTm, evt.riBBox)
