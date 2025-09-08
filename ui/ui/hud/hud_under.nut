from "%ui/ui_library.nut" import *

let {makeMarkersLayout} = require("%ui/components/hudMarkersLayout.nut")

let {loot_markers} = require("%ui/hud/state/loot_markers.nut")
let {item_ctor} = require("%ui/hud/hud_markers/item_ctor.nut")

let {help_ctors} = require("%ui/hud/hud_markers/help_ctor.nut")
let {help_markers} = require("%ui/hud/state/help_markers.nut")

let {game_trigger_markers, visible_interactables, hunter_vision_targets, hunter_minions} = require("state/markers.nut")
let {game_trigger_marker_ctors, visible_interactable_ctor} = require("hud_markers/hud_markers_ctors.nut")

let {useObjectHintMarkers} = require("state/actions_markers.nut")
let {action_marker_ctors} = require("hud_markers/action_marker_ctor.nut")

let {climbingHintMarkers} = require("state/climbing_hint.nut")
let {climbing_markers_ctor} = require("hud_markers/climbing_marker_ctor.nut")

let { checkAmmoMarkers } = require("%ui/hud/state/check_ammo_state.nut")
let { check_weapon_marker_ctors } = require("hud_markers/check_weapon_marker_ctor.nut")

let { hunter_vision_target_marker_arrow_ctors, hunter_vision_target_marker_main_ctors} = require("hud_markers/hunter_vision_ctor.nut")
let { hunter_minion_markers_ctor, hunter_minion_arrow_markers_ctor } = require("hud_markers/hunter_minion_ctor.nut")

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
