-- todo:
-- 3. finish for_engine
-- 4. fix up docs
-- 5. add other engines
-- * add global controls (verb?)

local controls = {}
controls.__index = controls

-- max slider value
local slider_max = 32

-- dampen sensitivity to make the param chooser (ENC 2) less twitchy
local chooser_enc_sens = 0.2

------------------------------------------------------------------------
------
-----  utils
----
------------------------------------------------------------------------

-- todo: move me
local function scale(x, min_in, max_in, min_out, max_out)
  return min_out + (x - min_in) * (max_out - min_out) / (max_in)
end

------------------------------------------------------------------------
------
-----  instance creation and configuration
----
------------------------------------------------------------------------

local function new()
  local c = {
    scalers = {},
    sliders = {},
    output_mix = true, -- whether to mix output w/ ENC 1
    index = 1, -- current param index
    edit = 1, -- param under edit
    ticks = 0
  }
  setmetatable(c, controls)

  local k = metro.init()
  k.count = -1
  k.time = 0.1
  k.event = function(_)
    c.ticks = c.ticks - 1
    if (c.ticks == 0) then
      k:stop()
    end
    redraw() -- ?
  end
  c.metro = k

  return c
end

local function required_param(config, name)
  assert(config[name] ~= nil, "param " .. name .. " required")
  return config[name]
end

-- todo: try tparams

--- add a parameter control
-- @param config (table)
-- @param config.name parameter name
-- @param config.minval parameter minval
-- @param config.maxval parameter maxval
-- @param config.default parameter default value optional; defaults to minval)
-- @param config.step parameter step value (optional; defaults to 0)
-- @param config.warp parameter warp (optional; defaults to "lin")
-- @param config.units parameter units (optional; defaults to "")
function controls:add_param(config)
  -- cache min/max for scaling; could be prettier.
  self.scalers[config.name] = {
    min = config.minval,
    max = config.maxval
  }

  params:add_control(
    required_param(config, "name"),
    required_param(config, "name"), -- todo: add index
    controlspec.new(
      required_param(config, "minval"),
      required_param(config, "maxval"),
      config.warp or "lin",
      config.step or 0,
      config.default or config.minval,
      config.units or ""
    )
  )
  params:set_action(config.name, config.action or engine[config.name])

  local p = params:lookup_param(config.name)
  print("got param: " .. tostring(p))
  self.sliders[tab.count(self.sliders)] = math.floor(scale(p:get(), config.minval, config.maxval, 0, slider_max))

  print("config " .. config.name)
  print("sliders " .. tab.count(self.sliders))
  -- print(params.count)

  -- (re)calculate meter offset
  self.meter_x = (126 - tab.count(self.sliders) * 4) / 2
end

local function new_poly_sub()
  local c = new()
  c:add_param {name = "shape", minval = 0, maxval = 1, default = 0}
  c:add_param {name = "timbre", minval = 0, maxval = 1, default = 0.5}
  c:add_param {name = "noise", minval = 0, maxval = 1, default = 0}
  c:add_param {name = "cut", minval = 0, maxval = 32, default = 8}
  c:add_param {name = "cutAtk", minval = 0.01, maxval = 10, default = 0.05}
  c:add_param {name = "cutDec", minval = 0, maxval = 2, default = 0.1}
  c:add_param {name = "cutSus", minval = 0, maxval = 1, default = 1}
  c:add_param {name = "cutRel", minval = 0.01, maxval = 10, default = 1}
  c:add_param {name = "cutEnvAmt", minval = 0, maxval = 1, default = 1}
  c:add_param {name = "ampAtk", minval = 0.01, maxval = 10, default = 0.05}
  c:add_param {name = "ampDec", minval = 0.01, maxval = 10, default = 0.05}
  c:add_param {name = "ampSus", minval = 0, maxval = 2, default = 0.1}
  c:add_param {name = "ampRel", minval = 0.01, maxval = 10, default = 1}
  c:add_param {name = "fgain", minval = 0, maxval = 6, default = 0}
  c:add_param {name = "sub", minval = 0, maxval = 1, default = 0}
  c:add_param {name = "width", minval = 0, maxval = 1, default = 0}
  c:add_param {name = "detune", minval = 0, maxval = 1, default = 0}

  c.metro:start()
  return c
end

--- configure whether to control output w/ ENC 1
-- @param b (optional; default is true)
function controls:with_output_mix(b)
  self.output_mix = b == nil or b and true
  return self
end

local function new_engine(name)
  assert(name ~= nil, "an engine needs to be specified")
  if (name == "PolySub") then
    return new_poly_sub()
  end
  --todo: throw error
end

function controls.for_engine(name)
  return new_engine(name or engine.name)
end

------------------------------------------------------------------------
------
-----  script callbacks
----
------------------------------------------------------------------------

function controls:enc(n, delta)
  if n == 1 and self.output_mix then
    mix:delta("output", delta)
  elseif n == 2 then
    -- de-twitch param chooser encoder
    -- move to init() once state is stored and restored (norns#414).
    norns.encoders.set_sens(2, chooser_enc_sens)
    self.index = ((self.index + delta - 1) % (tab.count(self.sliders))) + 1
    self.edit = self.index
  elseif n == 3 then
    local name = params:get_name(self.edit)
    params:delta(self.edit, delta)
    self.sliders[self.edit] =
      math.floor(scale(params:get(self.edit), self.scalers[name].min, self.scalers[name].max, 0, slider_max))
  end

  if n ~= 1 then
    -- (re) set timer
    self.ticks = 10
    self.metro:start()
  end

  self:redraw()
end

function controls:redraw()
  screen.aa(1)
  screen.line_width(1.0)
  screen.clear()

  -- meters
  for i, slider in ipairs(self.sliders) do
    screen.level(i == self.edit and 15 or 2)
    screen.move(self.meter_x + i * 4, 48)
    screen.line(self.meter_x + i * 4, 46 - self.sliders[i])
    screen.stroke()
  end

  -- legend
  if (self.ticks > 0) then
    screen.level(self.ticks)
    screen.move(64, 60)

    print(self.index)
    print(params:get_name(self.index))

    screen.text_center(params:get_name(self.index) or "unknown")
  end

  screen.update()
end

return controls
