from "net" import get_sync_time

import "%dngscripts/ecs.nut" as ecs
from "%ui/ui_library.nut" import *


let state = {
  isExtinguishing = Watched(false)
  isRepairing = Watched(false)
  maintenanceTime = Watched(0.0)
  maintenanceTotalTime = Watched(0.0)
  vehicleRepairTime = Watched(null)
}

let maintenanceTargetQuery = ecs.SqQuery("maintenanceTargetQuery", {
  comps_ro = [
    ["repairable__repairTotalTime", ecs.TYPE_FLOAT, -1.0],
    ["repairable__repairTime", ecs.TYPE_FLOAT, -1.0],
    ["extinguishable__extinguishTotalTime", ecs.TYPE_FLOAT, -1.0],
    ["extinguishable__extinguishTime", ecs.TYPE_FLOAT, -1.0],
    ["extinguishable__inProgress", ecs.TYPE_BOOL, false],
    ["repairable__inProgress", ecs.TYPE_BOOL, false],
  ]
})
ecs.register_es("ui_maintenance_es",
  {
    [["onChange", "onInit"]] = function (_evt, _eid, comp) {
      let isHeroExtinguishing = comp["extinguisher__active"]
      let isHeroRepairing = comp["repair__active"]
      let mntTgtEid = comp["maintenance__target"]

      state.isExtinguishing.set(isHeroExtinguishing)
      state.isRepairing.set(isHeroRepairing)
      if (mntTgtEid != ecs.INVALID_ENTITY_ID){
        maintenanceTargetQuery.perform(mntTgtEid, function(__eid, tgt_comp){
          state.vehicleRepairTime.set((tgt_comp["repairable__inProgress"] && isHeroRepairing) ? tgt_comp["repairable__repairTime"] : null)
          if (tgt_comp["extinguishable__inProgress"] && isHeroExtinguishing) {
            state.maintenanceTime.set(tgt_comp["extinguishable__extinguishTime"] + get_sync_time())
            state.maintenanceTotalTime.set(tgt_comp["extinguishable__extinguishTotalTime"])
          }
          else if (tgt_comp["repairable__inProgress"] && isHeroRepairing) {
            state.maintenanceTime.set(tgt_comp["repairable__repairTime"] + get_sync_time())
            state.maintenanceTotalTime.set(tgt_comp["repairable__repairTotalTime"])
          }
          else {
            state.maintenanceTime.set(0.0)
            state.maintenanceTotalTime.set(0.0)
          }
        })
      } else {
        state.vehicleRepairTime.set(null)
        state.maintenanceTime.set(0.0)
        state.maintenanceTotalTime.set(0.0)
      }
    },
    function onDestroy(...){
      state.vehicleRepairTime.set(null)
      state.maintenanceTime.set(0.0)
      state.isRepairing.set(false)
      state.isExtinguishing.set(false)
    }
  },
  {
    comps_track = [
      ["maintenance__target", ecs.TYPE_EID],
      ["extinguisher__active", ecs.TYPE_BOOL, false],
      ["repair__active", ecs.TYPE_BOOL, false]
    ],
    comps_rq=["watchedByPlr"]
  }
)

return state