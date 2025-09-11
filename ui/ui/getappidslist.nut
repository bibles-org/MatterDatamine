from "app" import get_app_id

let log = require("%sqGlob/library_logs.nut").with_prefix("[APP IDS] set list ")

let appIdsList = [get_app_id()]

let setAppIdsList = function(list) {
  log(list)
  appIdsList.clear()
  appIdsList.extend(list)
}
let getAppIdsList = @() clone appIdsList

return { setAppIdsList, getAppIdsList }