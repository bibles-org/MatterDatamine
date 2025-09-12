from "%ui/ui_library.nut" import *
from "%ui/state/clientState.nut" import gameLanguage
from "string" import endswith

import "%dngscripts/ecs.nut" as ecs

let currentAssistantSpeak = Watched(null)

let languageCutoff = {
  Russian = "/ru/"
}

ecs.register_es("assistant_speaking_check", {
    [["onInit","onChange"]] = function(_evt,_eid,comp) {
      let cutoff = languageCutoff?[gameLanguage] ?? "/en/"
      let soundName = comp.assistant__currentSoundName.replace(cutoff, "/")
      currentAssistantSpeak.set({
        currentScriptSoundLenght = comp.assistant__currentSoundLenght
        currentScriptName = soundName
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