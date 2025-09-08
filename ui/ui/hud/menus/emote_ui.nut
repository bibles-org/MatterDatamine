import "%dngscripts/ecs.nut" as ecs
from "%ui/ui_library.nut" import *

let {mkQMenu} = require("%ui/components/mkQuickMenu.nut")
let {get_controlled_hero} = require("%dngscripts/common_queries.nut")
let {CmdRequestUseEmote, sendNetEvent, CmdHideUiMenu, CmdShowUiMenu} = require("dasevents")

let emoteConfig = Watched([])

ecs.register_es("init_emote_config_ui_es",
  {
    [["onInit"]] = function(_evt, _eid, comp) {
      emoteConfig.set(comp.human_sec_anim__config.getAll().map(@(v) v?.a2d ?? "ERROR"))
    }
    onDestroy = @(...) emoteConfig.set([])
  },
  {
    comps_ro=[["human_sec_anim__config", ecs.TYPE_SHARED_ARRAY]],
    comps_rq=["hero"]
  },
  {tags="gameClient"}
)

let requestUseEmote = @(idx) sendNetEvent(get_controlled_hero(), CmdRequestUseEmote({emoteId=idx}))

let mkPieMenuItem = @(v, idx) {
  action = @() requestUseEmote(idx)
  text=loc(v.slice("*gesture_".len()))
}

let getPieMenuItems = @() emoteConfig.get().map(mkPieMenuItem)
const EmotesUiId = "EmotesUI"

let closeEmoteUi = @() ecs.g_entity_mgr.broadcastEvent(CmdHideUiMenu({menuName = EmotesUiId}))
let openEmotesUi = @() ecs.g_entity_mgr.broadcastEvent(CmdShowUiMenu({menuName = EmotesUiId}))

let emoteUI = mkQMenu(getPieMenuItems, closeEmoteUi, EmotesUiId, loc("emotions/title"))

return {
  emoteUI
  EmotesUiId
  closeEmoteUi
  openEmotesUi
}