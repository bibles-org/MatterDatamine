from "%sqGlob/library_logs.nut" import *
from "%ui/ui_library.nut" import *
let { mkLatestByTriggerStream, mkTriggerableLatestWatchedSetAndStorage, MK_COMBINED_STATE } = require("%sqstd/frp.nut")

let frameUpdateCounter = Watched(0)
gui_scene.setUpdateHandler(function sceneUpdateHandler(_dt) {
  frameUpdateCounter(frameUpdateCounter.get()+1)
})

let mkWatchedSetAndStorage = mkTriggerableLatestWatchedSetAndStorage(frameUpdateCounter)
let mkFrameIncrementObservable = mkLatestByTriggerStream(gui_scene.updateCounter)

return {
  mkWatchedSetAndStorage
  mkFrameIncrementObservable
  MK_COMBINED_STATE
}