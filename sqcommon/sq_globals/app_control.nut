import "%dngscripts/ecs.nut" as ecs


let { exit_game, switch_scene_and_update } = require("app")
let { EventGameSessionFinished } = require("dasevents")

let { dgs_get_settings } = require("dagor.system")
let menuScene = dgs_get_settings()?["scene"] ?? "content/active_matter/gamedata/scenes/player_onboarding_island.blk"
let disableMenu = dgs_get_settings()?["disableMenu"] ?? false

function switch_to_menu_scene_script() {
  if (disableMenu) {
    exit_game()
    return
  }
  ecs.g_entity_mgr.broadcastEvent(EventGameSessionFinished())
  switch_scene_and_update(menuScene)
}
return {
  switch_to_menu_scene = switch_to_menu_scene_script
}