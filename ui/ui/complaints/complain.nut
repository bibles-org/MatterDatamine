from "eventbus" import eventbus_subscribe
from "app" import get_app_id
from "%ui/ui_library.nut" import *

let { char_request = null } = require("%ui/charClient/charClient.nut")

let submitComplain = kwarg(function(userId, sessionId, complainType, user_comment, lang, appId) {
  let request = {
    appid = appId
    complainer_appid = get_app_id()
    offender_appid = appId
    offender_userid = userId
    session_id = sessionId.tostring()
    category = complainType
    user_comment
    lang
    details_json = "{\"complainId\":\"{0}\"}".subst(complainType)
  }

  char_request?(
    "cln_complaint",
    request,
    function(response) {
      log($"[COMPLAIN] on {userId}, type = {complainType}, in session {sessionId}, message = {user_comment}, lang = {lang}")
      log("[COMPLAIN] result: ", response)
    }
  )
})

eventbus_subscribe("penitentiary.complain", @(data) submitComplain(data))
