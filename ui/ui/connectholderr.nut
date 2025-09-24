from "matching.errors" import LoginResult, DisconnectReason
from "matching.api" import matching_logout, matching_login, get_mgates_count
from "eventbus" import eventbus_subscribe, eventbus_send
from "%dngscripts/globalState.nut" import nestWatched
from "%ui/ui_library.nut" import *



let logM = with_prefix("[MATCHING] ")

const CONNECT_FN_ID = "matchingConnect"

enum ConnectState {
  NOT_CONNECTED = 0
  CONNECTING = 1
  CONNECTED = 2
  STOPPED = 3
}

let connState = nestWatched("matchingConnectState", ConnectState.NOT_CONNECTED)
let setConnState = @(state) connState.set(state)

let connData = nestWatched("matchingConnectData", {
  lastLoginInfo = null
  loginFailCount = 0
  disconnectInfo = null
})

let getData = @() freeze(connData.get())
let setData = @(tbl) connData.mutate(function(v) {
  foreach (key, value in tbl)
    v[key] <- value
})

let serverResponseError = mkWatched(persist, "serverResponseError", false)
let max_relogin_retry_count = get_mgates_count()

eventbus_subscribe("matching.logged_in",
  function(...) {
    if (connState.get() == ConnectState.STOPPED) {
      logM("matching connection was stopped during connect process")
      matching_logout()
      setConnState(ConnectState.NOT_CONNECTED)
      return
    }
    eventbus_send("matching.connectHolder.ready", null)
  })

let isRetriableLoginResult = @(e)
  e == LoginResult.NameResolveFailed
  || e == LoginResult.FailedToConnect
  || e == LoginResult.ServerBusy
  || e == LoginResult.PeersLimitReached

let isUserDisconnectReason = @(e)
  e == DisconnectReason.CalledByUser
  || e == DisconnectReason.ForcedLogout
  || e == DisconnectReason.SecondLogin

function performConnect(login_info) {
  logM($"matching.performConnect", login_info != null, getData().loginFailCount)
  serverResponseError.set(false)
  if (login_info == null) {
    return
  }
  matching_login(login_info)
}

function onLoginFinished(result) {
  let isSuccess = result.status == 0
  serverResponseError.set(!isSuccess)
  if (isSuccess) {
    logM("matching login successfull")
    eventbus_send("matching.logged_in", null)
    setConnState(ConnectState.CONNECTED)
    return
  }

  logM($"matching login failed: \"{result.status_str}\"")
  if (connState.get() != ConnectState.STOPPED
      && isRetriableLoginResult(result.status)
      && getData().loginFailCount < max_relogin_retry_count) {
    setData({ loginFailCount = getData().loginFailCount + 1 })
    let loginInfo = getData().lastLoginInfo
    gui_scene.resetTimeout(3, @() performConnect(loginInfo), CONNECT_FN_ID)
    setConnState(ConnectState.CONNECTING)
    return
  }

  setConnState(ConnectState.NOT_CONNECTED)
  let dcInfo = getData().disconnectInfo
  if (dcInfo != null) {
    serverResponseError.set(false)
    eventbus_send("matching.logged_out", dcInfo)
  }
  else
    eventbus_send("matching.login_failed", { error = result.status_str })
}

eventbus_subscribe("matching.login_finished", onLoginFinished)


function deactivate_matching_login() {
  if (connState != ConnectState.CONNECTING)
    matching_logout()
  setConnState(ConnectState.STOPPED)
  setData({ lastLoginInfo = null })
}

function activate_matching_login(loginInfo) {
  logM($"matching login using name {loginInfo.userName} and user_id {loginInfo.userId}")
  setData({
    lastLoginInfo = loginInfo
    loginFailCount = 0
    disconnectInfo = null 
  })
  setConnState(ConnectState.CONNECTING)
  performConnect(loginInfo)
}

eventbus_subscribe("matching.on_disconnect",
  function(disconnectInfo) {
    logM("client had been disconnected from matching")
    logM(disconnectInfo)

    if (connState.get() == ConnectState.STOPPED) {
      logM("do logout")
      eventbus_send("matching.logged_out", null)
      setConnState(ConnectState.NOT_CONNECTED)
      return
    }

    if (disconnectInfo.message.len() > 0 || isUserDisconnectReason(disconnectInfo.reason)) {
      eventbus_send("matching.logged_out", disconnectInfo)
      setConnState(ConnectState.NOT_CONNECTED)
      return
    }

    if (connState.get() == ConnectState.CONNECTED && getData().lastLoginInfo != null) {
      setData({ loginFailCount = 0, disconnectInfo })
      let loginInfo = getData().lastLoginInfo
      gui_scene.resetTimeout(3, @() performConnect(loginInfo), CONNECT_FN_ID)
      setConnState(ConnectState.CONNECTING)
      return
    }

    logM("suspicious state. No action performed.", getData().state)
  })

return {
  activate_matching_login = activate_matching_login
  deactivate_matching_login = deactivate_matching_login
  is_logged_in = @() connState.get() == ConnectState.CONNECTED
  server_response_error = serverResponseError
}
