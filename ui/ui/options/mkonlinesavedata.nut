from "%ui/ui_library.nut" import *

let {settings} = require("%ui/options/onlineSettings.nut")

function mkOnlineSaveData(saveId, defValueFunc = @() null, validateFunc = @(v) v) {
  let watch = Computed(@() settings.get()?[saveId] ?? defValueFunc?())
  function setValue(value) {
    let v = validateFunc(value ?? defValueFunc())
    defer(@() settings.mutate(@(val) val[saveId] <- v))
  }
  return {
    watch
    setValue
  }
}

return {
  mkOnlineSaveData
}