from "dagor.time" import get_time_msec
import "statsd" as statsd
import "regexp2" as regexp2
from "%ui/ui_library.nut" import *

let logLogin = require("%sqGlob/library_logs.nut").with_prefix("[LOGIN_CHAIN]")

let stagesOrder = persist("stagesOrder", @() [])
let currentStage = mkWatched(persist, "currentStage", null)
let processState = persist("processState", @() {})
let globalInterrupted = mkWatched(persist, "interrupted", false)
let afterLoginOnceActions = persist("afterLoginOnceActions", @() [])

let statsFbdRe = regexp2(@"[^[:alnum:]]")
let STEP_CB_ACTION_ID = "login_chain_step_cb"

currentStage.subscribe(@(stage) logLogin($"Login stage -> {stage}"))

let stagesConfig = {}
let isStagesInited = Watched(false)
let stages = {}
local onSuccess = null 
local onInterrupt = null 
local startLoginTs = -1
let loginTime = mkWatched(persist, "loginTime", 0)

function makeStage(stageCfg) {
  let res = {
    id = ""
    action = @(_state, cb) cb()
    actionOnReload = null
  }.__update(stageCfg)

  if (res.actionOnReload == null)
    res.actionOnReload = res.action
  return res
}
let persistActions = persist("persistActions", @() {})
function makeStageCb() {
  let curStage = currentStage.get()
  return @(result) persistActions[STEP_CB_ACTION_ID](curStage, result)
}

let reportLoginEnd = @(reportKey) statsd.send_profile("login_time", get_time_msec() - startLoginTs, {status=reportKey})

function startStage(stageName) {
  currentStage.set(stageName)
  stages[stageName].action(processState, makeStageCb())
}

function curStageActionOnReload() {
  stages[currentStage.get()].actionOnReload(processState, makeStageCb())
}

function startLogin(params) {
  assert(currentStage.get() == null)
  assert(stagesOrder.len() > 0)

  processState.clear()
  processState.params <- params
  processState.stageResult <- {}
  processState.userInfo <- "userInfo" in params ? clone params.userInfo : {}

  startLoginTs = get_time_msec()
  globalInterrupted.set(false)

  startStage(stagesOrder[0])
}

function fireAfterLoginOnceActions() {
  let actions = clone afterLoginOnceActions
  afterLoginOnceActions.clear()
  foreach(action in actions)
    action()
}

function onStageResult(result) {
  let stageName = currentStage.get()
  processState.stageResult[stageName] <- result
  if (result?.status != null)
    processState.status <- result.status

  let errorId = result?.error
  if (errorId != null) {
    processState.stageResult.error <- errorId
    statsd.send_counter("login_fail", 1, {error = statsFbdRe.replace("_", errorId),
                                          login_stage = stageName} )
    logLogin("login failed {0}: {1}".subst(stageName, errorId))
  }

  let needErrorMsg = result?.needShowError ?? true
  processState.stageResult.needShowError <- needErrorMsg
  log(processState.stageResult)

  foreach (key in ["quitBtn"])
    if (key in result)
      processState.stageResult[key] <- result[key]

  log("onInterrupt:", onInterrupt, "onSuccess", onSuccess)
  if (errorId != null || result?.stop == true || globalInterrupted.get() == true) {
    log("on error", errorId, globalInterrupted.get())
    processState.interrupted <- true
    currentStage.set(null)
    reportLoginEnd("failure")
    afterLoginOnceActions.clear()
    onInterrupt?(processState)
    return
  }

  let idx = stagesOrder.indexof(stageName)
  if (idx==null)
    return
  if (idx == stagesOrder.len() - 1) {
    loginTime.set(get_time_msec())
    currentStage.set(null)
    reportLoginEnd("success")
    onSuccess?(processState)
    fireAfterLoginOnceActions()
    return
  }

  startStage(stagesOrder[idx + 1])
}

persistActions[STEP_CB_ACTION_ID] <- function(curStage, result) {
  if (curStage == currentStage.get())
    onStageResult(result)
  else
    logLogin($"Receive cb from stage {curStage} but current is {currentStage.get()}. Ignored.")
}

function makeStages(config) {
  assert(currentStage.get() == null || stages.len() == 0)

  let prevStagesOrder = clone stagesOrder
  stagesOrder.clear()
  stages.clear()

  foreach(stage in config.stages) {
    assert(("id" in stage) && ("action" in stage), " login stage must have id and action")
    assert(!(stage.id in stages), " duplicate stage id")
    stages[stage.id] <- makeStage(stage)
    stagesOrder.append(stage.id)
  }
  isStagesInited.set(stages.len() > 0)

  onSuccess = config.onSuccess
  onInterrupt = config.onInterrupt

  if (currentStage.get() == null)
    return

  if (!isEqual(prevStagesOrder, stagesOrder)) {
    
    logLogin("Full restart")
    currentStage.set(null)
    startLogin(processState?.params ?? {})
  }
  else {
    
    logLogin($"Reload stage {currentStage.get()}")
    curStageActionOnReload()
  }
}

function setStagesConfig(config) {
  stagesConfig.__update(config)
  makeStages(config)
}

return {
  loginTime = loginTime
  currentStage = currentStage
  startLogin = startLogin
  interrupt = @() globalInterrupted.set(true)
  setStagesConfig = setStagesConfig 
  isStagesInited = isStagesInited
  doAfterLoginOnce = @(action) afterLoginOnceActions.append(action) 
}
