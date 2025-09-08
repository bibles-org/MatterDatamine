from "%ui/ui_library.nut" import *

let { useActionType } = require("%ui/hud/state/actions_state.nut")
let { isExtinguishing, isRepairing, maintenanceTime, maintenanceTotalTime } = require("%ui/hud/state/vehicle_maintenance_state.nut")
let { mkContinuousActionTip } = require("%ui/hud/tips/continuous_action_tip.nut")
let { ACTION_EXTINGUISH, ACTION_REPAIR } = require("%ui/hud/human_actions.nut")
let { mkCountdownTimer } = require("%ui/helpers/timers.nut")


let maintenanceActions = {
  [ACTION_EXTINGUISH] = { icon = "fire-extinguisher"},
  [ACTION_REPAIR] = { icon = "wrench"},
}

let maintenanceTimer = mkCountdownTimer(maintenanceTime)
let maintenanceProgress = Computed(@() maintenanceTotalTime.get() > 0 ? (1 - (maintenanceTimer.get() / maintenanceTotalTime.get())) : 0)

let showMaintenanceProgress = Computed(@() maintenanceTime.get() > 0
                                           && maintenanceActions?[useActionType.get()] != null
                                           && (isRepairing.get() || isExtinguishing.get()))

let fakeItem = Watched("repair_kit_item")
let progressLine = mkContinuousActionTip(maintenanceProgress, maintenanceTimer, fakeItem)

return function() {
  return {
    watch = showMaintenanceProgress
    halign = ALIGN_CENTER
    valign = ALIGN_CENTER
    hplace = ALIGN_CENTER
    vplace = ALIGN_BOTTOM

    children = showMaintenanceProgress.get() ? progressLine : null
  }
}
