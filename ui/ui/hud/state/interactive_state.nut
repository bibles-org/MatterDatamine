from "%ui/ui_library.nut" import *

let interactiveElements = Watched({})

function addInteractiveElement(id) {
  if (!(id in interactiveElements.get()))
    interactiveElements.mutate(@(v) v[id] <- true)
}

function removeInteractiveElement(id) {
  if (id in interactiveElements.get())
    interactiveElements.mutate(@(v) v.$rawdelete(id))
}

function switchInteractiveElement(id) {
  interactiveElements.mutate(function(v) {
    if (id in v)
      v.$rawdelete(id)
    else
      v[id] <- true
  })
}
let freeInteractiveState = @() interactiveElements.set({})
let hudIsInteractive = Computed(@() interactiveElements.get().len() > 0)

return {
  removeInteractiveElement
  addInteractiveElement
  switchInteractiveElement
  hudIsInteractive
  freeInteractiveState
}

