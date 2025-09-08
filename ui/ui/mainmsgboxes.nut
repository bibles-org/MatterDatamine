from "%ui/ui_library.nut" import *

let {exit_game} = require("app")
let msgbox = require("%ui/components/msgbox.nut")
let login = require("%ui/login/login_state.nut")

function exitGameMsgBox () {
  msgbox.showMsgbox({
    text = loc("msgboxtext/exitGame")
    buttons = [
      { text = loc("Yes"), action = exit_game}
      { text = loc("No"), isCurrent = true }
    ]
  })
}
function logoutMsgBox(){
  msgbox.showMsgbox({
    text = loc("msgboxtext/logout")
    buttons = [
      { text = loc("Cancel"), isCurrent = true }
      { text = loc("Signout"), action = function() {
        login.logOut()
      }}
    ]
  })
}
return {
  exitGameMsgBox = exitGameMsgBox
  logoutMsgBox = logoutMsgBox
}
