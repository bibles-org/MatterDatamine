options no_aot = true//since this is merely loader
require game.events.vehicle_events
require game.events.events_active_matter
require game.events.events_game
require game.events.player_events
require game.events.inventory_events
require game.events.music_player_events
require app
require ecs
require ECSGlobalTags
require DagorSystem

// [export_enum]
// To export enums, we must request them all here.
// In case of a changing the list of export enums,
// don't forget to call am_genDasevents.bat after.
require active_matter.game.es.game_end_reasons_common
require active_matter.game.es.human_use_object_hint_type_common
require game.es.hit_result_common
require active_matter.game.es.inventory_enums_common
require active_matter.game.es.am_encounter_workbench_enums_common
require active_matter.game.es.extraction_point.extraction_enums_common
require active_matter.game.es.endgame_enums_common
require active_matter.game.es.objectives_enums_common
require active_matter.game.es.nexus_common
require active_matter.game.es.nexus_game_end_common
require active_matter.game.es.nexus_game_start_common
require active_matter.game.es.nexus_round_mode_common
require active_matter.game.es.nexus_stats_common
require active_matter.game.es.nexus_beacon_common
require active_matter.game.es.binoculars_common
require active_matter.game.es.client.player_spawn_controller_common
require active_matter.game.es.equipment_enums_common
require active_matter.game.es.ability_enums_common


def private load_ui_events() : bool
  var ok = true
  if ecs_has_tag("ui") || is_in_aot()
    ok = load_das("%scripts/game/es/ui/ui_events.das") && ok
    ok = load_das("%scripts/game/events/music_player_events.das") && ok
  return ok


def private load_sound_events() : bool
  var ok = true
  ok = load_das("%danetlibs/sound/human_sounds/modules/human_sounds_events.das") && ok
  ok = load_das("%danetlibs/sound/human_sounds_net/modules/human_sounds_net_events.das") && ok
  ok = load_das("%danetlibs/sound/human_net_speech/modules/human_net_speech_events.das") && ok
  return ok


[init]
def load
  var ok = true
  if is_in_aot() || (get_DAGOR_DBGLEVEL() > 0 && !has_value(get_command_line_arguments(), "--das-no-linter"))
    ok = load_das("%danetlibs/dascript_base/linter.das") && ok

  if (!is_in_aot() && get_DAGOR_DBGLEVEL() > 0 && get_DAGOR_ADDRESS_SANITIZER() == 0 && get_DAGOR_THREAD_SANITIZER() == 0
      && ecs_has_tag("render") && !has_value(get_command_line_arguments(), "--das-no-debugger"))
    ok = load_das_debugger("%danetlibs/dascript_base/debugger_debug.das") && ok

  ok = load_ui_events() && ok
  ok = load_sound_events() && ok

  if is_in_aot()
    assert(ok)
