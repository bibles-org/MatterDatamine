options no_global_variables = false

require app
require DagorMath
require DagorRandom
require DagorStdGuiRender
require darg
require math
require %daslib.functional


let dashCount = 60
let maxLoudness = 160.0

let neutralColor = E3DCOLOR(Color4(float4(0.8, 0.8, 0.8, 0.8))) // rgba(204,204,204,0.8)

let gradientColors <- fixed_array<E3DCOLOR>(
  neutralColor,
  E3DCOLOR(Color4(float4(0.53, 0.74, 0.89, 0.8))), // rgba(135,189,228,0.8)
  E3DCOLOR(Color4(float4(0.93, 0.92, 0.59, 0.8))), // rgba(237,235,151,0.8)
  E3DCOLOR(Color4(float4(0.96, 0.73, 0.45, 0.8))), // rgba(244,186,116,0.8)
  E3DCOLOR(Color4(float4(0.6, 0.16, 0.16, 1.0)))  // rgba(153,40,40,1)
)

var prevUpdateAt = 0.0
let noiseUpdateInterval = 0.1
var noiseUpdateAt = 0.0

// idk how to init these arrays in a better way.
var noiseArray <- fixed_array<float>(
  0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
  0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
  0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
  0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
  0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
  0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0)

var speechWaves <- fixed_array<float>(
  0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
  0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
  0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
  0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
  0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
  0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0)

var wishScale <- fixed_array<float>(
  0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
  0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
  0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
  0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
  0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
  0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0)

var currentScale <- fixed_array<float>(
  0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
  0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
  0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
  0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
  0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
  0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0)

struct WatchCircleParams
  loudness : float = 0.0
  speech : bool = false
  amGathererTickInterval : float = 1.0
  amGathererTickAt : float = 0.0
  amStorageFull : bool = false

struct VoiceWave
  amplitude : float
  pos : int
  speed : int
  width : int

var voiceWaves <- fixed_array(
    VoiceWave(amplitude = 1.0, pos = 0, speed = 3, width = 5),
    VoiceWave(amplitude = 1.0, pos = 15, speed = 3, width = 6),
    VoiceWave(amplitude = 1.0, pos = 30, speed = 3, width = 5),
    VoiceWave(amplitude = 1.0, pos = 45, speed = 3, width = 8))

// somehow it is impossible to import easings.das in this context
def outQuart(p : float)
  let f = (p - 1.f)
  return f * f * f * (1.f - p) + 1.f

[export]
def setup_data(props : Properties&; var storage : WatchCircleParams&)
  storage.amGathererTickInterval = props |> getFloat("amGathererTickInterval", 1.0)
  storage.amGathererTickAt = props |> getFloat("amGathererTickAt", 0.0)
  storage.amStorageFull = props |> getBool("amStorageFull", false)
  storage.loudness = storage.amGathererTickAt > 0.0 ? maxLoudness / 2.0 : props |> getFloat("loudness", 0.0)
  storage.speech = props |> getBool("speech", false)

var seed = 42

