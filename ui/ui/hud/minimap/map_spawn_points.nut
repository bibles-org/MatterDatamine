from "%ui/ui_library.nut" import *

from "%ui/hud/minimap/map_state.nut" import currentMapVisibleRadius
from "math" import PI, sin, cos, min, tan, abs, sqrt, atan2
let minimapHoverableMarker = require("minimap_hover_hint.nut")
let { Point2, Point3 } = require("dagor.math")
let { TextNormal } = require("%ui/components/colors.nut")
let { setTooltip, getTooltip } = require("%ui/components/cursors.nut")
let { lerp } = require("%sqstd/math.nut")


let spawnPoint = function(data, transform){
  let pos = data.transform.getcol(3)

  let spawnIcon = @(sf) {
    rendObj = ROBJ_IMAGE
    image = Picture($"ui/skin#white_circle.svg:{hdpxi(20)}:{hdpxi(20)}:P")
    color = Color(50,50,50,255)
    size = [hdpxi(20), hdpxi(20)]
    children = @(){
      watch = sf
      rendObj = ROBJ_IMAGE
      hplace = ALIGN_CENTER
      vplace = ALIGN_CENTER
      image = Picture($"ui/skin#antenna.svg:{hdpxi(16)}:{hdpxi(16)}:P")
      color = sf.get() & S_HOVER ? Color(255, 255, 0) : Color(255, 255, 255)
      size = [hdpxi(16), hdpxi(16)]
    }
  }
  return minimapHoverableMarker(
    { worldPos = pos, clampToBorder = false },
    transform,
    loc("hint/spawnPointMinimapMarker"),
    spawnIcon
  )
}

let mkSpawnPoints = function(spawns, transform) {
  return spawns.map(@(data) spawnPoint(data, transform))
}


function cross(o, a, b) {
  return (a.x - o.x) * (b.y - o.y) - (a.y - o.y) * (b.x - o.x)
}

function project(p) {
  return Point2(p.x, p.z)
}

function circumcircle(A, B, C) {
  let D = 2 * (A.x * (B.y - C.y) + B.x * (C.y - A.y) + C.x * (A.y - B.y))
  if (D == 0) return null

  let Ux = (A.x * A.x + A.y * A.y) * (B.y - C.y) + (B.x * B.x + B.y * B.y) * (C.y - A.y) + (C.x * C.x + C.y * C.y) * (A.y - B.y)
  let Uy = (A.x * A.x + A.y * A.y) * (C.x - B.x) + (B.x * B.x + B.y * B.y) * (A.x - C.x) + (C.x * C.x + C.y * C.y) * (B.x - A.x)

  let center = Point2(Ux / D, Uy / D)
  let radius = sqrt((A.x - center.x) * (A.x - center.x) + (A.y - center.y) * (A.y - center.y))

  return { center, radius }
}

function inCircle(p, circle) {
  let dx = p.x - circle.center.x
  let dy = p.y - circle.center.y
  return dx * dx + dy * dy <= circle.radius * circle.radius
}

function delaunayTriangulation(points) {
  let triangles = []

  let extendedPoints = [].extend(points, [Point2(-1000000, -1000000), Point2(1000000, -1000000), Point2(0, 1000000)])
  let superTriangle = {
    idencies = [
      extendedPoints.len() - 3,
      extendedPoints.len() - 2,
      extendedPoints.len() - 1
    ]
  }
  triangles.append(superTriangle)

  foreach (idx, p in points) {
    let edges = []
    for (local i = triangles.len() - 1; i >= 0; i--) {
      let t = triangles[i]
      let ids = t.idencies
      if (t?.circle == null) {
        t.circle <- circumcircle(extendedPoints[ids[0]], extendedPoints[ids[1]], extendedPoints[ids[2]])
      }
      if (t?.circle && inCircle(p, t.circle)) {
        edges.append([ids[0], ids[1]])
        edges.append([ids[1], ids[2]])
        edges.append([ids[2], ids[0]])
        triangles.remove(i)
      }
    }

    local sharedEdges = []
    for (local i = edges.len() - 1; i >= 0; i--) {
      for (local j = i - 1; j >= 0; j--) {
        if ((edges[i][0] == edges[j][1] && edges[i][1] == edges[j][0]) ||
            (edges[i][0] == edges[j][0] && edges[i][1] == edges[j][1])) {
          sharedEdges.append(i)
          sharedEdges.append(j)
          break
        }
      }
    }

    sharedEdges = sharedEdges
      .sort(@(a, b) b <=> a)

    foreach (edge in sharedEdges) {
      edges.remove(edge)
    }

    foreach (e in edges) {
      triangles.append({ idencies = [e[0], e[1], idx] })
    }
  }

  
  for (local i = triangles.len() - 1; i >= 0; i--){
    let t = triangles[i]
    let ids = t.idencies
    if (ids[0] >= points.len() || ids[1] >= points.len() || ids[2] >= points.len()) {
      triangles.remove(i)
    }
  }

  foreach(t in triangles) {
    if (t?.circle == null) {
      t.circle <- circumcircle(points[t.idencies[0]], points[t.idencies[1]], points[t.idencies[2]])
    }
  }

  return triangles
}

