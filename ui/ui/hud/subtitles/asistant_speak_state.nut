from "%ui/ui_library.nut" import *

import "%dngscripts/ecs.nut" as ecs

let currentAssistantSpeak = Watched(null)

ecs.register_es("assistant_speaking_check", {
    [["onInit","onChange"]] = function(_evt,_eid,comp) {
      currentAssistantSpeak.set({
        currentScriptSoundLenght = comp.assistant__currentSoundLenght
        currentScriptName = comp.assistant__currentSoundName
      })
    }
    onDestroy = function(...) {
      currentAssistantSpeak.set({})
    }
  },
  {
    comps_track= [["assistant__currentSoundName", ecs.TYPE_STRING]],
    comps_ro = [["assistant__currentSoundLenght", ecs.TYPE_FLOAT]]
  },
  { tags="gameClient" }
)

return {
  currentAssistantSpeak
}