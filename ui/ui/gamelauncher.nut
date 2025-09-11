import "%ui/components/msgbox.nut" as msgbox

from "%ui/state/appState.nut" import isInBattleStateUpdate
from "app" import launch_network_session
import "statsd" as statsd

import "%dngscripts/ecs.nut" as ecs
from "%ui/ui_library.nut" import *

let { isInBattleState } = require("%ui/state/appState.nut")

let lastGame = mkWatched(persist, "lastGame", null)
let extraGameLaunchParams = mkWatched(persist, "extraGameLaunchParams", {})

let isRealBattleStarted = Watched(false)

function setNotInBattle(){
  if (isRealBattleStarted.get())
    return
  isInBattleStateUpdate(false)
}

function clearState(){
  isInBattleStateUpdate(false)
  gui_scene.clearTimer(setNotInBattle)
}

function startGame(params) {
  console_print("Launching game client...")
  params = params.__merge(extraGameLaunchParams.get())
  log("starting game with params", params.filter(@(_,k) k!="authKey" && k!="encKey" && k!="modFile"))

  if (isInBattleState.get()) {
    msgbox.showMsgbox({text=loc("msgboxtext/gameIsRunning")})
    return
  }

  isInBattleStateUpdate(true) 
  try{
    statsd.send_counter("game_launch", 1)
    lastGame.set(params)
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
