from "%ui/ui_library.nut" import *

let { hackingCorticalVaultFinishAt, hackingCorticalVaultTotalTime } = require("%ui/hud/state/hacking_cortical_vault_state.nut")
let { mkContinuousActionTip } = require("%ui/hud/tips/continuous_action_tip.nut")
let { mkCountdownTimer } = require("%ui/helpers/timers.nut")


let hackingCorticalVaultTimer = mkCountdownTimer(hackingCorticalVaultFinishAt)
let hackingCorticalVaultProgress = Computed(@() hackingCorticalVaultTotalTime.get() > 0 ? (1 - (hackingCorticalVaultTimer.get() / hackingCorticalVaultTotalTime.get())) : 0)

let showHackingCorticalVaultProgress = Computed(@() hackingCorticalVaultFinishAt.get() > 0)

let fakeItem = Watched("")
let hintText = Watched(loc("hint/hacking_cortical_vault"))
let progressLine = mkContinuousActionTip(hackingCorticalVaultProgress, hackingCorticalVaultTimer, fakeItem, hintText)

return function() {
  return {
    watch = showHackingCorticalVaultProgress
    halign = ALIGN_CENTER
    valign = ALIGN_CENTER
    hplace = ALIGN_CENTER
    vplace = ALIGN_BOTTOM

    children = showHackingCorticalVaultProgress.get() ? progressLine : null
  }
}
