from "%sqGlob/dasenums.nut" import PlayerSpawnControllerDefaultState, EndgameControllerState

from "%ui/panels/smartwatch_panel.nut" import mkSmartwatchUi
from "%ui/hud/menus/notes_notification.nut" import noteNotification
from "%ui/mainMenu/clonesMenu/cloneMenuState.nut" import alterRewardWindowOpened
from "%ui/hud/menus/weaponShowroom/weaponShowroom.nut" import WEAPON_SHOWROOM_MENU_ID

import "%dngscripts/ecs.nut" as ecs
from "%ui/ui_library.nut" import *

let { endgameControllerState } = require("%ui/hud/state/endgame_controller_state.nut")
let { isNexus, isNexusPlayerSpawned } = require("%ui/hud/state/nexus_mode_state.nut")
let { currentMenuId } = require("%ui/hud/hud_menus_state.nut")
let { Market_id } = require("%ui/mainMenu/marketMenu.nut")
let hideHud = require("%ui/hud/state/hide_hud.nut")
let { ClonesMenuId, AlterSelectionSubMenuId } = require("%ui/mainMenu/clonesMenu/clonesMenuCommon.nut")
let { showNewNoteTip } = require("%ui/hud/menus/notes_notification.nut")

let spawnControllState = Watched(PlayerSpawnControllerDefaultState.NONE)

ecs.register_es("spawnStateTrack",
  {
    [["onInit","onChange"]] = function(_evt, _eid, comp) {
      spawnControllState.set(comp.player_spawn_controller_default__state)
    }
  },
  {
    comps_track = [["player_spawn_controller_default__state", ecs.TYPE_INT]]
  }
)

let endgameStatesWhenShowWatch = [EndgameControllerState.NONE, EndgameControllerState.SPECTATING]

let showSmartwatch = Computed(
  @() !hideHud.get()
    && (!isNexus.get() || isNexusPlayerSpawned.get())
    && endgameStatesWhenShowWatch.contains(endgameControllerState.get())
    && (spawnControllState.get() == PlayerSpawnControllerDefaultState.NONE || spawnControllState.get() == PlayerSpawnControllerDefaultState.DONE)
    && currentMenuId.get() != Market_id
    && currentMenuId.get() != ClonesMenuId
    && currentMenuId.get() != $"{ClonesMenuId}/{AlterSelectionSubMenuId}"
    && currentMenuId.get() != WEAPON_SHOWROOM_MENU_ID
    && !alterRewardWindowOpened.get()
  )

let arrow = {
  rendObj = ROBJ_VECTOR_CANVAS
  size = static [hdpx(10), hdpx(15)]
  commands = [
    [VECTOR_WIDTH, 0],
    [VECTOR_FILL_COLOR, Color(10, 10, 10, 130)],
    [VECTOR_COLOR, Color(0, 0, 0, 0)],
    [VECTOR_POLY, 0,0, 100,0, 50,100],
  ]
}

let arrowSpace = {
  halign = ALIGN_CENTER
  size = FLEX_H
  children = arrow
}

return freeze({
  size = SIZE_TO_CONTENT
  flow = FLOW_VERTICAL
  margin = hdpx(20)
  valign = ALIGN_BOTTOM
  halign = ALIGN_CENTER
  gap = hdpx(20)
  color = Color(255, 0, 0)
  children = [
    @() {
      halign = ALIGN_CENTER
      size = FLEX_H
      watch = showNewNoteTip
      flow = FLOW_VERTICAL
      children = showNewNoteTip.get() ? [
        noteNotification
        arrowSpace
      ] : null
    }
    @() {
      watch = showSmartwatch
      size = hdpx(180)
      halign = ALIGN_CENTER
      valign = ALIGN_CENTER
      children = showSmartwatch.get() ? [
        mkSmartwatchUi()
      ] : null
    }
  ]
})