function addEdge(edges, a, b) {
  foreach (edge in edges) {
    if ((edge?[0] == a && edge?[1] == b) || (edge?[0] == b && edge?[1] == a)) {
      edge.clear() 
      return
    }
  }
  edges.append([a, b])
}

function alphaComplex(points, triangles, alpha) {
  local edges = []
  foreach (t in triangles) {
    if (t.circle.radius < alpha) {
      addEdge(edges, t.idencies[0], t.idencies[1])
      addEdge(edges, t.idencies[1], t.idencies[2])
      addEdge(edges, t.idencies[2], t.idencies[0])
    }
  }

  edges = edges.filter(@(edge) edge.len() > 0)

  
  if (edges.len() == 0)
    return []

  let poly = [edges[0][0], edges[0][1]]
  edges.remove(0)

  while (edges.len() > 0) {
    local found = false
    for (local i = 0; i < edges.len(); i++) {
      let edge = edges[i]
      if (poly[poly.len() - 1] == edge[0]) {
        poly.append(edge[1])
        edges.remove(i)
        found = true
        break
      } else if (poly[poly.len() - 1] == edge[1]) {
        poly.append(edge[0])
        edges.remove(i)
        found = true
        break
      }
    }
    if (!found) break
  }
  poly.pop()
  return poly.map(@(idx) points[idx])
}


function chaikinSmoothing(points){
  let newPoints = []
  for (local i = 0; i < points.len(); i++) {
    let p0 = points[i]
    let p1 = points[(i + 1) % points.len()]
    let q = Point2(3.0/4.0 * p0.x + 1.0/4.0 * p1.x, 3.0/4.0 * p0.y + 1.0/4.0 * p1.y)
    let r = Point2(1.0/4.0 * p0.x + 3.0/4.0 * p1.x, 1.0/4.0 * p0.y + 3.0/4.0 * p1.y)
    newPoints.append(q, r)
  }
  return newPoints
}




function pointInPolygon(p, poly) {
  let n = poly.len()
  local count = 0

  for (local i = 0; i < n; i++) {
    let j = (i + 1) % n
    let p0 = poly[i]
    let p1 = poly[j]

    if (p0.y <= p.y) {
      if (p1.y > p.y && cross(p, p0, p1) > 0)
        count++
    } else {
      if (p1.y <= p.y && cross(p, p0, p1) < 0)
        count--
    }
  }
  return count != 0
}

function point2Polar(p) {
  let r = sqrt(p.x * p.x + p.y * p.y)
  let theta = atan2(p.y, p.x)
  return { r, theta }
}

function polar2Point(r, theta) {
  return Point2(r * cos(theta), r * sin(theta))
}

let hoverTextPoly = @(locId){
  size = SIZE_TO_CONTENT
  transform = { translate = [0, -sh(4.0)] }
  rendObj = ROBJ_BOX
  fillColor = Color(40, 40, 40, 150)
  zOrder = Layers.Upper
  key = locId
  flow = FLOW_VERTICAL
  halign = ALIGN_CENTER
  children = {
    padding = [hdpx(1), hdpx(2), hdpx(1), hdpx(2)]
    rendObj = ROBJ_TEXT
    text = loc(locId, loc("hint/spawnPolygoneMinimapMarker"))
    fontSize = hdpx(15)
    color = Color(255, 255, 255)
    fontFx = FFT_GLOW
    fontFxColor = Color(30, 30, 10)
    fontFxFactor = 12
  }
}

function clampToZone(points, zoneInfo, clampParam){
  let minRad = clampParam.x
  let maxRad = clampParam.y

  return points.map(function(p) {
    if (!zoneInfo)
      return p
    let center = Point2(zoneInfo.sourcePos.x, zoneInfo.sourcePos.z)
    let {r, theta} = point2Polar(p - center)
    local newR = r
    if (zoneInfo.radius - r < minRad)
      newR = zoneInfo.radius
    else if (zoneInfo.radius - r < maxRad)
      newR = lerp(zoneInfo.radius - minRad, zoneInfo.radius - maxRad, zoneInfo.radius, r, r)
    return polar2Point(newR, theta) + center
  })
}

