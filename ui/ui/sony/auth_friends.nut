from "%ui/ui_library.nut" import *

let { parse_json } = require("json")
let { httpRequest, HTTP_SUCCESS } = require("dagor.http")
let {get_auth_data_async} = require("dng.sony")
let {logerr} = require("dagor.debug")
let {get_circuit_conf} = require("app")
let statsd = require("statsd")
let { eventbus_subscribe_onehit } = require("eventbus")

let AUTH_FRIENDS_URL = get_circuit_conf()?.psnFriendsUrl
let AUTH_DATA_SUB_ID = "sony.auth_data_friends"



local requestNum = 0

function request_auth_contacts(game, include_unknown, callback) {
  if (!AUTH_FRIENDS_URL) {
    logerr("Invalid AUTH_FRIENDS_URL. To work with PS4 circuit needs to have psnFriendsUrl configured in network.blk")
    callback([])
    return
  }

  
  let eventId = $"{AUTH_DATA_SUB_ID}.{requestNum}"
  log($"[AuthFriends]: Send request with id: {eventId}")
  requestNum++
  function on_auth_data(auth_data) {
    if (!auth_data?.error) {
      let fmt_args = {
        code = auth_data.auth_code
        issuer = auth_data.issuer
        lang = auth_data.lang
        game = game
        unknown = include_unknown ? 1 : 0
      }
      let post_data = "code={code}&issuer={issuer}&lang={lang}&game={game}&unknown={unknown}".subst(fmt_args)
      log($"[AuthFriends]: eventId: {eventId} : POST data: {post_data}")
      let req_params = {
        method = "POST"
        url = AUTH_FRIENDS_URL
        data = post_data
        callback = function(response) {
          if (response.status != HTTP_SUCCESS || !response?.body ||
              response.http_code < 200 || response.http_code >= 300) {
            statsd.send_counter("psn_auth_friends_request_error", 1, {http_code = response.http_code})
            log($"[AuthFriends]: request failed ({response.http_code}), body {response?.body}")
            return
          }
          let response_body = response.body.as_string()
          let response_log_max_length = 1024 
          let response_log_length = response_body.len() > response_log_max_length ? response_log_max_length : response_body.len()
          log("[AuthFriends]: \n\n", response_body.slice(0, response_log_length))
          let parsed = parse_json(response_body)
          if (parsed?.status != "OK") {
            logerr("get_auth_friends failed")
            return
          }
          callback({ friends = parsed?.friends,
                     blocklist = parsed?.blocklist} )
        }
      }
      httpRequest(req_params)
    }
  }
  eventbus_subscribe_onehit(eventId, on_auth_data)
  get_auth_data_async(eventId)
}

return {
  request_auth_contacts
}
