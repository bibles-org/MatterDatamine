from "%ui/ui_library.nut" import *

let { BtnBdSelected, } = require("%ui/components/colors.nut")

let isIntersect = @(b1, b2) !(b1.l >= b2.r || b2.l >= b1.r || b1.t >= b2.b || b2.t >= b1.b)

function mkSizeTable(box, content) {
  let { l, r, t, b } = box
  return {
    size = [r-l, b-t]
    pos = [l, t]
  }.__update(content)
}

let lightCtor = @(box) mkSizeTable(box, {
  rendObj = ROBJ_BOX
  borderWidth = hdpx(1)
  borderColor = BtnBdSelected
})

let darkCtor = @(box) mkSizeTable(box, {
  rendObj = ROBJ_SOLID
  color = Color(0,0,0, 192)
})

function cutBlock(block, cutter) {
  if (!isIntersect(block, cutter))
    return [block]

  let res = []
  if (block.l < cutter.l)
    res.append({ l = block.l, t = block.t, r = cutter.l, b = block.b})
  if (block.r > cutter.r)
    res.append({ l = cutter.r, t = block.t, r = block.r, b = block.b })

  let l = max(cutter.l, block.l)
  let r = min(cutter.r, block.r)
  if (block.t < cutter.t)
    res.append({ l, r, t = block.t, b = cutter.t })
  if (block.b > cutter.b)
    res.append({ l, r, t = cutter.b, b = block.b })

  return res
}

let wndAnimationParams = [
  { prop=AnimProp.opacity, from=0, to=1, duration=0.2, play=true, easing=OutBack}
  { prop=AnimProp.opacity, from=1, to=0, duration=0.2, playFadeOut=true}
]

function createHighlight(boxes) {
  local darkBlocks = [{ l = 0, t = 0, r = sw(100), b = sh(100) }]
  let lightBlocks = []

  foreach (box in boxes) {
    if ("l" not in box)
      continue
    lightBlocks.append(box)
    let cutted = []
    darkBlocks.each(@(block) cutted.extend(cutBlock(block, box)))
    darkBlocks = cutted
  }

  return darkBlocks.map(darkCtor)
    .extend(lightBlocks.map(lightCtor))
}

function getBox(keys) {
  let kType = type(keys)
  if (kType == "function")
    return getBox(keys())

  if (kType == "array") {
    local res = null
    foreach (key in keys) {
      let aabb = gui_scene.getCompAABBbyKey(key)
      if (aabb == null)
        continue
      if (res == null) {
        res = aabb
        continue
      }
      res.l = min(res.l, aabb.l)
      res.r = max(res.r, aabb.r)
      res.t = min(res.t, aabb.t)
      res.b = max(res.b, aabb.b)
    }
    return res
  }

  return gui_scene.getCompAABBbyKey(keys)
}

function mkLightBox(boxes) {
  let boxesToUse = []
  foreach (box in boxes) {
    if ("l" in box) {
      boxesToUse.append(box)
      continue
    }
    let boxData = getBox(box)
    if ("l" in boxData)
      boxesToUse.append(boxData)
  }
  return {
    size = flex()
    transform = {}
    animations = wndAnimationParams
    children = createHighlight(boxesToUse)
  }
}

return {
  mkLightBox
}
