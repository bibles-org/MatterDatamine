from "%ui/ui_library.nut" import *

let { send, fetch, profile } = require("%sonyLib/webApi.nut")
let { pluck } = require("%sqstd/underscore.nut")
let {ceil} = require("math")
let statsd = require("statsd")
let logPSN = require("%sqGlob/library_logs.nut").with_prefix("[PSN FRIENDS] ")

let fields =  { BLOCKLIST = "blocks", FRIENDLIST = "friends" }

let parsers = {
  friendList = @(e) { accountId = e.user.accountId, nick = e.user.onlineId, online = (e.presence.onlineStatus == "online") }
  blockingUsers = @(e) { accountId = e.user.accountId }
  friends = @(e) { accountId = e, nick = null, online = false }
  blocks = @(e) { accountId = e }
}

let MAX_ACCOUNTS_IN_GET_PARAM = 100 
let CHUNK_SIZE = 100 
local pending = {}
let complete = []


function onProfilesReceived(response, _err, accounts, callback) {
  let recvd = response?.profiles ?? []
  recvd.each(function(u, i) {
    let uid = accounts[i]
    if (uid in pending)
      pending[uid].nick <- u?.onlineId
  })
  let finished = pending.filter(@(v) accounts.contains(v.accountId) && v.nick != null)
  finished.each(@(u) logPSN($"done {u.accountId} - {u.nick} - {u.online}"))
  finished.each(@(u) complete.append(u))
  pending = pending.filter(@(v) !accounts.contains(v.accountId) && v.nick == null)
  if (pending.len() == 0)
    callback(complete)
}

function onPresencesReceived(response, _err, callback) {
  let recvd = response?.basicPresences ?? []
  recvd.each(function(e) {
    let uid = e.accountId
    if (uid in pending)
      pending[uid].online <- e.onlineStatus == "online"
  })
  let accounts = pluck(recvd, "accountId")
  accounts.each(@(a, i) logPSN($"try profiles: {i} - {a}"))
  send(profile.getPublicProfiles(accounts), @(r, e) onProfilesReceived(r, e, accounts, callback))
}

local doGatherPresences = null
doGatherPresences = function(accounts, chunk_no, callback) {
  local chunk = accounts.slice(0, MAX_ACCOUNTS_IN_GET_PARAM)
  local remaining = accounts.slice(MAX_ACCOUNTS_IN_GET_PARAM)
  local on_presences_received = function(r, e) {
    onPresencesReceived(r, e, callback)
    if (remaining.len() > 0)
      doGatherPresences(remaining, chunk_no + 1, callback)
  }
  logPSN($"try presences. Chunk: {chunk_no}, Len: {chunk.len()}")
  send(profile.getBasicPresences(chunk), on_presences_received)
}

function gatherPresences(entries, callback) {
  pending.clear()
  complete.clear()
  entries.each(@(e) pending[e.accountId] <- e)
  let accounts = pending.keys()
  let accountsCount = accounts.len()
  let chunksCount = ceil(accountsCount / MAX_ACCOUNTS_IN_GET_PARAM.tofloat()).tointeger()
  logPSN($"start gathering presences: {accountsCount} / {chunksCount}")
  doGatherPresences(accounts, 1, callback)
}

function handleResponse(fieldName, response, err, callback) {
  let contactsList = response?[fieldName] ?? []
  logPSN($"start processing {fieldName} - {contactsList.len()}")
  let proceed = (fieldName != fields.BLOCKLIST && contactsList.len() != 0)
    ? @(res) gatherPresences(res, callback)
    : callback

  if (err != null) {
    statsd.send_counter("psn_service_request_error", 1, {error_code = err.code, endpoint = fieldName})
    logPSN($"Failed to get {fieldName} ({err.code}): {err?.message}")
  }
  else
    proceed(contactsList.map(parsers[fieldName]))
}

let pendingResponse = { [fields.BLOCKLIST] = [], [fields.FRIENDLIST] = [] }
function handleChunk(fieldName, response, err, callback) {
  let received = response?.nextOffset || response?.totalItemCount
  let total = response?.totalItemCount || received
  if (err == null)
    response[fieldName].each(@(e) pendingResponse[fieldName].append(e))

  logPSN($"received {fieldName} chunk: {received} items out of {total}")
  if (err != null || received >= total) {
    handleResponse(fieldName, pendingResponse, err, callback)
    pendingResponse[fieldName].clear()
  }
}

let request_psn_friends = @(cb)
  fetch(profile.listFriends(), @(r, e) handleChunk(fields.FRIENDLIST, r, e, cb), CHUNK_SIZE)

let request_blocked_users = @(cb)
  fetch(profile.listBlockedUsers(), @(r, e) handleChunk(fields.BLOCKLIST, r, e, cb), CHUNK_SIZE)

return {
  request_psn_friends
  request_blocked_users
}

