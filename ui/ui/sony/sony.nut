from "%sqGlob/app_control.nut" import switch_to_menu_scene
import "%ui/components/msgbox.nut" as msgbox
from "%ui/sony/psn_state.nut" import psn_invitation_dataUpdate, psn_game_intentUpdate, psn_was_logged_outUpdate
from "dng.sony" import check_psn_logged_in
import "%ui/sony/session.nut" as session
from "%ui/squad/squadManager.nut" import acceptSquadInvite, leaveSquadSilent
from "%ui/squad/squadAPI.nut" import requestMembership
from "eventbus" import eventbus_send, eventbus_subscribe
from "%ui/quickMatchQueue.nut" import leaveQueue
from "%ui/ui_library.nut" import *

from "%sqGlob/library_logs.nut" import with_prefix as logP
let loginState = require("%ui/login/login_state.nut")
let { psn_invitation_data, psn_was_logged_out } = require("%ui/sony/psn_state.nut")
let userInfo = require("%sqGlob/userInfo.nut")
let loginChain = require("%ui/login/login_chain.nut")
let { isInBattleState } = require("%ui/state/appState.nut")
let roomState = require("%ui/state/roomState.nut")
let { uid2console } = require("%ui/mainMenu/contacts/consoleUidsRemap.nut")
let { requestsToMeUids } = require("%ui/mainMenu/contacts/contactsWatchLists.nut")

let { open_player_profile = @(...) null, PlayerAction = null } = require("sony.social")

let JOIN_SESSION_ID = "join_session_after_sony_login"

function join_session(data) {
  let { session_id, invitation_id } = data
  session.join(session_id, invitation_id, function(squadId) {
    logP($"Trying to join squad {squadId}")
    if (squadId in requestsToMeUids.get()) {
      logP("Invitation was found, accepting")
      acceptSquadInvite(squadId.tointeger())
    }
    else {
      logP("Invitation wasn't found, requesting squad membership")
      requestMembership(squadId.tointeger())
    }
  })
}
let persistActions = persist("persistActions",@() {})
persistActions[JOIN_SESSION_ID] <- join_session


function onSessionInvitation(data) {
  logP($"got invitation to {data?.session_id}: uinfo {userInfo?.value}, lstage {loginChain?.currentStage.get()}")
  if (userInfo.get() != null) {
    if (isInBattleState.get()) {
      psn_invitation_dataUpdate(data)
      eventbus_send("ipc.onInviteAccepted", null)
    } else {
      join_session(data)
    }
  } else if (loginChain.currentStage.get() != null) {
    psn_invitation_dataUpdate(data)
  } else {
    loginChain.doAfterLoginOnce(@() persistActions[JOIN_SESSION_ID](data))
    loginChain.startLogin({})
  }
}

function onGameIntent(data) {
  logP($"got game intent {data?.action}, session {data?.sessionId}, activity {data?.activityId}")
  if (data.sessionId != "") {
    onSessionInvitation({session_id = data.sessionId, invitation_id = null})
    return
  }
  psn_game_intentUpdate(data)
  if (loginState.isLoggedIn.get() == null)
    loginChain.startLogin({})
}

function onResume(_) {
  if (loginChain.currentStage.get() != null) {
    loginChain.interrupt()
    return
  }
  loginState.logOut()
}

function do_logout() {
  loginState.logOut()
  msgbox.showMsgbox({ text = loc("yn1/disconnection/psn", { game = loc("title/name") }) })
}


eventbus_subscribe("psn.logged_in", function(result) {
  if (!result)
    do_logout()
})


function process_logout(skip_checks) {
  if (!skip_checks) {
    if (psn_was_logged_out.get()) {
      psn_was_logged_outUpdate(false)
      check_psn_logged_in()
    }
  } else {
    do_logout()
  }
}

function onLoginStateUpdate(is_signed_in) {
  if (!is_signed_in) {
    if (loginChain.currentStage.get() != null) {
      psn_was_logged_outUpdate(true)
      return
    }
    if (userInfo.get() != null)
      process_logout(true)
  }
}

loginState.isLoggedIn.subscribe(function(v) {
  if (!v) {
    if (isInBattleState.get())
      switch_to_menu_scene()
  }
})

eventbus_subscribe("dng.sony.login_state_update", onLoginStateUpdate)
eventbus_subscribe("dng.sony.resume", onResume)
eventbus_subscribe("dng.sony.game_intent", onGameIntent)

loginState.isLoggedIn.subscribe(function(v) {
  if (v)
    process_logout(false)
  else
    leaveQueue()
})

eventbus_subscribe("ipc.onBattleExitAccept", function(_) {
  defer(switch_to_menu_scene)
  leaveSquadSilent(function(...) {
    if (psn_invitation_data.get() != null) {
      join_session(psn_invitation_data.get())
      psn_invitation_dataUpdate(null)
    }
  })
})

eventbus_subscribe("matching.logged_out", function(_notify) {
  leaveQueue()
  roomState.leaveRoom(function(...){})
})

eventbus_subscribe("showPsnUserInfo", @(msg) open_player_profile(
  (uid2console.get()?[msg.userId.tostring()] ?? "-1").tointeger(),
  PlayerAction?.DISPLAY,
  "",
  {}
))

eventbus_subscribe("PSNAuthContactsReceived", function(_) {
  if (psn_invitation_data.get()) {
    join_session(psn_invitation_data.get())
    psn_invitation_dataUpdate(null)
  }
})