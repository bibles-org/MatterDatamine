let comboboxSound = freeze({
  click  = "ui_sounds/combobox_click"
  hover  = "ui_sounds/combobox_highlight"
  active = "ui_sounds/combobox_action"
})

let buttonSound = freeze({
  click  = "ui_sounds/button_click"
  hover  = "ui_sounds/button_highlight"
})

let stateChangeSounds = freeze({
  hover  = "ui_sounds/combobox_highlight"
  active = "ui_sounds/combobox_action"
})

return freeze({
  buttonSound
  stateChangeSounds
  comboboxSound
})
