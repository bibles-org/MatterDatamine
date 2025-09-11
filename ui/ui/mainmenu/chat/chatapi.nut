from "%ui/matchingClient.nut" import matchingCall

from "%ui/ui_library.nut" import *


function createChat(cb = null) {
  matchingCall("chat.create_chat", cb)
}

function joinChat(chatId, chatKey, cb = null) {
  matchingCall("chat.join_chat", cb, { chatId, chatKey })
}

function leaveChat(chatId, cb = null) {
  matchingCall("chat.leave_chat", cb, { chatId })
}

function sendMessage(chatId, text, cb = null) {
  matchingCall("chat.send_chat_message", cb, { chatId, message = { text } })
}

return {
  createChat
  joinChat
  leaveChat
  sendMessage
}
