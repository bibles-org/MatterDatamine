from "%ui/ui_library.nut" import *

let { is_sony, is_xbox } = require("%dngscripts/platform.nut")
let { isSteamRunning } = require("%ui/login/login_state.nut")
let { char_request = null } = require("%ui/charClient/charClient.nut")
let userInfo = require("%sqGlob/userInfo.nut")
let { updateContact } = require("%ui/mainMenu/contacts/contact.nut")
let { updateUids } = require("%ui/mainMenu/contacts/consoleUidsRemap.nut")

let logExt = require("%sqGlob/library_logs.nut").with_prefix("[EXT IDS MANAGER] ")


let EXTERNAL_TYPE_STEAM  = "s"
let EXTERNAL_TYPE_PSN    = "p"
let EXTERNAL_TYPE_XBOX   = "x"

let getExtType = @() is_sony ? EXTERNAL_TYPE_PSN
  : is_xbox ? EXTERNAL_TYPE_XBOX
  : isSteamRunning.value ? EXTERNAL_TYPE_STEAM
  : ""

let getMyExtId = @() is_sony ? require("sony.user").accountIdString
  : is_xbox ? require("gdk.user").get_xuid().tostring()
  : isSteamRunning.value ? require("steam").get_my_id()
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
      let myUserIdStr = userInfo.value?.userIdStr ?? ""

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