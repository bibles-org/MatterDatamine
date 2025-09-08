from "%ui/ui_library.nut" import *

let { nestWatched } = require("%dngscripts/globalState.nut")
let {get_local_unixtime} = require("dagor.time")
let {matching_listen_notify} = require("matching.api")
let { INVALID_USER_ID } = require("matching.errors")
let { eventbus_subscribe } = require("eventbus")

let chatLogs = nestWatched("chatLogs", {})

function clearChatState(chatId) {
  chatLogs.mutate(@(v) v.$rawdelete(chatId))
}

function addMsg(params, msg){
  let {chatId, user} = params
  let text = $"{user.name} {msg}"
  log(text)
  chatLogs.mutate(@(v) v[chatId] <- (v?[chatId] ?? [])
    .append({user = { name="", userId=INVALID_USER_ID}, timestamp = get_local_unixtime(), text})
  )
}

let chat_handlers = {
  ["chat.chat_message"] = function(params) {
    let {chatId, messages} = params
    chatLogs.mutate(@(v) v[chatId] <- [].extend(v?[chatId] ?? [], messages))
  },
  ["chat.user_joined"] = @(params) addMsg(params, "joined chat"),
  ["chat.user_leaved"] = @(params) addMsg(params, "left chat")
}

function subscribeHandlers() {
  foreach (k, v in chat_handlers) {
    matching_listen_notify(k)
    eventbus_subscribe(k, v)
  }
}

return {
  chatLogs
  clearChatState
  subscribeHandlers
}
