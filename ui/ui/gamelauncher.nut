import "%dngscripts/ecs.nut" as ecs
from "%ui/ui_library.nut" import *

let { isInBattleState, isInBattleStateUpdate } = require("%ui/state/appState.nut")
let { launch_network_session } = require("app")
let statsd = require("statsd")
let msgbox = require("%ui/components/msgbox.nut")

let lastGame = mkWatched(persist, "lastGame", null)
let extraGameLaunchParams = mkWatched(persist, "extraGameLaunchParams", {})

let isRealBattleStarted = Watched(false)

function setNotInBattle(){
  if (isRealBattleStarted.value)
    return
  isInBattleStateUpdate(false)
}

function clearState(){
  isInBattleStateUpdate(false)
  gui_scene.clearTimer(setNotInBattle)
}

function startGame(params) {
  console_print("Launching game client...")
  params = params.__merge(extraGameLaunchParams.value)
  log("starting game with params", params.filter(@(_,k) k!="authKey" && k!="encKey" && k!="modFile"))

  if (isInBattleState.value) {
    msgbox.showMsgbox({text=loc("msgboxtext/gameIsRunning")})
    return
  }

  isInBattleStateUpdate(true) 
  try{
    statsd.send_counter("game_launch", 1)
    lastGame(params)
    log("STARTING GAME WITH MOD")
    launch_network_session(params)
  }
  catch(e){
    clearState()
  }
}

return {
  startGame
  lastGame
  extraGameLaunchParams
}
