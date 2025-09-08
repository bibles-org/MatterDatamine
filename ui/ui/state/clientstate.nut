let { Watched } = require("frp")
let { get_app_id } = require("app")
let { getCurrentLanguage, getForceLanguage, setLanguageToSettings } = require("dagor.localize")

let appId = get_app_id()

function initForceLanguage() {
  let forceLanguage = getForceLanguage()
  if (forceLanguage != "")
    setLanguageToSettings(forceLanguage)
}
initForceLanguage()

let gameLanguage = getCurrentLanguage()
let language = Watched(gameLanguage)

return {
  appId
  gameLanguage
  language
}
