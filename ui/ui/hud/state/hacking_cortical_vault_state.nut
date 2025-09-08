import "%dngscripts/ecs.nut" as ecs
from "%ui/ui_library.nut" import *

let state = {
  hackingCorticalVaultFinishAt = Watched(0.0)
  hackingCorticalVaultTotalTime = Watched(0.0)
}

let hackingCorticalVaultQuery = ecs.SqQuery("maintenanceTargetQuery", {
  comps_ro = [
    ["hacking_cortical_vault_process__startedAt", ecs.TYPE_FLOAT],
    ["hacking_cortical_vault_process__hackTime", ecs.TYPE_FLOAT]
  ]
})

ecs.register_es("ui_hacking_cortical_vault_es",
  {
    [["onChange", "onInit"]] = function (_evt, _eid, comp) {
      if (comp.cortical_vault_human_controller__hackingProcessEid != ecs.INVALID_ENTITY_ID) {
        hackingCorticalVaultQuery.perform(
          comp.cortical_vault_human_controller__hackingProcessEid,
          function(__eid, process_comp) {
            state.hackingCorticalVaultFinishAt(
              process_comp.hacking_cortical_vault_process__startedAt + process_comp.hacking_cortical_vault_process__hackTime)
            state.hackingCorticalVaultTotalTime(process_comp.hacking_cortical_vault_process__hackTime)
          })
      }
      else {
        state.hackingCorticalVaultFinishAt(0.0)
        state.hackingCorticalVaultTotalTime(0.0)
      }
    },
    function onDestroy(...){
      state.hackingCorticalVaultFinishAt(0.0)
      state.hackingCorticalVaultTotalTime(0.0)
    }
  },
  {
    comps_track = [
      ["cortical_vault_human_controller__hackingProcessEid", ecs.TYPE_EID]
    ],
    comps_rq=["watchedByPlr"]
  }
)


return state