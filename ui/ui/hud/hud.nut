import "%ui/hud/tips/all_tips.nut" as all_tips
import "%ui/hud/hud_layout.nut" as hudLayout
import "%ui/hud/tips/network_error.nut" as network_error
from "%ui/hud/hud_menus.nut" import menusUi
import "%ui/hud/hud_under.nut" as hud_under
import "%ui/hud/hud_objectives.nut" as hudObjectives
from "%ui/hud/tips/nexus_round_mode_alerts.nut" import alertsUi
from "%ui/hud/state/shooting_range_state.nut" import shootingRangeWarn
import "%ui/hud/vehicle_crosshair.nut" as vehicleCrosshair
import "%ui/hud/turret_crosshair.nut" as turretCrosshair
import "%ui/hud/commander_crosshair.nut" as commanderCrosshair
from "%ui/ui_library.nut" import *
from "%ui/hud/menus/chat.ui.nut" import setInteractive, showChatInput

let { inspectorRoot } = require("%darg/helpers/inspector.nut")

require("%ui/hud/state/cmd_hero_log_event.nut")
require("%ui/hud/state/gun_blocked_es.nut")

let { chatOutMessage } = require("%ui/hud/state/chat.nut")
let hudDroneOperatorMark = require("%ui/hud/hud_drone_operator_mark.nut")
let JB = require("%ui/control/gui_buttons.nut")
let { hit_marks } = require("%ui/hud/hit_marks.nut")
let { inTank, isGunner } = require("%ui/hud/state/vehicle_state.nut")
let { isDroneMode } = require("%ui/hud/state/drone_state.nut")
let { showroomActive } = require("%ui/hud/state/showroom_state.nut")

let groundVehicleCrosshair = @() {
  watch = [inTank, isGunner, isDroneMode]
  children = isDroneMode.get() ? null : ((!inTank.get() || isGunner.get()) ? turretCrosshair : commanderCrosshair)
}

let hud = @() {
  size = flex(),
  watch = showroomActive
  children = [
    showroomActive.get() ? null : hit_marks,
    showroomActive.get() ? null : hud_under,
    showroomActive.get() ? null : hudObjectives,
    showroomActive.get() ? null : hudDroneOperatorMark,
    showroomActive.get() ? null : all_tips,
    showroomActive.get() ? null : hudLayout,
    network_error,
    showroomActive.get() ? null : vehicleCrosshair,
    showroomActive.get() ? null : groundVehicleCrosshair
  ]
}

let menuEventChild = @(){
  eventHandlers = {
    ["HUD.ChatInput"] = @(_event) showChatInput.modify(@(v) !v)
  }
  watch=showChatInput
  children = showChatInput.get() ? {
    hotkeys = [
      [$"Esc | {JB.B}", function() {
        chatOutMessage.set("")
        showChatInput.set(false)
        setInteractive(showChatInput.get())
      }, "Close chat"]
    ]
  } : null
}

let HudRoot = {
  size = flex()
  children = [hud, alertsUi, menusUi, inspectorRoot, menuEventChild, shootingRangeWarn]
}

return HudRoot
