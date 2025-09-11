from "%sqGlob/offline_mode.nut" import disableRemoteNetServices
from "%dngscripts/globalState.nut" import nestWatched
from "vromfsUpdate" import get_remote_version_async
from "vromfs" import get_updated_game_version
from "eventbus" import eventbus_subscribe
from "app" import get_circuit_conf
from "settings" import get_setting_by_blk_path
import "%dngscripts/ecs.nut" as ecs
from "%ui/ui_library.nut" import *

let debug = require("%sqGlob/library_logs.nut").with_prefix("[CPTC] ")
let contentUpdater = require_optional("contentUpdater")
if (contentUpdater == null) {
  debug("Not available")
  return
}

let { Version } = require("%sqstd/version.nut")

let {
  start_updater, stop_updater, is_updater_running,
  UPDATER_EVENT_STAGE,
  UPDATER_EVENT_PROGRESS,
  UPDATER_EVENT_ERROR,
  UPDATER_EVENT_FINISH,
  UPDATER_RESULT_SUCCESS
} = contentUpdater

let { isInBattleState } = require("%ui/state/appState.nut")
let { isLoggedIn } = require("%ui/login/login_state.nut")

let isGetVersionInProgress = nestWatched("isGetVersionInProgress", false)

let remoteVromsVersion = nestWatched("remoteVromsVersion")
let remoteVromsVersionNumber = nestWatched("remoteVromsVersionNumber")
let downloadedVersion = nestWatched("downloadedVersion", Version(get_updated_game_version()).tostring())



let disableVromsAutoUpdate = get_circuit_conf()?.disableVromsAutoUpdate ?? false
let useAddonVromSrc        = get_setting_by_blk_path("debug/useAddonVromSrc") ?? false
let offlineBinaries        = get_setting_by_blk_path("debug/offlineBinaries") ?? false

let updaterEvents = {
  [UPDATER_EVENT_STAGE]    = @(_evt) null,
  [UPDATER_EVENT_PROGRESS] = @(_evt) null,
  [UPDATER_EVENT_FINISH]   = function(evt) {
    let {result, version} = evt;
    if (result == UPDATER_RESULT_SUCCESS)
      downloadedVersion.set(version)
  },
  [UPDATER_EVENT_ERROR]    = @(_evt) null,
}

const ContentUpdaterEventId = "contentUpdater.event"

eventbus_subscribe(ContentUpdaterEventId, function (evt) {
  let {eventType} = evt
  updaterEvents?[eventType](evt)
})

eventbus_subscribe("auth.get_remote_version_async", function(resp) {
  if (isInBattleState.get())
    return

  let version       = resp?.version
  let versionNumber = resp?.versionNumber

  isGetVersionInProgress.set(false)

  debug($"remote: {version} ({versionNumber}); downloaded: {downloadedVersion.get()}")

  if (versionNumber == null || version == null || downloadedVersion.get() == version)
    return

  remoteVromsVersion.set(version)
  remoteVromsVersionNumber.set(versionNumber)

  debug($"Start download a new version: {version}")
  start_updater(ContentUpdaterEventId)
})

function update() {
  if (!isLoggedIn.get() || isGetVersionInProgress.get() || is_updater_running() || isInBattleState.get())
    return

  isGetVersionInProgress.set(true)
  get_remote_version_async()
}

if (!disableVromsAutoUpdate && !offlineBinaries && !useAddonVromSrc && !disableRemoteNetServices) {
  isInBattleState.subscribe_with_nasty_disregard_of_frp_update(function(inBattle) {
    if (inBattle) {
      debug($"Stop due to the battle")
      stop_updater()
    }
    else {
      debug($"Return from the battle. Try to update the game.")
      update()
    }
  })

  ecs.register_es("content_updater_es",
    { onUpdate = @(...) update() },
    {},
    { tags="gameClient", updateInterval = 1800.0 , after="*", before="*" })
}
else
  debug($"Disable update due to disableVromsAutoUpdate = {disableVromsAutoUpdate}; offlineBinaries = {offlineBinaries}; useAddonVromSrc = {useAddonVromSrc}; disableRemoteNetServices = {disableRemoteNetServices};")

console_register_command(@() update(), "updater.start")
