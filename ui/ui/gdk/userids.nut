from "%ui/ui_library.nut" import *

let xboxUids = Watched({
  uid2xbox = {}
  xbox2uid = {}
})

let friendsUids = Watched({})

let uid2xbox = Computed(@() xboxUids.get().uid2xbox)
let xbox2uid = Computed(@() xboxUids.get().xbox2uid)


function updateUidsMapping(xbox2UidNewList) {
  let res = clone xboxUids.get()
  res.xbox2uid = res.xbox2uid.__merge(xbox2UidNewList)
  let newUid2xbox = {}
  foreach (k,v in xbox2UidNewList)
    newUid2xbox[v] <- k
  res.uid2xbox = res.uid2xbox.__merge(newUid2xbox)
  xboxUids.set(res)
}


return {
  uid2xbox
  xbox2uid
  updateUidsMapping
  friendsUids
}