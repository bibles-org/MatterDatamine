from "%ui/hud/menus/components/quickUsePanel.nut" import mkQuickUsePanel, quickUseObjectiveItemSlot, quickUseDroneConsoleItem

from "%ui/hud/objectives/objectives_hud.nut" import objectivesHud
from "%ui/hud/menus/chat.ui.nut" import chatRoot
import "%ui/hud/player.nut" as playerBlock
import "%ui/hud/tips/spectatorMode_tip.nut" as spectatorMode_tip
from "%ui/hud/tips/drone_tip.nut" import droneTip, connectionQuality, droneWeakSignalTip
import "%ui/hud/player_events.nut" as playerEventsRoot
import "%ui/hud/human_teammates.nut" as human_teammates
import "%ui/hud/vehicle_hud.nut" as vehicleHud
import "%ui/hud/maintenance_progress_hint.nut" as maintenanceProgress
import "%ui/hud/hacking_cortical_vault_progress_hint.nut" as hackingCorticalVaultProgress
import "%ui/hud/tips/entity_usage.nut" as entity_usage
from "%ui/hud/tips/nexus_round_mode_header.nut" import nexusHeaderBlock
from "%ui/hud/tips/nexus_wave_mode_header.nut" import nexusWaveHeaderBlock
import "%ui/hud/in_battle_squad_notification.nut" as inBattleSquadNotification
from "%ui/hud/player_info/proxy_compass_strip.nut" import proxyCompassStrip
from "%ui/hud/player_info/vital_proxy_info.ui.nut" import proxyDollBlock
from "%ui/hud/nexus_kill_log.nut" import killLogUi
from "%ui/hud/vehicle_hints.nut" import vehicleHintsBlock

from "%ui/ui_library.nut" import *
import "math" as math

let { safeAreaVerPadding, safeAreaHorPadding } = require("%ui/options/safeArea.nut")
let { allDefaultActions } = require("%ui/hud/actions.nut")
let { monsterUi } = require("%ui/hud/player_info/monster_info.ui.nut")

let debug_borders = mkWatched(persist, "debug_borders", false)
console_register_command(@() debug_borders.modify(@(v) !v),"ui.hud_layout_borders_debug")

let centerBottom = {
  size = FLEX_H
  halign = ALIGN_CENTER
  children = [
    entity_usage
    maintenanceProgress
    hackingCorticalVaultProgress
    allDefaultActions
    {
      halign = ALIGN_CENTER
      gap = hdpx(10)
      flow = FLOW_VERTICAL
      children = [
        quickUseDroneConsoleItem
        quickUseObjectiveItemSlot
        mkQuickUsePanel()
      ]
    }

  ]
  flow = FLOW_VERTICAL
  gap = hdpx(2)
}


let leftPanelTop = []
let leftPanelMiddle = [objectivesHud, vehicleHud, inBattleSquadNotification, chatRoot, human_teammates]
let leftPanelBottom = [droneTip]
let centerPanelTop = [proxyCompassStrip, nexusHeaderBlock, nexusWaveHeaderBlock, spectatorMode_tip, playerEventsRoot]
let centerPanelMiddle = [droneWeakSignalTip]
let centerPanelBottom = [centerBottom]
let rightPanelTop = [killLogUi]
let rightPanelMiddle = [vehicleHintsBlock]
let rightPanelBottom = [connectionQuality, playerBlock, proxyDollBlock, monsterUi]

let debug_borders_robj = @() debug_borders.get() ? ROBJ_FRAME: null

function debug_colors() {
  return Color(math.rand()*155/math.RAND_MAX+100, math.rand()*155/math.RAND_MAX+100, math.rand()*155/math.RAND_MAX+100)
}

function mpanel(elems, params={}) {
  return @() {
    size = flex()
    flow = FLOW_VERTICAL
    valign = ALIGN_TOP
    halign = ALIGN_LEFT
    rendObj = debug_borders_robj()
    color = debug_colors()

    gap = fsh(1)
  }.__update(params, {children=elems})
}


function panel(params={}) {
  let size = params?.size ?? flex()
  let children = params?.children ?? []
  let watch = params?.watch ?? []
  return {
    size = size
    rendObj = debug_borders_robj()
    color = debug_colors()
    flow = FLOW_VERTICAL
    padding = fsh(1)
    children = children
    watch = watch
  }
}

function leftPanel(params={}) {
  return panel (params.__merge({
    size = flex(1)
    children = [
      mpanel(leftPanelTop, { size = FLEX_H, margin = static [sh(7), 0, 0, 0] })
      mpanel(leftPanelMiddle, { valign = ALIGN_BOTTOM size = static [flex(), flex(3)] })
      mpanel(leftPanelBottom, { valign = ALIGN_BOTTOM maxHeight = flex(1) size = FLEX_H })
    ]
  }))
}
function centerPanel(params={}) {
  return panel (params.__merge({
    size = flex(2)
    children = [
      mpanel(centerPanelTop, {halign = ALIGN_CENTER, size = static [flex(),flex(3)]})
      mpanel(centerPanelMiddle, {halign = ALIGN_CENTER, valign = ALIGN_BOTTOM, size = static [flex(),flex(2)]})
      mpanel(centerPanelBottom, {halign = ALIGN_CENTER valign = ALIGN_BOTTOM, size = static [flex(), flex(1)]})
    ]
  }))
}

function rightPanel(params={}) {
  return panel(params.__merge({
    size = flex(1)
    children = [
      mpanel(rightPanelTop, { size =static [flex(),flex(1)] halign=ALIGN_RIGHT})
      mpanel(rightPanelMiddle, { size =static [flex(),flex(2)] halign=ALIGN_RIGHT valign=ALIGN_CENTER})
      mpanel(rightPanelBottom, { size =static [flex(),flex(1)] halign=ALIGN_RIGHT valign=ALIGN_BOTTOM})
    ]
  }))
}

function footer(size) {
  return {
    size = [flex(), size]
    rendObj = debug_borders_robj()
    color = debug_colors()
  }
}

function header(size) {
  return {
    size = [flex(), size]
    rendObj = debug_borders_robj()
    color = debug_colors()
    flow = FLOW_HORIZONTAL
    padding = static [0,fsh(2),0,fsh(2)]
  }
}

function HudLayout() {
  let children = [
    header(max(safeAreaVerPadding.get(), fsh(1)))
    {
      flow = FLOW_HORIZONTAL
      size = flex()
      children = [
        {size = [max(fsh(1), safeAreaHorPadding.get()),flex()]} 
        leftPanel({size=static [fsh(40),flex()]})
        centerPanel()
        rightPanel({szie=[fsh(40),flex()]})
        {size = [max(fsh(1), safeAreaHorPadding.get()),flex()]} 
      ]
    }
    footer(max(safeAreaVerPadding.get(), fsh(1)))
  ]
  let desc = {
    size = flex()
    flow = FLOW_VERTICAL
    watch = [debug_borders, safeAreaVerPadding]
    children
  }


  return desc
}

return HudLayout
