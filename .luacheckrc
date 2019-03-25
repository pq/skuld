std = 'lua53'

files['.luacheckrc'].ignore = {'111', '112', '131'}

unused_args = false

-- 'unused argument self'
self = false

read_globals = {
  -- lua53
  math = {
    fields = {
      'log10',
      'pow'
    }
  }
}

globals = {
    'norns',
    'arc',
    'audio',
    'engine',
    'cleanup',
    'controlspec',
    'enc',
    'grid',
    'hid',
    'init',
    'include',
    'key',
    'metro',
    'midi',
    'mix', -- remove
    'params',
    'redraw',
    'screen',
    'softcut',
    'tab',
    'util',
}
