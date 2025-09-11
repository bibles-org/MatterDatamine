from "%ui/ui_library.nut" import *
from "%dngscripts/globalState.nut" import nestWatched
from "%sqstd/timers.nut" import throttle
from "%ui/state/appState.nut" import isInBattleState
from "%ui/changeLogState.nut" import changelogDisabled, haveUnseenVersions, requestPatchnotes, patchnotesReady, maxVersionInt
from "dagor.time" import get_time_msec
from "%ui/openChangelog.nut" import openChangelog
let { isOnboarding } = require("%ui/hud/state/onboarding_state.nut")

let patchnote = nestWatched("patchnote", {
  cachedUpdatedVersion = -1
  timeShown = -1
  requestMadeTime = -1
})

const MIN_SEC_BETWEEN_REQUESTS = 10 
let checkVersionAndReqPatchnotes = throttle(function(...) {
  let doNeedReqeust = !isInBattleState.get()
      && maxVersionInt.get() >= 0
      && maxVersionInt.get() > patchnote.get().cachedUpdatedVersion
  if (doNeedReqeust) {
    requestPatchnotes()
    patchnote.mutate(function(v) {
      v.cachedUpdatedVersion = maxVersionInt.get()
      v.requestMadeTime = get_time_msec()
    })
  }
}, MIN_SEC_BETWEEN_REQUESTS, {leading=true, trailing=false})
checkVersionAndReqPatchnotes()
gui_scene.setInterval(301, checkVersionAndReqPatchnotes) 
isInBattleState.subscribe_with_nasty_disregard_of_frp_update(checkVersionAndReqPatchnotes) 

let needShowPatchnote = Computed(@() patchnotesReady.get()
  && !isOnboarding.get()
  && haveUnseenVersions.get()
  && patchnote.get().timeShown != patchnote.get().requestMadeTime
)

if (!changelogDisabled)
  needShowPatchnote.subscribe_with_nasty_disregard_of_frp_update(function(v) {
    if (!v)
      return
    openChangelog()
    patchnote.mutate(@(val) val.timeShown = val.requestMadeTime)
  })
return {needShowPatchnote}