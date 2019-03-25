-- earthsea (riffs)
--
-- subtractive polysynth
-- controlled by midi or grid
--
-- grid pattern player:
-- 1 1 record toggle
-- 1 2 play toggle
-- 1 8 transpose mode

local tab = require "tabutil"
local pattern_time = require "pattern_time"

local g = grid.connect()

local mode_transpose = 0
local mode_quantize = 0
local root = {
  x = 5,
  y = 5
}
local trans = {
  x = 5,
  y = 5
}
local lit = {}

local MAX_NUM_VOICES = 16

engine.name = "PolySub"

local ctl = include "controls.lua"
local controls = ctl.for_engine("PolySub"):with_output_mix()

local loopcut = include "loopcut.lua"
loopcut.init()

-- pythagorean minor/major, kinda
local ratios = {1, 9 / 8, 6 / 5, 5 / 4, 4 / 3, 3 / 2, 27 / 16, 16 / 9}
local base = 27.5 -- low A

local function getHz(deg, oct)
  return base * ratios[deg] * (2 ^ oct)
end

local function getHzET(note)
  return 55 * 2 ^ (note / 12)
end

-- current count of active voices
local nvoices = 0

local patterns = {}
local current_pattern = 1
local pat

local function init_track(n)
  local p = pattern_time.new()
  p.process = function(e)
    grid_note_trans(e, n)
  end
  return p
end

function init()
  patterns = {
    init_track(1),
    init_track(2),
    init_track(3)
  }
  pat = patterns[1]

  engine.level(0.05)
  engine.stopAll()

  -- controls:add_param{name="cut1rate", minval=-2, maxval = 2, default = 0,
  --   action = function (e) print('hi') end
  -- }

  if g then
    gridredraw()
  end
end

local function toggle_record(track_index)
  local p = patterns[track_index]
  if p.rec == 0 then
    mode_transpose = 0
    trans = {x = 5, y = 5}
    p:stop()
    engine.stopAll()
    p:clear()
    p:rec_start()
    -- tmp
    pat = p
  else
    p:rec_stop()
    if p.count > 0 then
      root = {
        x = p.event[1].x,
        y = p.event[1].y
      }
      trans = {
        x = root.x,
        y = root.y
      }
      p:start()
    end
  end
end

local function toggle_play(pattern_index)
  local p = patterns[pattern_index]
  if p.play == 0 and p.count > 0 then
    if p.rec == 1 then
      p:rec_stop()
    end
    p:start()
  elseif p.play == 1 then
    p:stop()
    engine.stopAll()
    nvoices = 0
    lit = {}
  end
end

function g.key(x, y, z)
  if x == 1 then
    if z == 1 then
      if y == 1 then
        toggle_record(1)
      elseif y == 2 then
        toggle_play(1)
      elseif y == 3 then
        toggle_record(2)
      elseif y == 4 then
        toggle_play(2)
      elseif y == 5 then
        toggle_record(3)
      elseif y == 6 then
        toggle_play(3)
      elseif y == 7 then
        mode_quantize = 1 - mode_quantize
      elseif y == 8 then
        mode_transpose = 1 - mode_transpose
      end
    end
  else
    if mode_transpose == 0 then
      local e = {
        id = x * 8 + y,
        x = x,
        y = y,
        state = z
      }
      pat:watch(e)
      grid_note(e)
    else
      trans = {
        x = x,
        y = y
      }
    end
  end
  gridredraw()
end

function grid_note(e)
  local note = ((7 - e.y) * 5) + e.x
  if e.state > 0 then
    if nvoices < MAX_NUM_VOICES then
      -- engine.start(e.id, getHzET(note), 0.0, 0.8)
      engine.start(e.id, getHzET(note))

      lit[e.id] = {
        x = e.x,
        y = e.y,
        track = current_pattern
      }
      nvoices = nvoices + 1
    end
  else
    if lit[e.id] ~= nil then
      engine.stop(e.id)
      lit[e.id] = nil
      nvoices = nvoices - 1
    end
  end
  gridredraw()
end

local function reset_check()
  -- print(pat.step)
  if mode_quantize and pat == patterns[i] then
    if pat.step == pat.count then
      patterns[2].step = 1
      patterns[3].step = 1
    end
  end
end

function grid_note_trans(e, track)
  reset_check()
  local note = ((7 - e.y + (root.y - trans.y)) * 5) + e.x + (trans.x - root.x)
  if e.state > 0 then
    if nvoices < MAX_NUM_VOICES then
      -- engine.start(e.id, getHzET(note), 0.0)
      engine.start(e.id, getHzET(note))
      lit[e.id] = {
        x = e.x + trans.x - root.x,
        y = e.y + trans.y - root.y,
        track = track
      }
      nvoices = nvoices + 1
    end
  else
    engine.stop(e.id)
    lit[e.id] = nil
    nvoices = nvoices - 1
  end
  gridredraw()
end

function gridredraw()
  g:all(0)
  g:led(1, 1, 2 + patterns[1].rec * 10)
  g:led(1, 2, 2 + patterns[1].play * 10)
  g:led(1, 3, 2 + patterns[2].rec * 10)
  g:led(1, 4, 2 + patterns[2].play * 10)
  g:led(1, 5, 2 + patterns[3].rec * 10)
  g:led(1, 6, 2 + patterns[3].play * 10)

  g:led(1, 7, 2 + mode_quantize * 10)
  g:led(1, 8, 2 + mode_transpose * 10)

  if mode_transpose == 1 then
    g:led(trans.x, trans.y, 4)
  end
  for _, e in pairs(lit) do
    -- vary intensity w/ track
    g:led(e.x, e.y, 15 - ((e.track - 1) * 6))
  end

  g:refresh()
end

function enc(n, delta)
  controls:enc(n, delta)
end

function redraw()
  controls:redraw()
  -- screen.clear()
  -- screen.aa(0)
  -- screen.line_width(1)
  -- screen.move(0,30)
  -- screen.text('hi')
end

local function note_on(note, vel)
  if nvoices < MAX_NUM_VOICES then
    print("note on")
    engine.start(note, getHzET(note), 0.0)
    nvoices = nvoices + 1
  end
end

local function note_off(note, vel)
  engine.stop(note)
  nvoices = nvoices - 1
end

local function midi_event(data)
  if data[1] == 144 then
    if data[3] == 0 then
      note_off(data[2])
    else
      note_on(data[2], data[3])
    end
  elseif data[1] == 128 then
    note_off(data[2])
  elseif data[1] == 176 then
    --cc(data1, data2)
  elseif data[1] == 224 then
  --bend(data1, data2)
  end
end

midi.add = function(dev)
  print("earthsea: midi device added", dev.id, dev.name)
  dev.event = midi_event
end

function cleanup()
  pat:stop()
  pat = nil
end
