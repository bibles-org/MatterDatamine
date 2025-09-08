from "%ui/ui_library.nut" import *

let loginState = require("%ui/login/login_state.nut")
let {psn_invitation_dataUpdate, psn_invitation_data, psn_game_intentUpdate, psn_was_logged_out, psn_was_logged_outUpdate } = require("%ui/sony/psn_state.nut")
let {check_psn_logged_in} = require("dng.sony")
let session = require("%ui/sony/session.nut")
let { acceptSquadInvite, leaveSquadSilent } = require("%ui/squad/squadManager.nut")
let { requestMembership } = require("%ui/squad/squadAPI.nut")
let userInfo = require("%sqGlob/userInfo.nut")
let loginChain = require("%ui/login/login_chain.nut")
let { isInBattleState } = require("%ui/state/appState.nut")
let msgbox = require("%ui/components/msgbox.nut")
let { eventbus_send, eventbus_subscribe } = require("eventbus")
let {leaveQueue} = require("%ui/quickMatchQueue.nut")
let roomState = require("%ui/state/roomState.nut")
let {switch_to_menu_scene} = require("%sqGlob/app_control.nut")
let { uid2console } = require("%ui/mainMenu/contacts/consoleUidsRemap.nut")
let { requestsToMeUids } = require("%ui/mainMenu/contacts/contactsWatchLists.nut")
let logP = require("%sqGlob/library_logs.nut").with_prefix("[PSNENV] ")

let { open_player_profile = @(...) null, PlayerAction = null
} = require("sony.social")

let JOIN_SESSION_ID = "join_session_after_sony_login"

function join_session(data) {
  let { session_id, invitation_id } = data
  session.join(session_id, invitation_id, function(squadId) {
    logP($"Trying to join squad {squadId}")
    if (squadId in requestsToMeUids.value) {
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
  logP($"got invitation to {data?.session_id}: uinfo {userInfo?.value}, lstage {loginChain?.currentStage.value}")
  if (userInfo.value != null) {
    if (isInBattleState.value) {
      psn_invitation_dataUpdate(data)
      eventbus_send("ipc.onInviteAccepted", null)
    } else {
      join_session(data)
    }
  } else if (loginChain.currentStage.value != null) {
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
  if (loginState.isLoggedIn.value == null)
    loginChain.startLogin({})
}

function onResume(_) {
  if (loginChain.currentStage.value != null) {
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
    if (psn_was_logged_out.value) {
      psn_was_logged_outUpdate(false)
      check_psn_logged_in()
    }
  } else {
    do_logout()
  }
}

function onLoginStateUpdate(is_signed_in) {
  if (!is_signed_in) {
    if (loginChain.currentStage.value != null) {
      psn_was_logged_outUpdate(true)
      return
    }
    if (userInfo.value != null)
      process_logout(true)
  }
}

loginState.isLoggedIn.subscribe(function(v) {
  if (!v) {
    if (isInBattleState.value)
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
    if (psn_invitation_data.value != null) {
      join_session(psn_invitation_data.value)
      psn_invitation_dataUpdate(null)
    }
  })
})

eventbus_subscribe("matching.logged_out", function(_notify) {
  leaveQueue()
  roomState.leaveRoom(function(...){})
})

eventbus_subscribe("showPsnUserInfo", @(msg) open_player_profile(
  (uid2console.value?[msg.userId.tostring()] ?? "-1").tointeger(),
  PlayerAction?.DISPLAY,
  "",
  {}
))

eventbus_subscribe("PSNAuthContactsReceived", function(_) {
  if (psn_invitation_data.value) {
    join_session(psn_invitation_data.value)
    psn_invitation_dataUpdate(null)
  }
})