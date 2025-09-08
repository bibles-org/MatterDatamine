from "%ui/ui_library.nut" import *
import "%dngscripts/ecs.nut" as ecs

let agencyLoadoutGenerators = Watched([])

ecs.register_es("nexus_agency_loadouts_init", {
  onInit = function(_evt, _eid, comp) {
    let generators = comp.nexus_agency_loadouts__generators.getAll()
    let names = comp.nexus_agency_loadouts__names.getAll()
    agencyLoadoutGenerators.mutate(function(v) {
      for (local i = 0; i < comp.nexus_agency_loadouts__generators.getAll().len(); i++) {
        v.append({generator = generators[i], name = loc(names[i])})
      }
    })
  }
  onDestroy = function(_evt, _eid, _comp) {
    agencyLoadoutGenerators.set([])
  }
}, {
  comps_ro =[
    ["nexus_agency_loadouts__generators", ecs.TYPE_STRING_LIST],
    ["nexus_agency_loadouts__names", ecs.TYPE_STRING_LIST],
  ]
},
{
  tags = "gameClient"
})

return {
  agencyLoadoutGenerators
}