--- controls
--
-- in-app param control
-- experiments

local ctl = include "controls.lua"
engine.name = "PolySub"
local controls = ctl.for_engine():with_output_mix()

local g = grid.connect()

------------------------------------------------------------------------
------
-----  locals
----
------------------------------------------------------------------------

local function getHzET(note)
  return 55 * 2 ^ (note / 12)
end

local function grid_note(e)
  local note = ((7 - e.y) * 5) + e.x
  if e.state > 0 then
    engine.start(e.id, getHzET(note))
    g:led(e.x, e.y, 15)
  else
    engine.stop(e.id)
    g:led(e.x, e.y, 0)
  end
  g:refresh()
end

------------------------------------------------------------------------
------
-----  norns hooks
----
------------------------------------------------------------------------

function init()
  engine.level(0.2)
end

function enc(n, delta)
  controls:enc(n, delta)
end

function g.key(x, y, z)
  grid_note {
    id = x * 8 + y,
    x = x,
    y = y,
    state = z
  }
end

function redraw()
  controls:redraw()
end
