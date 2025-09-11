from "%ui/ui_library.nut" import *

let joyAHintOverrideText = Watched(null)



let hotkeysPanelComps = {value={}}
let hotkeysPanelCompsGen = Watched(0)
let getHotkeysComps = @() hotkeysPanelComps.value ?? {}
function setHotkeysComps(comps){
  hotkeysPanelComps.value = comps
  hotkeysPanelCompsGen.modify(@(v) v+1)
}
function removeHotkeysComp(id){
  if (id not in hotkeysPanelComps.value)
    return
  hotkeysPanelComps.value.$rawdelete(id)
  hotkeysPanelCompsGen.modify(@(v) v+1)
}
function addHotkeysComp(id, comp){
  hotkeysPanelComps.value[id] <- comp
  hotkeysPanelCompsGen.modify(@(v) v+1)
}

return {
  setHotkeysComps, hotkeysPanelCompsGen, getHotkeysComps, removeHotkeysComp, addHotkeysComp, joyAHintOverrideText
}