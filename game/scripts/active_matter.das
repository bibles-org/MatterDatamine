options no_aot = true
require ecs
require ecs.fs
require app
require ECSGlobalTags
require DagorSystem

require %scripts/dng_libs_init


def private load_sound() : bool
  var ok = true

  if ecs_has_tag("sound") || is_in_aot()
    ok = load_folder("%scripts/game/es/sound") && ok
    ok = load_folder("%scripts/game/es/sound/vehicle") && ok
    ok = load_folder("%scripts/game/es/sound/extraction_point") && ok

  if ecs_has_tag("soundNet") || is_in_aot()
    ok = load_folder("%scripts/game/es/sound_net") && ok

  return ok


def private load_render() : bool
  var ok = true
  if ecs_has_tag("render") || is_in_aot()
    ok = load_folder("%scripts/game/es/render") && ok
    ok = load_folder("%scripts/game/es/render/motion_matching") && ok
    ok = load_folder("%scripts/game/es/render/extraction_point") && ok
  return ok


def private load_input() : bool
  var ok = true
  if ecs_has_tag("input") || is_in_aot()
    ok = load_folder("%scripts/game/es/input") && ok
  return ok


def private load_imgui() : bool
  var ok = true
  if typeinfo builtin_module_exists(DagorImgui) || is_in_aot()
    ok = load_folder("%scripts/game/es/imgui") && ok

  if (typeinfo builtin_module_exists(DagorImgui) && typeinfo builtin_module_exists(DagorEditor)) || is_in_aot()
    ok = load_folder("%scripts/game/es/imgui/daEditor") && ok
  return ok



def private load_ui() : bool
  var ok = true
  if ecs_has_tag("ui") || is_in_aot()
    ok = load_folder("%scripts/game/es/ui") && ok
  return ok



def private load_client() : bool
  var ok = true
  if ecs_has_tag("input") || is_in_aot() // check input as real game client tag, netClient is unset on game start
    ok = load_folder("%scripts/game/es/client") && ok
    ok = load_folder("%scripts/game/es/player/client") && ok
    ok = load_folder("%scripts/game/es/client/extraction_point") && ok
  return ok



def private load_dedicated() : bool
  var ok = true
  if (ecs_has_tag("server") && !ecs_has_tag("gameClient")) || is_in_aot()
    ok = load_folder("%scripts/game/es/dedicated") && ok
  return ok


def private load_daEditor() : bool
  var ok = true
  if typeinfo builtin_module_exists(DagorEditor) || is_in_aot()
    ok = load_folder("%scripts/game/es/daEditor") && ok
  return ok


def private load_replay() : bool
  var ok = true
  if ecs_has_tag("input") || is_in_aot()
    ok = load_folder("%scripts/game/es/replay") && ok
  return true


[init]
def load
  var ok = true

  if ecs_has_tag("dasWebui") || is_in_aot()
    load_optional_folder("%dngdas/remote/es")
    if typeinfo builtin_module_exists(DngWalkerai)
      load_optional_folder("%dngdas/remote/es/ai")
  load_optional_folder("%dngdas/debug/es")

  ok = load_folder("%scripts/game/es/effects") && ok
  ok = load_folder("%scripts/game/es/extraction_point") && ok
  ok = load_folder("%scripts/game/es/damage_systems") && ok
  ok = load_folder("%scripts/game/es/human") && ok
  ok = load_folder("%scripts/game/es/locks") && ok
  ok = load_folder("%scripts/game/es/flashlights") && ok
  ok = load_folder("%scripts/game/es/vehicle") && ok
  ok = load_folder("%scripts/game/es/player") && ok
  ok = load_folder("%scripts/game/es") && ok
  ok = load_folder("%scripts/game/es/ai") && ok
  ok = load_folder("%scripts/game/es/anomalies") && ok
  ok = load_folder("%scripts/game/es/abilities") && ok
  ok = load_folder("%scripts/game/es/objectives") && ok
  ok = load_folder("%scripts/game/es/weapon") && ok
  ok = load_folder("%scripts/game/es/triggers") && ok

  ok = load_sound() && ok
  ok = load_render() && ok
  ok = load_input() && ok
  ok = load_imgui() && ok
  ok = load_ui() && ok
  ok = load_client() && ok
  ok = load_dedicated() && ok
  ok = load_daEditor() && ok
  ok = load_replay() && ok

  ok = load_dng_libs() && ok

  if is_in_aot()
    assert(ok)
