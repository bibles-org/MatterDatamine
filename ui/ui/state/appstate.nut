import "%dngscripts/ecs.nut" as ecs
from "%ui/ui_library.nut" import *
import "net" as net

let { logerr } = require("dagor.debug")
let { SANITIZER } = require("dagor.system")
let { EventOnDisconnectedFromServer } = require("gameevents")
let { showMsgbox } = require("%ui/components/msgbox.nut")
let { setInterval, resetTimeout, clearTimer } = require("dagor.workcycle")
let { switch_to_menu_scene } = require("%sqGlob/app_control.nut")
let { get_setting_by_blk_path } = require("settings")
let { nestWatched } = require("%dngscripts/globalState.nut")
let { get_time_msec } = require("dagor.time")
let { EventGameSessionFinished, EventGameSessionStarted } = require("dasevents")

let levelLoaded = nestWatched("levelLoaded", false)
let levelIsLoading = nestWatched("levelIsLoading", false)
let levelLoadingStartedTime = nestWatched("levelLoadingStartedTime", -1)
let currentLevelBlk = nestWatched("currentLevelBlk", null)
let disableMenu = get_setting_by_blk_path("disableMenu") ?? false
let isInBattleState = nestWatched("isInBattleState", disableMenu)
let isRealBattleStarted = nestWatched("isRealBattleStarted", false)
let isCheckRequired = nestWatched("isCheckRequired", false)
let uiDisabled = Watched(false)
let dbgLoading = mkWatched(persist, "dbgLoading", false)
console_register_command(function() {dbgLoading.modify(@(v) !v)},
  "ui.loadingDbg")

const JoiningWatchdogTime = 30
let LoadingWatchdogTimeSANMap = {"address": 300_000, "thread": 1200_000}
let LoadingWatchdogTimeMs = SANITIZER in LoadingWatchdogTimeSANMap ? LoadingWatchdogTimeSANMap[SANITIZER] : 150_000

let connErrMessages = freeze({
  [net.DC_CONNECTION_CLOSED] = loc("ConnErr/CONNECTION_CLOSED"),
  [net.DC_CONNECTION_LOST] = loc("ConnErr/CONNECTION_LOST"),
  [net.DC_CONNECTION_STOPPED] = loc("ConnErr/CONNECTION_CLOSED"),
  [net.DC_CONNECTION_ATTEMPT_FAILED] = loc("ConnErr/CONNECT_FAILED"),
  [net.DC_NET_PROTO_MISMATCH] = loc("ConnErr/CONNECT_FAILED_PROTO_MISMATCH"),
  [net.DC_SERVER_FULL] = loc("ConnErr/SERVER_FULL"),
  [net.DC_KICK_GENERIC] = loc("ConnErr/WAS_KICKED_OUT"),
  [net.DC_KICK_INACTIVITY] = loc("ConnErr/KICK_AFK"),
  [net.DC_KICK_ANTICHEAT] = loc("ConnErr/KICK_EAC"),
  [net.DC_KICK_FRIENDLY_FIRE] = loc("ConnErr/KICK_KILLING_TEAMMATES"),
  [net.DC_KICK_VOTE] = loc("ConnErr/DC_KICK_VOTE"),
})

function setNotInBattle(){
  isCheckRequired.set(false)
  if (isRealBattleStarted.get())
    return
  isInBattleState.set(false)
}

if (isCheckRequired.get()){
  resetTimeout(JoiningWatchdogTime, setNotInBattle)
}

let isInBattleStateUpdate = function(v) {
  isInBattleState.set(v)
  clearMemoizeCaches()
  if (v) {
    isCheckRequired.set(true)
    resetTimeout(JoiningWatchdogTime, setNotInBattle)
  }
  else{
    isCheckRequired.set(false)
    clearTimer(setNotInBattle)
  }
  return isInBattleState
}

