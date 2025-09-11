from "%sqGlob/library_logs.nut" import with_prefix
from "%gdkLib/impl/user.nut" import register_for_user_change_event, EventType, shutdown_user
from "%ui/login/login_state.nut" import logOut, isLoggedIn
from "%ui/login/login_chain.nut" import currentStage, interrupt

let logX = with_prefix("[XBOX] ")

function on_login() {
  logX("on_login")
}

function on_logout() {
  logX("on_logout")
  shutdown_user(null)
}

isLoggedIn.subscribe(function(v) {
  if (v) {
    on_login()
  } else {
    on_logout()
  }
})

register_for_user_change_event(function(event) {
  if (event == EventType.SigningOut) {
    logX("user_change_event_handler -> SigningOut")
    if (currentStage.get()) {
      logX("Seems like user was logged out from system during login parocess. Interrupting...")
      interrupt()
      return
    }
    logOut()
  }
})