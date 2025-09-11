from "%sqstd/underscore.nut" import flatten

from "string" import startswith
import "dagor.random" as random
from "settings" import get_setting_by_blk_path
from "dagor.fs" import scan_folder
from "dagor.system" import dgs_get_settings

from "%ui/ui_library.nut" import *

let localSettings = require("%ui/options/localSettings.nut")("createRoom/")

let settings = {
  minPlayers = 1
  maxPlayers = 32
  roomName = "room_{0}".subst(random.rnd_int(1, 10000))
  startOffline = false
  botsPopulation = 0
  botAutoSquad = false
  writeReplay = false
  groupSize = 1
}.map(localSettings)

let scenesFolders = []
let scenesBlk = dgs_get_settings()?["scenes"]
if (scenesBlk!=null) {
  for (local i=0; i<scenesBlk.paramCount(); i++){
    scenesFolders.append(scenesBlk.getParamValue(i))
  }
}

let useAddonVromSrc = get_setting_by_blk_path("debug/useAddonVromSrc") ?? false
let lscenes = flatten(scenesFolders
  .map(@(root) scan_folder({root, vromfs = !useAddonVromSrc, realfs = useAddonVromSrc, recursive = true, files_suffix=".blk"})
    .map(function(v){
      if (!v.contains("/scenes/") || v.contains("app_start.blk"))
        throw null
      let p = v.split("/")
      let fname = p[p.len()-1]
      if (startswith(fname, "_"))
        throw null
      return {title=fname, id=v}
     })
  )
)

settings.savedSceneId <- localSettings("", "scene")
let scenes = WatchedRo(lscenes)
let scene = Watched(scenes.get()
  .findvalue(@(s) s.id == settings.savedSceneId.get()) ?? scenes.get()?[0])

scene.subscribe_with_nasty_disregard_of_frp_update(@(s) settings.savedSceneId(s?.id ?? ""))

settings.__update({scenes, scene})
return settings
