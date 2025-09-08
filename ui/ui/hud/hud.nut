from "%ui/ui_library.nut" import *

let {inspectorRoot} = require("%darg/helpers/inspector.nut")

require("%ui/hud/state/cmd_hero_log_event.nut")
require("%ui/hud/state/gun_blocked_es.nut")

let { showChatInput } =  require("%ui/hud/menus/chat.ui.nut")
let { chatOutMessage } = require("%ui/hud/state/chat.nut")
let all_tips = require("%ui/hud/tips/all_tips.nut")
let hudLayout = require("%ui/hud/hud_layout.nut")
let network_error = require("%ui/hud/tips/network_error.nut")
let { menusUi } = require("%ui/hud/hud_menus.nut")
let hud_under = require("%ui/hud/hud_under.nut")
let hudObjectives = require("%ui/hud/hud_objectives.nut")
let hudDroneOperatorMark = require("%ui/hud/hud_drone_operator_mark.nut")
let JB = require("%ui/control/gui_buttons.nut")
let {hit_marks} = require("%ui/hud/hit_marks.nut")
let { alertsUi } = require("%ui/hud/tips/nexus_round_mode_alerts.nut")
let { shootingRangeWarn } = require("%ui/hud/state/shooting_range_state.nut")

let hud = {
  size = flex(),
  children = [
    hit_marks,
    hud_under,
    hudObjectives,
    hudDroneOperatorMark,
    all_tips,
    hudLayout,
    network_error
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
      }, "Close chat"]
    ]
  } : null
}

let HudRoot = {
  size = flex()
  children = [hud, alertsUi, menusUi, inspectorRoot, menuEventChild, shootingRangeWarn]
}

return HudRoot
