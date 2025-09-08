options no_global_variables = false

require app
require DagorMath
require DagorRandom
require DagorStdGuiRender
require darg
require math


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

[export]
def setup_data(props : Properties&; var storage : WatchCircleParams&)
  storage.loudness = props |> getFloat("loudness", 0.0)
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

  for s, idx in currentScale, range(currentScale |> length())
    let islong = idx % 5 == 0
    let width = islong ? 3.0 : 2.0
    let dash = islong ? 15.0 : 10.0
    let r0 = 48.0
    let r1 = r0 - dash * s
    let angle = 2.0 * PI * float(idx) / float(dashCount)

    let x0 = center.x + r0 * cos(angle) * rdata.size.x / 100.0
    let y0 = center.y + r0 * sin(angle) * rdata.size.y / 100.0
    let x1 = center.x + r1 * cos(angle) * rdata.size.x / 100.0
    let y1 = center.y + r1 * sin(angle) * rdata.size.y / 100.0

    var longColor : E3DCOLOR
    if s < 0.2
      longColor = gradientColors[0]
    elif s < 0.45
      longColor = e3dcolor_lerp(gradientColors[0], gradientColors[1], (s - 0.2) / 0.25)
    elif s < 0.55
      longColor = e3dcolor_lerp(gradientColors[1], gradientColors[2], (s - 0.45) / 0.1)
    elif s < 0.75
      longColor = e3dcolor_lerp(gradientColors[2], gradientColors[3], (s - 0.55) / 0.2)
    else
      longColor = e3dcolor_lerp(gradientColors[3], gradientColors[4], (s - 0.75) / 0.25)

    let color = islong ? longColor : neutralColor
    ctx |> set_color(color)

    let coord <- to_array_move(fixed_array(float2(x0, y0), float2(x1, y1)))
    ctx |> render_line_aa(coord, false, width, float2(0, 0), color)

  prevUpdateAt = curTime