function mkSpawnsPoly(spawns, locId, zoneInfo, alpha, radius, map_size, clampParam, transform) {
  let N = 4
  let points = spawns
    .map(@(spawn) project(spawn.transform.getcol(3)))
    .reduce(function(acc, p) { 
      for (local i = 0; i < N; i++) {
        let angle = 2 * PI / N * i
        let r = radius * (1 + (0.1 / N) * i ) 
        acc.append(Point2(p.x + r * cos(angle), p.y + r * sin(angle)))
      }
      return acc
    }, [])
    .map(function(p) { 
      if (!zoneInfo)
        return p
      let center = Point2(zoneInfo.sourcePos.x, zoneInfo.sourcePos.z)
      let {r, theta} = point2Polar(p - center)
      return polar2Point(min(r, zoneInfo.radius), theta) + center
    })
    .reduce(function(acc, p){ 
      foreach(a in acc){
        if (p.x == a.x && p.y == a.y)
          return acc
      }
      acc.append(p)
      return acc
    }, [])

  let triangles = delaunayTriangulation(points)
  local poly = alphaComplex(points, triangles, alpha)

  poly = chaikinSmoothing(poly)
  poly = clampToZone(poly, zoneInfo, clampParam)
  poly = chaikinSmoothing(poly)

  let [lt, rb] = poly.reduce(@(acc, p) [
    Point2(min(acc[0].x, p.x), min(acc[0].y, p.y)),
    Point2(max(acc[1].x, p.x), max(acc[1].y, p.y))
  ], [Point2(100000, 100000), Point2(-100000, -100000)])
  let center = Point2((lt.x + rb.x) / 2.0, (lt.y + rb.y) / 2.0)

  let mouseInPoly = Watched(false)

  let sf = Watched(0)

  return function() {
    let visibleRadius = currentMapVisibleRadius.get()
    let polygonSize = [(rb.x - lt.x) / visibleRadius * map_size[0] * 0.5, (rb.y - lt.y) / visibleRadius * map_size[1] * 0.5]

    let relativePoints = poly.map(function(p) {
      let point = Point2(p.x - center.x, p.y - center.y)
      
      
      return Point2(50.0 + point.x / (rb.x - lt.x) * 100.0, 50.0 - point.y / (rb.y - lt.y) * 100.0)
    })

    function onMouseMove(mouseEvent) {
      let point = Point2(mouseEvent.screenX, mouseEvent.screenY)
      let {l, t, r, b} = mouseEvent.targetRect
      if (r - l == 0 || b - t == 0)
        return

      let relativePoint = Point2(
        (point.x - l) / (r - l) * 100.0,
        (point.y - t) / (b - t) * 100.0
      )
      let hit = pointInPolygon(relativePoint, relativePoints)
      let hovered = sf.get() & S_HOVER
      mouseInPoly.set(hovered && hit)
    }

    let commands = [[VECTOR_POLY]]
    foreach (p in relativePoints)
      commands.top().append(p.x, p.y)

    if ((sf.get() & S_HOVER) && mouseInPoly.get())
      setTooltip(hoverTextPoly(locId))
    else if (getTooltip()?.key == locId)
      setTooltip(null)

    return {
      watch = [currentMapVisibleRadius, mouseInPoly, sf]
      data = {
        worldPos = Point3(center.x, 0, center.y),
        clampToBorder = false
      }
      behavior = Behaviors.TrackMouse
      onMouseMove
      onElemState = @(state) sf.set(state)
      eventPassThrough = true
      size = polygonSize
      transform
      color = mul_color(TextNormal, (sf.get() & S_HOVER) && mouseInPoly.get() ? 0.7 : 0.3)
      fillColor = mul_color(TextNormal, (sf.get() & S_HOVER) && mouseInPoly.get() ? 0.2 : 0.1)
      rendObj = ROBJ_VECTOR_CANVAS
      commands
      valign = ALIGN_CENTER
      halign = ALIGN_CENTER
    }
  }
}

function mkSpawns(spawns, zoneInfo, raidDesc, map_size, transform) {
  let allSpawns = spawns.reduce(@(acc, s) acc.extend(s.spawns), [])

  let children = []
  if (raidDesc?.drawSpawnsAsPoly){
    children.extend(
      spawns.map(
        function(s) {
          let alpha = raidDesc?.drawSpawnsAlpha ?? 100
          let radius = raidDesc?.drawSpawnsRadius ?? 20
          return mkSpawnsPoly(s.spawns, s.locId, zoneInfo, alpha, radius, map_size, raidDesc?.drawSpawnsClampParam transform)
        }
      ).values())
  }
  if (raidDesc?.drawSpawnsAsPoints)
    children.extend(mkSpawnPoints(allSpawns, transform))

  
  return children.len() > 0 ? children : mkSpawnPoints(allSpawns, transform)
}

return {
  mkSpawns
}
