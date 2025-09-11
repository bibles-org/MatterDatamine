from "%sqGlob/offline_mode.nut" import disableRemoteNetServices

import "steam" as steam
import "%ui/login/login_cb.nut" as login_cb
import "%ui/login/login_cb_steam.nut" as login_steam_cb

from "%ui/ui_library.nut" import *


let auth_result = require("%ui/login/stages/auth_result.nut")
let char_stage = require("%ui/login/stages/char.nut")
let online_settings = require("%ui/login/stages/online_settings.nut")
let eula = require("%ui/login/stages/eula.nut")
let eula_before_login = require("%ui/login/stages/eula_before_login.nut")
let matching = require("%ui/login/stages/matching.nut")
let fake_login = require("%ui/login/stages/fake.nut")
let go_login = require("%ui/login/stages/go.nut")
let save_login = require("%ui/login/stages/save_login_data.nut")
let steam_stages = require("%ui/login/stages/steam_stages.nut")

if (disableRemoteNetServices) {
  return {
    stages = [fake_login]
    onSuccess = login_cb.onSuccess
    onInterrupt = login_cb.onInterrupt
  }
}

if (steam.is_running()) {
  return {
    stages = [eula_before_login].extend(steam_stages).append(
      auth_result
      char_stage
      online_settings
      eula
      matching
    )
    onSuccess = login_steam_cb.onSuccess
    onInterrupt = login_steam_cb.onInterrupt
  }
}

return freeze({
  stages = [
    eula_before_login
    go_login
    auth_result
    char_stage
    online_settings
    eula
    matching
    save_login
  ]
  onSuccess = login_cb.onSuccess
  onInterrupt = login_cb.onInterrupt
})
