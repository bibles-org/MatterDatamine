from "dasevents" import CmdSendChatMessage, sendNetEvent

import "%dngscripts/ecs.nut" as ecs
from "%ui/ui_library.nut" import *

let { find_local_player } = require("%dngscripts/common_queries.nut")

function sendChatMsg(params) {
  let data = ecs.CompObject()
  foreach (name, val in params)
    data[name] = val
  sendNetEvent(find_local_player(), CmdSendChatMessage({data}))
}

function sendQuickChatSoundMsg(text, qmsg = null, sound = null) {
  sendChatMsg({mode = "qteam", text = text, qmsg = qmsg, sound = sound})
}

function sendQuickChatItemMsg(text, item_name=null) {
  sendChatMsg({mode="qteam", text = text, qmsg={item=item_name}})
}

function sendItemHint(item_name, item_eid, item_count, item_owner_nickname) {
  sendChatMsg({mode="qteam", text= "squad/item_hint", qmsg={item=item_name, count = item_count, nickname = item_owner_nickname}, eid = item_eid})
}

return {
  sendQuickChatSoundMsg
  sendQuickChatMsg = sendQuickChatItemMsg
  sendQuickChatItemMsg = sendQuickChatItemMsg
  sendItemHint = sendItemHint
}