import "%dngscripts/ecs.nut" as ecs
from "%ui/ui_library.nut" import *

let { watchedHeroPlayerEid } = require("%ui/hud/state/watched_hero.nut")

let droneEnableToUse       = Watched(false)
let quickUseDroneConsole   = Watched(null)
let isDroneMode            = Watched(false)
let heroDrones             = Watched({})
let currentDroneEid        = Watched(ecs.INVALID_ENTITY_ID)

let droneOperator = Computed(@() isDroneMode.get()
  ? (heroDrones.get()?[currentDroneEid.get()].operator ?? ecs.INVALID_ENTITY_ID)
  : ecs.INVALID_ENTITY_ID)
let droneConnectionQuality = Computed(@() isDroneMode.get()
  ? (heroDrones.get()?[currentDroneEid.get()].connectionQuality ?? 0) : 0)
let droneShowConnectionWarning = Computed(@() isDroneMode.get()
  ? (heroDrones.get()?[currentDroneEid.get()].connectionQualityWarning ?? false) : false)
let distanceToOperator = Computed(@() isDroneMode.get()
  ? (heroDrones.get()?[currentDroneEid.get()].distance ?? 0.0) : 0.0)
let droneOperatorLang = Computed(@() isDroneMode.get() ? heroDrones.get()?[currentDroneEid.get()].operatorLang : null)


ecs.register_es("controling_drone_es", {
  [["onInit", "onChange"]] = function(_evt, _eid, comp) {
    currentDroneEid.set(comp.camera__active ? comp.camera__target : ecs.INVALID_ENTITY_ID)
    isDroneMode.set(comp.camera__active)
  }
  onDestroy = function(_evt, _eid, _comp) {
    isDroneMode.set(false)
    currentDroneEid.set(ecs.INVALID_ENTITY_ID)
  }
},
{
  comps_ro=[["camera__target", ecs.TYPE_EID]]
  comps_track=[["camera__active", ecs.TYPE_BOOL]]
  comps_rq=["droneCamera"]
})


ecs.register_es("connection_quality_drone_es", {
  [["onInit", "onChange"]] = function (_evt, eid, comp) {
    if (watchedHeroPlayerEid.get() == comp.playerOwnerEid) {
      heroDrones.mutate(@(drones) drones[eid] <- {
        operator = comp.drone__owner
        connectionQuality = comp.drone__connectionQuality
        connectionQualityWarning = comp.drone__connectionQualityWarning
        distance = comp.drone__distanceToOperator
        operatorLang = comp.drone__operatorLang
      })
    }
    else if (eid in heroDrones.get())
      heroDrones.mutate(@(drones) drones.$rawdelete(eid))
  }
  onDestroy = function(_evt, eid, _comp) {
    if (eid in heroDrones.get())
      heroDrones.mutate(@(drones) drones.$rawdelete(eid))
  }
},
{
  comps_ro=[
    ["playerOwnerEid", ecs.TYPE_EID],
    ["drone__operatorLang", ecs.TYPE_STRING],
    ["drone__connectionQualityWarning", ecs.TYPE_BOOL],
  ]
  comps_track=[
    ["drone__connectionQuality", ecs.TYPE_INT],
    ["drone__distanceToOperator", ecs.TYPE_FLOAT],
    ["drone__owner", ecs.TYPE_EID],
  ]
})


let getAllDroneForLocalPlayerQuery = ecs.SqQuery("getAllDroneForLocalPlayerQuery", {
  comps_ro =[["playerOwnerEid", ecs.TYPE_EID],
             ["drone__remoteConsole", ecs.TYPE_EID],
             ["drone__enableControl", ecs.TYPE_BOOL]]
})

let getRemoteConsoleInfoQuery = ecs.SqQuery("getRemoteConsoleInfoQuery", {
  comps_rq =["item_drone_remote_console"],
  comps_ro =[["item__proto", ecs.TYPE_STRING],
             ["item__humanOwnerEid", ecs.TYPE_EID]]
})


ecs.register_es("update_enable_use_drone", {
  onUpdate = function(_dt, eid, es_comp){
    if (!es_comp.is_local)
      return
    local findEnableToUseDrone = false
    getAllDroneForLocalPlayerQuery.perform(function(_eid, drone_comp) {
      if (findEnableToUseDrone)
        return
      if (eid == drone_comp.playerOwnerEid && drone_comp.drone__enableControl) {
        getRemoteConsoleInfoQuery.perform(drone_comp.drone__remoteConsole, function(_eid, console_comp) {
          if (console_comp.item__humanOwnerEid != es_comp.possessed)
            return
          droneEnableToUse(true)
          quickUseDroneConsole(console_comp.item__proto)
          findEnableToUseDrone = true
        })
      }
    })
    if (!findEnableToUseDrone) {
      droneEnableToUse(false)
      quickUseDroneConsole(null)
    }
  }
},
{
  comps_ro = [["is_local", ecs.TYPE_BOOL], ["possessed", ecs.TYPE_EID]],
  comps_rq = ["player"],
},
{tags = "gameClient", updateInterval = 0.5, after="*", before="*"})


return {
  droneEnableToUse
  isDroneMode
  droneConnectionQuality
  droneShowConnectionWarning
  quickUseDroneConsole
  droneOperator
  distanceToOperator
  droneOperatorLang
}
