from "%ui/mainMenu/eula/eula.nut" import eulaVersion, showEula

from "%ui/ui_library.nut" import *

let { acceptedEulaVersionBeforeLogin } = require("%ui/mainMenu/eula/eula.nut")


let onlineSettings = require("%ui/options/onlineSettings.nut")
let eulaEnabled = true
function action(_login_status, cb) {
  if (!eulaEnabled) {
    log("eula check disabled")
    cb({})
    return
  }
  local acceptedVersion = onlineSettings.settings.get()?["acceptedEULA"]
  log($"eulaVersion {eulaVersion}, accepted version before login {acceptedEulaVersionBeforeLogin.get()}, current acceptedVersion: {acceptedVersion}")
  if ((acceptedEulaVersionBeforeLogin.get() ?? -1) == eulaVersion || (acceptedVersion==null && ((acceptedEulaVersionBeforeLogin.get() ?? -1) > -1)) ) {
    log("accepted current EULA version before login")
    acceptedVersion = acceptedEulaVersionBeforeLogin.get()
    onlineSettings.settings.mutate(@(value) value["acceptedEULA"] <- acceptedVersion)
  }
  if (acceptedVersion != eulaVersion) {
    showEula(function(accept) {
      log("showEula")
      if (accept) {
        onlineSettings.settings.mutate(@(value) value["acceptedEULA"] <- eulaVersion)
        cb({})
      }
      else
        cb({stop = true})
    }, acceptedVersion != null)
  }
  else {
    cb({})
  }
}

return {
  id  = "eula"
  action
}