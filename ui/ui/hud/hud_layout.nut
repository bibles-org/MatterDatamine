from "%ui/ui_library.nut" import *
import "math" as math

let {safeAreaVerPadding, safeAreaHorPadding} = require("%ui/options/safeArea.nut")
let { allDefaultActions } = require("%ui/hud/actions.nut")
let {objectivesHud} = require("%ui/hud/objectives/objectives_hud.nut")
let {chatRoot} = require("%ui/hud/menus/chat.ui.nut")
let playerBlock = require("%ui/hud/player.nut")
let { monsterUi } = require("player_info/monster_info.ui.nut")
let spectatorMode_tip = require("%ui/hud/tips/spectatorMode_tip.nut")
let {droneTip, connectionQuality, droneWeakSignalTip} = require("%ui/hud/tips/drone_tip.nut")
let playerEventsRoot = require("%ui/hud/player_events.nut")
let human_teammates = require("%ui/hud/human_teammates.nut")
let vehicleHud = require("%ui/hud/vehicle_hud.nut")
let maintenanceProgress = require("%ui/hud/maintenance_progress_hint.nut")
let hackingCorticalVaultProgress = require("%ui/hud/hacking_cortical_vault_progress_hint.nut")
let { mkQuickUsePanel, quickUseObjectiveItemSlot, quickUseDroneConsoleItem
} = require("%ui/hud/menus/components/quickUsePanel.nut")
let entity_usage = require("%ui/hud/tips/entity_usage.nut")
let { nexusHeaderBlock } = require("%ui/hud/tips/nexus_round_mode_header.nut")
let inBattleSquadNotification = require("%ui/hud/in_battle_squad_notification.nut")
let { proxyCompassStrip } = require("%ui/hud/player_info/proxy_compass_strip.nut")
let { proxyDollBlock } = require("%ui/hud/player_info/vital_proxy_info.ui.nut")

let debug_borders = mkWatched(persist, "debug_borders", false)
console_register_command(@() debug_borders.modify(@(v) !v),"ui.hud_layout_borders_debug")

let centerBottom = {
  size = [flex(), SIZE_TO_CONTENT]
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
let leftPanelMiddle = [inBattleSquadNotification, objectivesHud, vehicleHud, chatRoot, human_teammates]
let leftPanelBottom = [droneTip]
let centerPanelTop = [proxyCompassStrip, nexusHeaderBlock, spectatorMode_tip, playerEventsRoot]
let centerPanelMiddle = [droneWeakSignalTip]
let centerPanelBottom = [centerBottom]
let rightPanelTop = []
let rightPanelMiddle = []
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
      mpanel(leftPanelTop, { size =[flex(),flex(1)], padding = [sh(10), 0, 0, 0]})
      mpanel(leftPanelMiddle, { valign = ALIGN_BOTTOM size =[flex(),flex(3)]})
      mpanel(leftPanelBottom, {  valign = ALIGN_BOTTOM maxHeight = flex(1) size = [flex(),SIZE_TO_CONTENT]})
    ]
  }))
}
function centerPanel(params={}) {
  return panel (params.__merge({
    size = flex(2)
    children = [
      mpanel(centerPanelTop, {halign = ALIGN_CENTER, size = [flex(),flex(3)]})
      mpanel(centerPanelMiddle, {halign = ALIGN_CENTER, valign = ALIGN_BOTTOM, size = [flex(),flex(2)]})
      mpanel(centerPanelBottom, {halign = ALIGN_CENTER valign = ALIGN_BOTTOM, size = [flex(), flex(1)]})
    ]
  }))
}

function rightPanel(params={}) {
  return panel(params.__merge({
    size = flex(1)
    children = [
      mpanel(rightPanelTop, { size =[flex(),flex(1)] halign=ALIGN_RIGHT})
      mpanel(rightPanelMiddle, { size =[flex(),flex(2)] halign=ALIGN_RIGHT valign=ALIGN_CENTER})
      mpanel(rightPanelBottom, { size =[flex(),flex(1)] halign=ALIGN_RIGHT valign=ALIGN_BOTTOM})
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
    padding = [0,fsh(2),0,fsh(2)]
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
        leftPanel({size=[fsh(40),flex()]})
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
