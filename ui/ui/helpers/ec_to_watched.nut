from "%sqstd/frp.nut" import mkLatestByTriggerStream, mkTriggerableLatestWatchedSetAndStorage, MK_COMBINED_STATE

from "%sqGlob/library_logs.nut" import *
from "%ui/ui_library.nut" import *

let frameUpdateCounter = Watched(0)
gui_scene.setUpdateHandler(function sceneUpdateHandler(_dt) {
  frameUpdateCounter.set(frameUpdateCounter.get()+1)
})

let mkWatchedSetAndStorage = mkTriggerableLatestWatchedSetAndStorage(frameUpdateCounter)
let mkFrameIncrementObservable = mkLatestByTriggerStream(gui_scene.updateCounter)

return {
  mkWatchedSetAndStorage
  mkFrameIncrementObservable
  MK_COMBINED_STATE
}