function loadingWatchdog(){
  log("Loading time WATCHDOG check")
  let llst = levelLoadingStartedTime.get()
  if (levelLoaded.get() || !levelIsLoading.get() || llst <=0) {
    log("Loading time WATCHDOG: game loaded!!")
    clearTimer(loadingWatchdog)
    return
  }
  if (llst + LoadingWatchdogTimeMs <= get_time_msec()) {
    logerr("Loading time: took too much time")
    clearTimer(loadingWatchdog)
    levelLoadingStartedTime.set(-1)
    defer(switch_to_menu_scene)
    isInBattleStateUpdate(false)
    showMsgbox({
      text = loc("ConnErr/UNKNOWN") 
    })

  }
}

function setLoadingWatchDog(isLoading=false) {
  log($"set loading time WATCHDOG, isLoading = {isLoading}, levelIsLoading.get() = {levelIsLoading.get()}" )
  if (isLoading) {
    log("loading time WATCHDOG: start")
    clearTimer(loadingWatchdog)
    setInterval(1, loadingWatchdog)
    if (levelLoadingStartedTime.get()<=0)
      levelLoadingStartedTime.set(get_time_msec())
  }
  else if (!isLoading) {
    log("loading time WATCHDOG: stop")
    clearTimer(loadingWatchdog)
    levelLoadingStartedTime.set(-1)
  }
}

ecs.register_es(
  "script_game_launcher_es",
  {
    [EventGameSessionFinished] = function() {
      isInBattleStateUpdate(false)
      setLoadingWatchDog(false)
      isRealBattleStarted.set(false)
    },
    [EventGameSessionStarted] = function() {
      levelIsLoading.set(true)
      setLoadingWatchDog(true)
      isInBattleStateUpdate(true)
      isRealBattleStarted.set(true)
    },
    [EventOnDisconnectedFromServer] = function onDisconnectedFromServer(evt, _eid, _comp) {
      isRealBattleStarted.set(false)
      setLoadingWatchDog(false)
      switch_to_menu_scene()
      isInBattleStateUpdate(false)

      let err_code = evt[0]
      let msgText = loc("network/disconnect_message").subst({
        err = connErrMessages?[err_code] ?? loc("ConnErr/UNKNOWN")
      })
      showMsgbox({
        text = msgText
        onClose = switch_to_menu_scene
      })
    },
  }
)

if (levelIsLoading.get()) {
  clearTimer(loadingWatchdog)
  setInterval(1, loadingWatchdog)
}

ecs.register_es("level_is_loading_ui_es",
  {
    [["onChange","onInit"]] = function(_eid, comp) {
      let isLoading = comp["level_is_loading"]
      setLoadingWatchDog(isLoading)
      levelIsLoading.set(isLoading)
    }
    onDestroy = function(...) {
      levelIsLoading.set(false)
      clearTimer(loadingWatchdog)
    }
  },
  {comps_track = [["level_is_loading", ecs.TYPE_BOOL]]}
)

ecs.register_es("level_state_ui_es",
  {
    [["onChange","onInit"]] = function(_eid, comp)  {
      let lvlLoaded = comp["level__loaded"]
      levelLoaded.set(lvlLoaded)
      if (lvlLoaded) {
        setLoadingWatchDog(false)
      }
      else {
        setLoadingWatchDog(true)
      }
    }
    onDestroy = function(...) {
      levelLoaded.set(false)
      setLoadingWatchDog(true)
    }
  },
  {comps_track = [["level__loaded", ecs.TYPE_BOOL]]}
)


ecs.register_es("level_blk_name_ui_es",
  {
    [["onInit"]] = @(_eid, comp) currentLevelBlk.set(comp["level__blk"])
    onDestroy = @() currentLevelBlk.set(null)
  },
  {comps_ro = [["level__blk", ecs.TYPE_STRING]]}
)

ecs.register_es("ui_disabled_ui_es",
  {
    [["onChange","onInit"]] = @(_eid, comp) uiDisabled.set(comp["ui__disabled"])
    onDestroy = @() uiDisabled.set(false)
  },
  {comps_track = [["ui__disabled", ecs.TYPE_BOOL]]}
)

return {
  uiDisabled
  dbgLoading
  isInBattleState
  isInBattleStateUpdate

  levelIsLoading,
  levelLoaded,
  currentLevelBlk
}