from "%ui/ui_library.nut" import *
import "auth" as auth

let {sound_play} = require("%dngscripts/sound_system.nut")
let {showMsgbox} = require("%ui/components/msgbox.nut")
let urlText = require("%ui/components/urlText.nut")
let {userInfoUpdate} = require("%sqGlob/userInfoState.nut")
let {getLoginActions} = require("loginActions.nut")
let {exit_game} = require("app")
let {readPermissions, readPenalties} = require("%ui/login/permission_utils.nut")
let { remap_nick } = require("%ui/helpers/remap_nick.nut")


function onSuccess(state) {
  let authResult = state.stageResult.auth_result
  userInfoUpdate({
    userId = authResult.userId
    userIdStr = authResult.userId.tostring()
    name = authResult.name
    nameorig = (authResult?.nameorig ?? "") != "" ? authResult.nameorig : remap_nick(authResult.name)
    token = authResult.token
    tags = authResult?.tags ?? []
    permissions = readPermissions(state.stageResult?.char?.clientPermJwt, authResult.userId)
    penalties = readPenalties(state.stageResult?.char.penaltiesJwt, authResult.userId)
    penaltiesJwt = state.stageResult?.char.penaltiesJwt
    dedicatedPermJwt = state.stageResult?.char?.dedicatedPermJwt
    chardToken = state.stageResult?.char?.chard_token
    externalid = state.stageResult?.char?.externalid ?? []
  }.__update(state.userInfo))
  getLoginActions()?.onAuthComplete?.filter(@(v) type(v)=="function")?.map(@(action) action())
}

function getErrorText(state) {
  if (!(state.params?.needShowError(state) ?? true))
    return null
  if (!state.stageResult?.needShowError)
    return null
  if ((state?.status ?? auth.YU2_OK) != auth.YU2_OK)
    return "{0} {1}".subst(loc("loginFailed/authError"), loc("responseStatus/{0}".subst(state.stageResult.error), state.stageResult.error))
  if ((state.stageResult?.char?.success ?? true) != true)
    return loc($"error/{state.stageResult.char.error}")
  let errorId = state.stageResult?.error
  if (errorId != null)
    return loc(errorId)
  return null
}

function proccessUpdateError(state) {
  if (state.stageResult?.error == "InvalidVersion") {
    state.params?.afterErrorProcessed?(state)
    return true
  }
  return false
}

function showStageErrorMsgBox(errText, state, mkChildren = @(defChild) defChild) {
  let afterErrorProcessed = state.params?.afterErrorProcessed
  if (errText == null) {
    afterErrorProcessed?(state)
    return
  }

  local urlObj = null
  let linkUrl = loc($"{state.stageResult.error}/link/url", "")
  let linkText = loc($"{state.stageResult.error}/link/text", "")
  if (linkUrl != "" && linkText != "") {
    urlObj = urlText(linkText, linkUrl)
  }

  sound_play("ui_sounds/login_fail")
  let msgboxParams = {
    text = errText,
    onClose = @() afterErrorProcessed?(state),
    children = mkChildren(urlObj)
  }

  if (state.stageResult?.quitBtn ?? false) {
    msgboxParams.buttons <- [
      {
        text = loc("mainmenu/btnClose")
      },
      {
        text = loc("gamemenu/btnQuit")
        action = exit_game
        isCurrent = true
      }
    ]
  }

  showMsgbox(msgboxParams)
}

let onInterrupt = function (state) {
  if (!proccessUpdateError(state))
    showStageErrorMsgBox(getErrorText(state), state)
}

return {
  onSuccess = onSuccess
  onInterrupt = onInterrupt
  showStageErrorMsgBox = showStageErrorMsgBox
}
