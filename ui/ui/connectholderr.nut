from "%dngscripts/globalState.nut" import nestWatched
from "matching.api" import matching_logout, matching_login, get_mgates_count
from "matching.errors" import DisconnectReason, LoginResult
from "eventbus" import eventbus_send, eventbus_subscribe
from "%ui/ui_library.nut" import *



let logM = require("%sqGlob/library_logs.nut").with_prefix("[MATCHING] ")


let matchingConnectState = nestWatched("matchingConnectState", {
    connecting = false
    stopped = false
    isLoggedIn = false
    loginFailCount = 0
    reconnectAfterDisconnect = false
    disconnectReason = null
    lastLoginInfo = null
})

let getState = @() freeze(matchingConnectState.get())

let setState = function(key, value) {
  assert(key in matchingConnectState.get(), @() $"unknown {key}")
  matchingConnectState.mutate(@(v) v[key] <- value)
}

let serverResponseError = mkWatched(persist, "serverResponseError", false)

let max_relogin_retry_count = get_mgates_count()

eventbus_subscribe("matching.logged_in",
  function(...) {
    setState("isLoggedIn", true)
    eventbus_send("matching.connectHolder.ready", null)
    if (getState().stopped == true) {
      logM("matching connection was stopped during connect process")
      matching_logout()
    }
  })

eventbus_subscribe("matching.logged_out",
  function(...) {
    setState("isLoggedIn", false)
  })

function is_retriable_login_error(loginerror) {
  if (loginerror == LoginResult.NameResolveFailed ||
      loginerror == LoginResult.FailedToConnect ||
      loginerror == LoginResult.ServerBusy ||
      loginerror == LoginResult.PeersLimitReached)
    return true
  return false
}

function performConnect(login_info) {
  logM($"matching.performConnect", login_info != null, getState().loginFailCount)
  serverResponseError.set(false)
  if (getState().connecting || login_info == null) {
    return
  }
  setState("stopped", false)
  setState("connecting", true)
  matching_login(login_info)
}

function onLoginFinished(result) {
  setState("connecting", false)
  serverResponseError.set(result.status != 0)
  if (result.status == 0) {
    logM("matching login successfull")
    eventbus_send("matching.logged_in", null)
  }
  else {
    logM($"matching login failed: \"{result.status_str}\"")
    if (getState().loginFailCount < max_relogin_retry_count && !getState().stopped && is_retriable_login_error(result.status)) {
      setState("loginFailCount", getState().loginFailCount+1)
      gui_scene.setTimeout(3, @() performConnect(getState().lastLoginInfo))
    }
    else {
      if (getState().reconnectAfterDisconnect) {
        serverResponseError.set(false)
        eventbus_send("matching.logged_out", getState().disconnectReason)
      }
      else
        eventbus_send("matching.login_failed", {error = result.status_str})
    }
  }
}

eventbus_subscribe("matching.login_finished", onLoginFinished)


function deactivate_matching_login() {
  setState("stopped", true)
  if (!getState().connecting)
    matching_logout()
  setState("lastLoginInfo", null)
}

function activate_matching_login(loginInfo) {
  logM($"matching login using name {loginInfo.userName} and user_id {loginInfo.userId}")
  setState("lastLoginInfo", loginInfo)
  setState("loginFailCount", 0)
  setState("reconnectAfterDisconnect", false)
  setState("disconnectReason", null)
  performConnect(loginInfo)
}

function restore_connection(_login_info, disconnect_reason) {
  setState("loginFailCount", 0)
  setState("reconnectAfterDisconnect", true)
  setState("disconnectReason", disconnect_reason)
  performConnect(getState().lastLoginInfo)
}

eventbus_subscribe("matching.on_disconnect",
  function(disconnect_info) {
    logM("client had been disconnected from matching")
    logM(disconnect_info)

    if (getState().stopped) {
      logM("do logout")
      eventbus_send("matching.logged_out", null)
      return
    }

    local doLogout = false
    if (disconnect_info.message.len() > 0)
      doLogout = true
    else if ([
        DisconnectReason.CalledByUser, DisconnectReason.ForcedLogout,
        DisconnectReason.SecondLogin].contains(disconnect_info.reason)){
        doLogout = true
      
      
    }

    if (doLogout) {
      eventbus_send("matching.logged_out", disconnect_info)
    }
    else {
      
      if (getState().isLoggedIn && getState().lastLoginInfo) {
        gui_scene.setTimeout(3, @() restore_connection(getState().lastLoginInfo, disconnect_info))
      }
    }
  })

return freeze({
  activate_matching_login = activate_matching_login
  deactivate_matching_login = deactivate_matching_login
  is_logged_in = @() getState().isLoggedIn
  server_response_error = serverResponseError
})
