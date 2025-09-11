from "%dngscripts/platform.nut" import is_sony, is_xbox
from "%ui/mainMenu/contacts/contact.nut" import updateContact
from "%ui/mainMenu/contacts/consoleUidsRemap.nut" import updateUids
from "%ui/ui_library.nut" import *

let logExt = require("%sqGlob/library_logs.nut").with_prefix("[EXT IDS MANAGER] ")
let { isSteamRunning } = require("%ui/login/login_state.nut")
let { char_request = null } = require("%ui/charClient/charClient.nut")
let userInfo = require("%sqGlob/userInfo.nut")



let EXTERNAL_TYPE_STEAM  = "s"
let EXTERNAL_TYPE_PSN    = "p"
let EXTERNAL_TYPE_XBOX   = "x"

let getExtType = @() is_sony ? EXTERNAL_TYPE_PSN
  : is_xbox ? EXTERNAL_TYPE_XBOX
  : isSteamRunning.get() ? EXTERNAL_TYPE_STEAM
  : ""

let getMyExtId = @() is_sony ? require("sony.user").accountIdString
  : is_xbox ? require("gdk.user").get_xuid().tostring()
  : isSteamRunning.get() ? require("steam").get_my_id()
  : "-1"

function setExternalId() {
  let id = getMyExtId()
  let extType = getExtType()
  if (id == "-1" || extType == "") 
    return

  char_request?("cln_set_external_id_json", { id, type = extType }, @(res) logExt("Return result of set ext id", res))
}

userInfo.subscribe(function(uInfo) {
  if (uInfo != null && uInfo.externalid.findvalue(@(res) res.t == getExtType()) == null)
    setExternalId()
})


function searchContactByExternalId(extIdsArray, callback = null) {
  if (!extIdsArray.len()) {
    callback?([])
    return
  }

  let request = {
    externalIdList = ";".join(extIdsArray)
    externalIdType = getExtType()
    maxCount = extIdsArray.len()
  }

  char_request?(
    "cln_find_users_by_external_id_list_json",
    request,
    function (result) {
      let myUserIdStr = userInfo.get()?.userIdStr ?? ""

      foreach (uidStr, data in result)
        if (uidStr != myUserIdStr && uidStr != "" && data?.nick != null)
          updateContact(uidStr, data.nick)

      callback?(result)
    }
  )
}

let searchContactByInternalId = @(userid, callback = null) char_request?(
  "ano_get_external_id",
  { userid },
  function(result) {
    if (result?.externalid.len())
      updateUids({ [result.externalid[0].i] = userid })

    callback?()
  }
)

return {
  searchContactByExternalId
  searchContactByInternalId
}