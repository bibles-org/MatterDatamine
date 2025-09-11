from "%ui/components/mkQuickMenu.nut" import mkQMenu
from "%ui/hud/send_quick_chat_msg.nut" import sendQuickChatMsg
from "dasevents" import CmdHideUiMenu

from "%ui/ui_library.nut" import *
import "%dngscripts/ecs.nut" as ecs


let quickChatMessages = [
  "quickchat/letsGo"
  "quickchat/engage"
  "quickchat/evacuate"
  "quickchat/stayHere"
  "quickchat/followMe"
  "quickchat/needHelp"
  "quickchat/thanks"
  "quickchat/goodJob"
]

let showQuickChatItems = quickChatMessages.map(@(v) {
  action = @() sendQuickChatMsg(v)
  text=loc(v)
})

const QuickChatID = "quickChat"
return {
  quickChatUI = mkQMenu(@() showQuickChatItems, @() ecs.g_entity_mgr.broadcastEvent(CmdHideUiMenu({menuName = QuickChatID})), QuickChatID)
  QuickChatID
}