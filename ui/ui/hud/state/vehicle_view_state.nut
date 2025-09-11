import "%dngscripts/ecs.nut" as ecs
from "%ui/ui_library.nut" import *

let comps = [
  {comp = "vehicle_view__isAutomaticTransmission", typ = ecs.TYPE_BOOL,  def=false, sname= "isAutomaticTransmission"}
  {comp = "vehicle_view__gear",                    typ = ecs.TYPE_INT,   def=0,     sname= "gear"}
  {comp = "vehicle_view__neutralGear",             typ = ecs.TYPE_INT,   def=0,     sname= "neutralGear"}
  {comp = "vehicle_view__rpm",                     typ = ecs.TYPE_INT,   def=0,     sname= "rpm"}
  {comp = "vehicle_view__speed",                   typ = ecs.TYPE_INT,   def=0,     sname= "speed"}
  {comp = "vehicle_view__power",                   typ = ecs.TYPE_INT,   def=0,     sname= "power"}
  {comp = "vehicle_view__altitude",                typ = ecs.TYPE_INT,   def=0,     sname= "altitude"}
  {comp = "vehicle_view__bodyHpRel",               typ = ecs.TYPE_FLOAT, def=1.0,   sname= "bodyHpRel"}
  {comp = "vehicle_view__engineHpRel",             typ = ecs.TYPE_FLOAT, def=1.0,   sname= "engineHpRel"}
  {comp = "vehicle_view__transmissionHpRel",       typ = ecs.TYPE_FLOAT, def=1.0,   sname= "transmissionHpRel"}
]

let state = comps.reduce(function(a,b) {
  a[b.sname]<-Watched(b.def)
  return a
}, {})

ecs.register_es("ui_vehicle_view_state",
  {
    [["onInit","onChange"]] = function(_, comp){
      comps.each(@(v) state[v.sname].set(comp[v.comp]))
    }
    function onDestroy(_, __){
      comps.each(@(v) state[v.sname].set(v.def))
    }
  },
  {
    comps_track = comps.map(@(obj) [obj.comp, obj.typ, obj.def]),
    comps_rq = ["vehicleWithWatched"]
  },
  { tags="ui" }
)

return state