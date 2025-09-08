import "%dngscripts/ecs.nut" as ecs
from "%ui/ui_library.nut" import *

let { INVALID_USER_ID } = require("matching.errors")
let { TEAM_UNASSIGNED } = require("team")
let { blockedUids } = require("%ui/mainMenu/contacts/contactsWatchLists.nut")
let { chatId } = require("%ui/squad/squadManager.nut")
let { chatLogs } = require("%ui/mainMenu/chat/chatState.nut")
let { canInterractCrossPlatform } = require("%ui/helpers/platformUtils.nut")
let { sendMessage } = require("%ui/mainMenu/chat/chatApi.nut")
let { isInBattleState } = require("%ui/state/appState.nut")
let { find_local_player } = require("%dngscripts/common_queries.nut")
let { CmdSendChatMessage, EventChatMessage, sendNetEvent } = require("dasevents")
let {get_time_msec} = require("dagor.time")

let lines = mkWatched(persist, "lines", [])
let totalLines = mkWatched(persist, "totalLines", 0)
let logState = mkWatched(persist, "logState", [])
let outMessage = mkWatched(persist, "outMessage", "")
let sendMode = mkWatched(persist, "sendMode", "team")

let MAX_LINES = 10
let MAX_LOG_LINES = 1000
const UPDATE_DT = 0.45
const TTL = 15_000

local updateChat
updateChat = function() {
  let ctime = get_time_msec()
  let newLines = lines.get().filter(@(rec) rec.timeCreated + TTL > ctime)
  if (newLines.len() != lines.get().len())
    lines.set(newLines)
  if (newLines.len()==0)
    gui_scene.clearTimer(updateChat)
}
function startUpdateChat() {
  gui_scene.clearTimer(updateChat)
  gui_scene.setInterval(UPDATE_DT, updateChat)
}

function addChatMsg(m){
  lines.mutate(function(val) {
    val.append(m)
    if (val.len()>MAX_LINES)
      val.remove(0)
  })
  startUpdateChat()
}

function clearChat(){
  lines.set([])
  gui_scene.clearTimer(updateChat)
}

function mkMsg(sender_team, name_from, user_id_from, text, send_mode) {
  return {
    team = sender_team
    name = name_from
    userId = user_id_from
    text
    sendMode = send_mode
    timeCreated = get_time_msec()
  }
}

function pushMsg(sender_team, name_from, user_id_from, text, send_mode, qmsg) {
  if ( user_id_from in blockedUids.get()
    || (qmsg == null && name_from != "" && !canInterractCrossPlatform(name_from, false)) )
    return

  totalLines.modify(@(v) v+1)
  let rec = mkMsg(sender_team, name_from, user_id_from, text, send_mode)

  addChatMsg(rec)

  logState.mutate(function(val) {
    val.append(rec)
    if (val.len()>MAX_LOG_LINES) {
      val.remove(0)
    }
  })
}

function sendChatCmd(params = {mode="team", text=""}) {
  params = params.__merge({mode=params?.mode ?? "team"})
  let data = ecs.CompObject()
  foreach (name, val in params)
    data[name] = val
  sendNetEvent(find_local_player(), CmdSendChatMessage({data}))
}


function sendChatMessage(params){
  let {text} = params
  if (!isInBattleState.get() && chatId.get() != null) {
    sendMessage(chatId.get(), text)
  }
  else {
    sendChatCmd(params)
  }
}

function mkTextFromQchatMsg(data) {
  
  return (type(data?.qmsg) == "table")
      ? loc(data?.text ?? "", data.qmsg.__merge({item=loc(data.qmsg?.item ?? "", {count = data.qmsg?.count, nickname = data.qmsg?.nickname})}))
      : data?.text ?? ""
}

function onChatMessage(evt, _eid, _comp) {
  let data = evt?.data
  if (data==null)
    return

  let {
    qmsg = null,
    mode = "team",
    team = 0,
    name = "unknown",
    senderUserId = INVALID_USER_ID
  } = data

  let text = mkTextFromQchatMsg(data)
  pushMsg(team, name, senderUserId, text, mode, qmsg)
}

ecs.register_es("chat_client_es", {
    [EventChatMessage] = onChatMessage
  }, {comps_rq = ["player"]}
)

local starti = 0
console_register_command(function() {
  array(10).each(@(_, i) onChatMessage({data = {text = $"{starti+i}", name="generated", team=i}}, null, null))
  starti += 10
}, "chat.debug_log")

console_register_command(clearChat, "chat.clear")
const MatchingTeam = "matching_team"
function proceedMatchingMessages(messages) {
  let newLog = MAX_LOG_LINES < messages.len() ?
    messages.map(@(msg) mkMsg(MatchingTeam, msg.sender.name, msg.sender.userId, msg.text, "team")) :
    messages.slice(messages.len() - MAX_LOG_LINES, messages.len())
      .map(@(msg) mkMsg(MatchingTeam, msg?.sender.name ?? msg.user.name, msg?.sender.userId ?? msg.user.userId, msg.text, "team"))
  let newLines = MAX_LOG_LINES < messages.len() ?
    newLog :
    newLog.slice(messages.len() - MAX_LINES, newLog.len())

  lines.set(newLines)
  startUpdateChat()
  logState.set(newLog)

  totalLines.set(newLog.len())
}

chatId.subscribe(function(id) {
  if (isInBattleState.get())
    return
  proceedMatchingMessages(chatLogs.get()?[id] ?? [])
})

chatLogs.subscribe(function(v) {
  if (chatId.get() == null)
    return
  let logs = v?[chatId.get()]
  if (isInBattleState.get() || logs == null)
    return
  proceedMatchingMessages(logs)
})

return {
  chatLines = lines
  chatTotalLines = totalLines
  chatLogState = logState
  chatOutMessage = outMessage
  chatSendMode = sendMode
  sendChatCmd
  MatchingTeam

  updateChat
  pushChatMsg = pushMsg
  pushSystemMsg = @(msg) pushMsg(TEAM_UNASSIGNED, "", INVALID_USER_ID, msg, "system", null)
  sendChatMessage
}
