from "%ui/ui_library.nut" import *
let { get_paragraph_loc } = require("%ui/hud/menus/notes/articles/articles_common.nut")

function mkNote(id) {
  let paragraphs = [
    {t="paragraph", v=loc("notes/from/agency")}
    {t="paragraph", v=loc("notes/spacer")}
    {t="paragraph", v=loc("notes/spacer")}
  ]

  local idx = 1
  local contentLoc = get_paragraph_loc(id, idx)
  while(contentLoc != ""){
    paragraphs.append({t="paragraph", v=contentLoc})
    idx += 1
    contentLoc = get_paragraph_loc(id, idx)
  }
  return {
    id,
    title = loc($"notes/{id}/title"),
    content = [
      {t="h1" v=loc($"notes/{id}/title")}
      {t="columns", preset="two_97_3", v=[
        {t="column", v=paragraphs}
        {t="column", v=[]}
      ]}
    ],
    notificationText = loc($"notes/{id}/paragraph/1"),
    type = "agency"
  }
}


let onboarding = [
  mkNote("note_onboarding_bunker_first_visit").__update({rememberOnboardingButton = true}),
  mkNote("note_onboarding_miniraid_start"),
  mkNote("note_onboarding_miniraid_healing"),
  mkNote("note_onboarding_miniraid_body"),
  mkNote("note_onboarding_miniraid_wall"),
  mkNote("note_onboarding_miniraid_trap"),
  mkNote("note_onboarding_miniraid_am"),
  mkNote("note_onboarding_miniraid_portal"),
  mkNote("note_onboarding_contracts"),
  mkNote("note_onboarding_monolith"),
  mkNote("note_onboarding_bunker_end")
]

return {
  onboarding
}