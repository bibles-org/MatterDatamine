from "%ui/components/hudMarkersLayout.nut" import makeMarkersLayout
from "%ui/hud/hud_markers/item_ctor.nut" import item_ctor
from "%ui/hud/hud_markers/hud_markers_ctors.nut" import game_trigger_marker_ctors, visible_interactable_ctor
from "%ui/hud/hud_markers/action_marker_ctor.nut" import action_marker_ctors
from "%ui/hud/hud_markers/climbing_marker_ctor.nut" import climbing_markers_ctor
from "%ui/hud/hud_markers/check_weapon_marker_ctor.nut" import check_weapon_marker_ctors
from "%ui/hud/hud_markers/hunter_vision_ctor.nut" import hunter_vision_target_marker_arrow_ctors, hunter_vision_target_marker_main_ctors
from "%ui/hud/hud_markers/hunter_minion_ctor.nut" import hunter_minion_markers_ctor, hunter_minion_arrow_markers_ctor
from "%ui/ui_library.nut" import *


let { loot_markers } = require("%ui/hud/state/loot_markers.nut")

let { help_ctors } = require("%ui/hud/hud_markers/help_ctor.nut")
let { help_markers } = require("%ui/hud/state/help_markers.nut")

let { game_trigger_markers, visible_interactables, hunter_vision_targets, hunter_minions } = require("%ui/hud/state/markers.nut")

let { useObjectHintMarkers } = require("%ui/hud/state/actions_markers.nut")

let { climbingHintMarkers } = require("%ui/hud/state/climbing_hint.nut")

let { checkAmmoMarkers } = require("%ui/hud/state/check_ammo_state.nut")


let markersCtorsAndState = {
  [loot_markers] = item_ctor,
  [help_markers] = help_ctors,
  [visible_interactables] = [visible_interactable_ctor],
  [useObjectHintMarkers] = action_marker_ctors,
  [climbingHintMarkers] = climbing_markers_ctor,
  [checkAmmoMarkers] = check_weapon_marker_ctors,
  [game_trigger_markers] = game_trigger_marker_ctors,
  [hunter_vision_targets] =  [hunter_vision_target_marker_arrow_ctors, hunter_vision_target_marker_main_ctors],
  [hunter_minions] = [hunter_minion_markers_ctor, hunter_minion_arrow_markers_ctor]
}

let arrowsPadding = sh(4)

return makeMarkersLayout(markersCtorsAndState, arrowsPadding)
