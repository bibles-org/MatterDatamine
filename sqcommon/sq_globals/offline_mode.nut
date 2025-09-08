let {get_setting_by_blk_path} = require("settings")
let {argv, dgs_get_settings} = require("dagor.system")

let app_is_offline_mode = @() argv.contains("-devMode")

if (app_is_offline_mode()) {
  let settings = dgs_get_settings()
  if (!get_setting_by_blk_path("disableRemoteNetServices")) {
    settings["disableRemoteNetServices"] <- true
  }
  settings["cryptLogs"] <- false
  if (!get_setting_by_blk_path("disableMenu"))
    settings["disableMenu"] <- true
}

let disableRemoteNetServices = app_is_offline_mode() || (get_setting_by_blk_path("disableRemoteNetServices") ?? false)
let disableMenu = app_is_offline_mode() || (get_setting_by_blk_path("disableMenu") ?? false)

println($"disableRemoteNetServices: {disableRemoteNetServices}, disableMenu: {disableMenu}, app_is_offline_mode: {app_is_offline_mode()}")

return {
  app_is_offline_mode
  disableRemoteNetServices
  disableMenu
}