[export, unused_argument(rstate)]
def draw_watchface(var ctx : GuiContext&;
                   rdata : ElemRenderData& const;
                   rstate : RenderState& const;
                   data : WatchCircleParams& const)

  let lt = rdata.pos
  let rb = rdata.pos + rdata.size
  let center = (lt + rb) * 0.5

  let curTime = get_sync_time()

  // scene change could cause curTime to go back in time
  if curTime < prevUpdateAt
    prevUpdateAt = 0.0
    noiseUpdateAt = 0.0

  // here we adding non-linear function to loudness to make it more visually appealing
  let correctedLoudness = clamp(sqrt(data.loudness / maxLoudness), 0.0, 1.0)

  if curTime > noiseUpdateAt
    noiseUpdateAt = curTime + noiseUpdateInterval
    for i in range(0, dashCount)
      noiseArray[i] = _frnd(seed) * 0.6 - 0.3

    for i in range(0, dashCount)
      speechWaves[i] = data.speech ? 0.2 : 0.0

    if data.speech
      for wave in voiceWaves
        for i in range(0, wave.width)
          let additional = sin(PI * float(i) / float(wave.width)) * wave.amplitude
          let pos = (dashCount + wave.pos - (wave.width / 2) + i) % dashCount
          speechWaves[pos] = speechWaves[pos] + additional
        wave.pos = (wave.pos + wave.speed) % dashCount

  for i in range(0, dashCount)
    wishScale[i] = clamp(0.2 + correctedLoudness * 0.8 + noiseArray[i] * correctedLoudness + speechWaves[i], 0.0, 1.0)

  let t = 1.0 - exp(-8.0 * (curTime - prevUpdateAt))
  for i in range(0, dashCount)
    currentScale[i] = currentScale[i] + t * (wishScale[i] - currentScale[i])

  for scale, idx in currentScale, range(currentScale |> length())
    let islong = idx % 5 == 0
    let width = islong ? 3.0 : 2.0
    let dash = islong ? 15.0 : 10.0
    let r0 = 48.0
    let r1 = r0 - dash * scale
    let angle = 2.0 * PI * float(idx) / float(dashCount)

    var s, c : float
    sincos(angle, s, c)

    let x0 = center.x + r0 * c * rdata.size.x / 100.0
    let y0 = center.y + r0 * s * rdata.size.y / 100.0
    let x1 = center.x + r1 * c * rdata.size.x / 100.0
    let y1 = center.y + r1 * s * rdata.size.y / 100.0

    var longColor : E3DCOLOR
    if scale < 0.2
      longColor = gradientColors[0]
    elif scale < 0.45
      longColor = e3dcolor_lerp(gradientColors[0], gradientColors[1], (scale - 0.2) / 0.25)
    elif scale < 0.55
      longColor = e3dcolor_lerp(gradientColors[1], gradientColors[2], (scale - 0.45) / 0.1)
    elif scale < 0.75
      longColor = e3dcolor_lerp(gradientColors[2], gradientColors[3], (scale - 0.55) / 0.2)
    else
      longColor = e3dcolor_lerp(gradientColors[3], gradientColors[4], (scale - 0.75) / 0.25)

    let color = islong ? longColor : neutralColor
    ctx |> set_color(color)

    let coord <- to_array_move(fixed_array(float2(x0, y0), float2(x1, y1)))
    ctx |> render_line_aa(coord, false, width, float2(0, 0), color)

  prevUpdateAt = curTime

  if data.amGathererTickAt <= 0.0
    return

  let prevBlend = ctx |> get_alpha_blend()
  ctx |> set_alpha_blend(BlendMode.PREMULTIPLIED)

  let a = 18.0 / 100.0 * rdata.size.y // side length of the central triangle
  let r = a * sqrt(3.0) / 3.0 // radius of circle around triangle
  let logoOffset = float2(0, -a / 3.0)

  // 1 -> 0
  let gathererProgress = data.amStorageFull ? 0.0 : clamp(outQuart((data.amGathererTickAt - curTime) / data.amGathererTickInterval), 0.0, 1.0)

  let logoColor1 = E3DCOLOR(Color4(float4(0.6, 0.6, 0.6, 0.6)))
  let logoColor2 = E3DCOLOR(Color4(float4(0.9, 0.9, 0.9, 0.8)))
  let logoColor = e3dcolor_lerp(logoColor2, logoColor1, gathererProgress)

  let shadowColor1 = E3DCOLOR(Color4(float4(0.5, 0.5, 0.5, 0.0)))
  let shadowColor2 = E3DCOLOR(Color4(float4(0.0, 0.90196, 0.65098, 0.9)))
  let shadowColor = e3dcolor_lerp(shadowColor2, shadowColor1, gathererProgress)

  let triangle = array(
    center + logoOffset + float2(r * cos(-PI / 2.0), r * sin(-PI / 2.0)),
    center + logoOffset + float2(r * cos(-PI / 2.0 + 2.0 * PI / 3.0), r * sin(-PI / 2.0 + 2.0 * PI / 3.0)),
    center + logoOffset + float2(r * cos(-PI / 2.0 + 4.0 * PI / 3.0), r * sin(-PI / 2.0 + 4.0 * PI / 3.0)),
  )

  var bars : array<array<float2>>
  bars.reserve(3)

  for i in range(3)
    let idx0 = i + 0
    let idx1 = (i + 1) % 3
    let idx2 = (i + 2) % 3

    bars.emplace(array(
      triangle[idx0] + (triangle[idx0] - triangle[idx2]) / 3.0,
      triangle[idx1] + (triangle[idx1] - triangle[idx2]) / 3.0,
      triangle[idx1] + 2.0 * (triangle[idx1] - triangle[idx2]) / 3.0,
      triangle[idx0] + 2.0 * (triangle[idx0] - triangle[idx2]) / 3.0,
    ))

  let maxScale = 2.0
  let minScale = 1.0
  var shadowTriangle : array<float2>
  shadowTriangle.reserve(3)
  for p in triangle
    shadowTriangle.push((p - center - logoOffset) * lerp(minScale, maxScale, gathererProgress) + center + logoOffset)

  var shadowBars : array<array<float2>>
  shadowBars.reserve(3)
  for i in range(3)
    let idx0 = i
    let idx1 = (i + 1) % 3
    let idx2 = (i + 2) % 3

    shadowBars.emplace(array(
      triangle[idx0] + (1.0 - gathererProgress) * (triangle[idx0] - triangle[idx2]) / 3.0 + gathererProgress * (triangle[idx0] - triangle[idx1]) / 3.0,
      triangle[idx1] + (1.0 - gathererProgress) * (triangle[idx1] - triangle[idx2]) / 3.0 + gathererProgress * (triangle[idx1] - triangle[idx0]) / 3.0,
      triangle[idx1] + (2.0 + 2.0 * gathererProgress) * (triangle[idx1] - triangle[idx2]) / 3.0 + gathererProgress * (triangle[idx1] - triangle[idx0]) / 3.0,
      triangle[idx0] + (2.0 + 2.0 * gathererProgress) * (triangle[idx0] - triangle[idx2]) / 3.0 + gathererProgress * (triangle[idx0] - triangle[idx1]) / 3.0,
    ))

  ctx |> set_alpha_blend(BlendMode.NONPREMULTIPLIED)
  ctx |> render_poly(shadowTriangle, shadowColor)
  for i in range(3)
    ctx |> render_poly(shadowBars[i], shadowColor)

  ctx |> set_alpha_blend(BlendMode.PREMULTIPLIED)
  ctx |> render_poly(triangle, logoColor)
  for i in range(3)
    ctx |> render_poly(bars[i], logoColor)

  ctx |> set_alpha_blend(prevBlend)
