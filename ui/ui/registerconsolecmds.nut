import "%ui/components/msgbox.nut" as msgbox

from "%ui/matchingClient.nut" import matchingCall
from "eventbus" import eventbus_send
import "%ui/checkReconnect.nut" as checkReconnect
from "matching.api" import matching_logout

from "%ui/ui_library.nut" import *

let { inspectorToggle } = require("%darg/helpers/inspector.nut")


console_register_command(@(locId) console_print($"String:{locId} is localized as:{loc(locId)}"), "ui.loc")

console_register_command(function() { msgbox.showMsgbox({ text = "Test messagebox" buttons = [{ text = "Yes" action=@()vlog("Yes")} { text = "No" action = @() vlog("no")} ]})}, "ui.test_msgbox2")
console_register_command(function() { msgbox.showMsgbox({
   text = "Test messagebox" buttons = [{ text = "Yes" action=@()vlog("yes")} { text = "No", action=@()vlog("No")} { text = "Cancel" action=@()vlog("Cancel")}]})}, "ui.test_msgbox3")
console_register_command(function() { msgbox.showMsgbox({ text = "Test messagebox"})}, "ui.test_msgbox")

console_register_command(function(key, value) {
    matchingCall("mpresence.set_presence", console_print, {[key] = value})
  },
  "mpresence.set_presence")

console_register_command(function() {
    matchingCall("mpresence.reload_contact_list", console_print)
  },
  "mpresence.reload_contact_list")

console_register_command(function() {
    matchingCall("mpresence.notify_friend_added", console_print)
  },
  "mpresence.notify_friend_added")

console_register_command(@(message, data) eventbus_send(message, data), "eventbus.send")

console_register_command(@() inspectorToggle(), "ui.inspector_enlist")

console_register_command(@() checkReconnect(), "app.check_reconnect")

console_register_command(@() matching_logout(), "matching.logout")
