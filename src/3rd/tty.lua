-- object-based tty streams --

do
  local color_profiles = {
    { -- default VGA colors
      0x000000,
      0xaa0000,
      0x00aa00,
      0xaa5500,
      0x0000aa,
      0xaa00aa,
      0x00aaaa,
      0xaaaaaa,
      0x555555,
      0xff5555,
      0x55ff55,
      0xffff55,
      0x5555ff,
      0xff55ff,
      0x55ffff,
      0xffffff
    },
    { -- Breeze theme colors from Konsole
      0x232627,
      0xed1515,
      0x11d116,
      0xf67400,
      0x1d99f3,
      0x9b59b6,
      0x1abc9c,
      0xfcfcfc,
      -- intense variants
      0x7f8c8d,
      0xc0392b,
      0x1cdc9a,
      0xfdbc4b,
      0x3daee9,
      0x8e44ad,
      0x16a085,
      0xffffff
    },
    { -- Gruvbox
      0x282828,
      0xcc241d,
      0x98971a,
      0xd79921,
      0x458588,
      0xb16286,
      0x689d6a,
      0xa89984,
      0x928374,
      0xfb4934,
      0xb8bb26,
      0xfabd2f,
      0x83a598,
      0xd3869b,
      0x8ec07c,
      0xebdbb2
    },
    { -- Gruvbox light, for those crazy enough to want a light theme
      0xfbf1c7,
      0xcc241d,
      0x98971a,
      0xd79921,
      0x458588,
      0xb16286,
      0x689d6a,
      0x7c6f64,
      0x928374,
      0x9d0006,
      0x79740e,
      0xb57614,
      0x076678,
      0x8f3f71,
      0x427b58,
      0x3c3836
    },
    { -- PaperColor light
      0xeeeeee,
      0xaf0000,
      0x008700,
      0x5f8700,
      0x0087af,
      0x878787,
      0x005f87,
      0x444444,
      0xbcbcbc,
      0xd70000,
      0xd70087,
      0x8700af,
      0xd75f00,
      0xd75f00,
      0x005faf,
      0x005f87
    },
    { -- Pale Night
      0x292d3e,
      0xf07178,
      0xc3e88d,
      0xffcb6b,
      0x82aaff,
      0xc792ea,
      0x89ddff,
      0xd0d0d0,
      0x434758,
      0xff8b92,
      0xddffa7,
      0xffe585,
      0x9cc4ff,
      0xe1acff,
      0xa3f7ff,
      0xffffff,
    }
  }
  local colors = color_profiles[1]

  if type(k.cmdline["tty.profile"]) == "number" then
    colors = color_profiles[k.cmdline["tty.profile"]] or color_profiles[1]
  end

  if type(k.cmdline["tty.colors"]) == "string" then
    for color in k.cmdline["tty.colors"]:gmatch("[^,]+") do
      local idx, col = color:match("(%x):(%x%x%x%x%x%x)")
      if idx and col then
        idx = tonumber(idx, 16) + 1
        col = tonumber(col, 16)
        colors[idx] = col or colors[idx]
      end
    end
  end
  
  local len = unicode.len
  local sub = unicode.sub

  -- pop characters from the end of a string
  local function pop(str, n, u)
    local sub, len = string.sub, string.len
    if not u then sub = unicode.sub len = unicode.len end
    local ret = sub(str, 1, n)
    local also = sub(str, len(ret) + 1, -1)
 
    return also, ret
  end

  local function wrap_cursor(self)
    while self.cx > self.w do
    --if self.cx > self.w then
      self.cx, self.cy = math.max(1, self.cx - self.w), self.cy + 1
    end
    
    while self.cx < 1 do
      self.cx, self.cy = self.w + self.cx, self.cy - 1
    end
    
    while self.cy < 1 do
      self.cy = self.cy + 1
      self.gpu.copy(1, 1, self.w, self.h - 1, 0, 1)
      self.gpu.fill(1, 1, self.w, 1, " ")
    end
    
    while self.cy > self.h do
      self.cy = self.cy - 1
      self.gpu.copy(1, 2, self.w, self.h, 0, -1)
      self.gpu.fill(1, self.h, self.w, 1, " ")
    end
  end

  local function writeline(self, rline)
    local wrapped = false
    while #rline > 0 do
      local to_write
      rline, to_write = pop(rline, self.w - self.cx + 1)
      
      self.gpu.set(self.cx, self.cy, to_write)
      
      self.cx = self.cx + len(to_write)
      wrapped = self.cx > self.w
      
      wrap_cursor(self)
    end
    return wrapped
  end

  local function write(self, lines)
    if self.attributes.xoff then return end
    while #lines > 0 do
      local next_nl = lines:find("\n")

      if next_nl then
        local ln
        lines, ln = pop(lines, next_nl - 1, true)
        lines = lines:sub(2) -- take off the newline
        
        local w = writeline(self, ln)

        if not w then
          self.cx, self.cy = 1, self.cy + 1
        end

        wrap_cursor(self)
      else
        writeline(self, lines)
        break
      end
    end
  end

  local commands, control = {}, {}
  local separators = {
    standard = "[",
    control = "?"
  }

  -- move cursor up N[=1] lines
  function commands:A(args)
    local n = math.max(args[1] or 0, 1)
    self.cy = self.cy - n
  end

  -- move cursor down N[=1] lines
  function commands:B(args)
    local n = math.max(args[1] or 0, 1)
    self.cy = self.cy + n
  end

  -- move cursor right N[=1] lines
  function commands:C(args)
    local n = math.max(args[1] or 0, 1)
    self.cx = self.cx + n
  end

  -- move cursor left N[=1] lines
  function commands:D(args)
    local n = math.max(args[1] or 0, 1)
    self.cx = self.cx - n
  end

  -- incompatibility: terminal-specific command for calling advanced GPU
  -- functionality
  function commands:g(args)
    if #args < 1 then return end
    local cmd = table.remove(args, 1)
    if cmd == 0 then -- fill
      if #args < 4 then return end
      args[1] = math.max(1, math.min(args[1], self.w))
      args[2] = math.max(1, math.min(args[2], self.h))
      self.gpu.fill(args[1], args[2], args[3], args[4], " ")
    elseif cmd == 1 then -- copy
      if #args < 6 then return end
      self.gpu.copy(args[1], args[2], args[3], args[4], args[5], args[6])
    end
    -- TODO more commands
  end

  function commands:G(args)
    self.cx = math.max(1, math.min(self.w, args[1] or 1))
  end

  function commands:H(args)
    local y, x = 1, 1
    y = args[1] or y
    x = args[2] or x
  
    self.cx = math.max(1, math.min(self.w, x))
    self.cy = math.max(1, math.min(self.h, y))
    
    wrap_cursor(self)
  end

  -- clear a portion of the screen
  function commands:J(args)
    local n = args[1] or 0
    
    if n == 0 then
      self.gpu.fill(1, self.cy, self.w, self.h - self.cy, " ")
    elseif n == 1 then
      self.gpu.fill(1, 1, self.w, self.cy, " ")
    elseif n == 2 then
      self.gpu.fill(1, 1, self.w, self.h, " ")
    end
  end
  
  -- clear a portion of the current line
  function commands:K(args)
    local n = args[1] or 0
    
    if n == 0 then
      self.gpu.fill(self.cx, self.cy, self.w, 1, " ")
    elseif n == 1 then
      self.gpu.fill(1, self.cy, self.cx, 1, " ")
    elseif n == 2 then
      self.gpu.fill(1, self.cy, self.w, 1, " ")
    end
  end

  -- adjust some terminal attributes - foreground/background color and local
  -- echo.  for more control {ESC}?c may be desirable.
  function commands:m(args)
    args[1] = args[1] or 0
    local i = 1
    while i <= #args do
      local n = args[i]
      if n == 0 then
        self.fg = 7
        self.bg = 0
        self.fgp = true
        self.bgp = true
        self.gpu.setForeground(self.fg, true)
        self.gpu.setBackground(self.bg, true)
        self.attributes.echo = true
      elseif n == 8 then
        self.attributes.echo = false
      elseif n == 28 then
        self.attributes.echo = true
      elseif n > 29 and n < 38 then
        self.fg = n - 30
        self.fgp = true
        self.gpu.setForeground(self.fg, true)
      elseif n == 39 then
        self.fg = 7
        self.fgp = true
        self.gpu.setForeground(self.fg, true)
      elseif n > 39 and n < 48 then
        self.bg = n - 40
        self.bgp = true
        self.gpu.setBackground(self.bg, true)
      elseif n == 49 then
        self.bg = 0
        self.bgp = true
        self.gpu.setBackground(self.bg, true)
      elseif n > 89 and n < 98 then
        self.fg = n - 82
        self.fgp = true
        self.gpu.setForeground(self.fg, true)
      elseif n > 99 and n < 108 then
        self.bg = n - 92
        self.bgp = true
        self.gpu.setBackground(self.bg, true)
      elseif n == 38 then
        i = i + 1
        if not args[i] then return end
        local mode = args[i]
        if mode == 5 then -- 256-color mode
          -- TODO
        elseif mode == 2 then -- 24-bit color mode
          local r, g, b = args[i + 1], args[i + 2], args[i + 3]
          if not b then return end
          i = i + 3
          self.fg = (r << 16) + (g << 8) + b
          self.fgp = false
          self.gpu.setForeground(self.fg)
        end
      elseif n == 48 then
        i = i + 1
        if not args[i] then return end
        local mode = args[i]
        if mode == 5 then -- 256-color mode
          -- TODO
        elseif mode == 2 then -- 24-bit color mode
          local r, g, b = args[i + 1], args[i + 2], args[i + 3]
          if not b then return end
          i = i + 3
          self.bg = (r << 16) + (g << 8) + b
          self.bgp = false
          self.gpu.setBackground(self.bg)
        end
      end
      i = i + 1
    end
  end

  function commands:n(args)
    local n = args[1] or 0

    if n == 6 then
      self.rb = string.format("%s\27[%d;%dR", self.rb, self.cy, self.cx)
    end
  end

  function commands:S(args)
    local n = args[1] or 1
    self.gpu.copy(1, n, self.w, self.h, 0, -n)
    self.gpu.fill(1, self.h - n, self.w, n, " ")
  end

  function commands:T(args)
    local n = args[1] or 1
    self.gpu.copy(1, 1, self.w, self.h-n, 0, n)
    self.gpu.fill(1, 1, self.w, n, " ")
  end

  -- adjust more terminal attributes
  -- codes:
  --   - 0: reset
  --   - 1: enable echo
  --   - 2: enable line mode
  --   - 3: enable raw mode
  --   - 4: show cursor
  --   - 5: undo 15
  --   - 11: disable echo
  --   - 12: disable line mode
  --   - 13: disable raw mode
  --   - 14: hide cursor
  --   - 15: disable all input and output
  function control:c(args)
    args[1] = args[1] or 0
    
    for i=1, #args, 1 do
      local n = args[i]

      if n == 0 then -- (re)set configuration to sane defaults
        -- echo text that the user has entered?
        self.attributes.echo = true
        
        -- buffer input by line?
        self.attributes.line = true
        
        -- whether to send raw key input data according to the VT100 spec,
        -- rather than e.g. changing \r -> \n and capturing backspace
        self.attributes.raw = false

        -- whether to show the terminal cursor
        self.attributes.cursor = true
      elseif n == 1 then
        self.attributes.echo = true
      elseif n == 2 then
        self.attributes.line = true
      elseif n == 3 then
        self.attributes.raw = true
      elseif n == 4 then
        self.attributes.cursor = true
      elseif n == 5 then
        self.attributes.xoff = false
      elseif n == 11 then
        self.attributes.echo = false
      elseif n == 12 then
        self.attributes.line = false
      elseif n == 13 then
        self.attributes.raw = false
      elseif n == 14 then
        self.attributes.cursor = false
      elseif n == 15 then
        self.attributes.xoff = true
      end
    end
  end

  -- adjust signal behavior
  -- 0: reset
  -- 1: disable INT on ^C
  -- 2: disable keyboard STOP on ^Z
  -- 3: disable HUP on ^D
  -- 11: enable INT
  -- 12: enable STOP
  -- 13: enable HUP
  function control:s(args)
    args[1] = args[1] or 0
    for i=1, #args, 1 do
      local n = args[i]
      if n == 0 then
        self.disabled = {}
      elseif n == 1 then
        self.disabled.C = true
      elseif n == 2 then
        self.disabled.Z = true
      elseif n == 3 then
        self.disabled.D = true
      elseif n == 11 then
        self.disabled.C = false
      elseif n == 12 then
        self.disabled.Z = false
      elseif n == 13 then
        self.disabled.D = false
      end
    end
  end

  local _stream = {}

  local function temp(...)
    return ...
  end

  function _stream:write(...)
    checkArg(1, ..., "string")

    local str = (k.util and k.util.concat or temp)(...)

    if self.attributes.line and not k.cmdline.nottylinebuffer then
      self.wb = self.wb .. str
      if self.wb:find("\n") then
        local ln = self.wb:match(".+\n")
        if not ln then ln = self.wb:match(".-\n") end
        self.wb = self.wb:sub(#ln + 1)
        return self:write_str(ln)
      elseif len(self.wb) > 2048 then
        local ln = self.wb
        self.wb = ""
        return self:write_str(ln)
      end
    else
      return self:write_str(str)
    end
  end

  -- This is where most of the heavy lifting happens.  I've attempted to make
  -- this function fairly optimized, but there's only so much one can do given
  -- OpenComputers's call budget limits and wrapped string library.
  function _stream:write_str(str)
    local gpu = self.gpu
    local time = computer.uptime()
    
    -- TODO: cursor logic is a bit brute-force currently, there are certain
    -- TODO: scenarios where cursor manipulation is unnecessary
    if self.attributes.cursor then
      local c, f, b, pf, pb = gpu.get(self.cx, self.cy)
      if pf then
        gpu.setForeground(pb, true)
        gpu.setBackground(pf, true)
      else
        gpu.setForeground(b)
        gpu.setBackground(f)
      end
      gpu.set(self.cx, self.cy, c)
      gpu.setForeground(self.fg, self.fgp)
      gpu.setBackground(self.bg, self.bgp)
    end
    
    -- lazily convert tabs
    str = str:gsub("\t", "  ")
    
    while #str > 0 do
      --[[if computer.uptime() - time >= 4.8 then -- almost TLWY
        time = computer.uptime()
        computer.pullSignal(0) -- yield so we don't die
      end]]

      if self.in_esc then
        local esc_end = str:find("[a-zA-Z]")

        if not esc_end then
          self.esc = self.esc .. str
        else
          self.in_esc = false

          local finish
          str, finish = pop(str, esc_end, true)

          local esc = self.esc .. finish
          self.esc = ""

          local separator, raw_args, code = esc:match(
            "\27([%[%?])([%-%d;]*)([a-zA-Z])")
          raw_args = raw_args or "0"
          
          local args = {}
          for arg in raw_args:gmatch("([^;]+)") do
            args[#args + 1] = tonumber(arg) or 0
          end
          
          if separator == separators.standard and commands[code] then
            commands[code](self, args)
          elseif separator == separators.control and control[code] then
            control[code](self, args)
          end
          
          wrap_cursor(self)
        end
      else
        -- handle BEL and \r
        if str:find("\a") then
          computer.beep()
        end
        str = str:gsub("\a", "")
        str = str:gsub("\r", "\27[G")

        local next_esc = str:find("\27")
        
        if next_esc then
          self.in_esc = true
          self.esc = ""
        
          local ln
          str, ln = pop(str, next_esc - 1, true)
          
          write(self, ln)
        else
          write(self, str)
          str = ""
        end
      end
    end

    if self.attributes.cursor then
      c, f, b, pf, pb = gpu.get(self.cx, self.cy)
    
      if pf then
        gpu.setForeground(pb, true)
        gpu.setBackground(pf, true)
      else
        gpu.setForeground(b)
        gpu.setBackground(f)
      end
      gpu.set(self.cx, self.cy, c)
      if pf then
        gpu.setForeground(self.fg, self.fgp)
        gpu.setBackground(self.bg, self.bgp)
      end
    end
    
    return true
  end

  function _stream:flush()
    if #self.wb > 0 then
      self:write_str(self.wb)
      self.wb = ""
    end
    return true
  end

  -- aliases of key scan codes to key inputs
  local aliases = {
    [200] = "\27[A", -- up
    [208] = "\27[B", -- down
    [205] = "\27[C", -- right
    [203] = "\27[D", -- left
  }

  local sigacts = {
    D = 1, -- hangup, TODO: check this is correct
    C = 2, -- interrupt
    Z = 18, -- keyboard stop
  }

  function _stream:key_down(...)
    local signal = table.pack(...)

    if not self.keyboards[signal[2]] then
      return
    end

    if signal[3] == 0 and signal[4] == 0 then
      return
    end

    if self.xoff then
      return
    end
    
    local char = aliases[signal[4]] or
              (signal[3] > 255 and unicode.char or string.char)(signal[3])
    local ch = signal[3]
    local tw = char

    if ch == 0 and not aliases[signal[4]] then
      return
    end
    
    if len(char) == 1 and ch == 0 then
      char = ""
      tw = ""
    elseif char:match("\27%[[ABCD]") then
      tw = string.format("^[%s", char:sub(-1))
    elseif #char == 1 and ch < 32 then
      local tch = string.char(
          (ch == 0 and 32) or
          (ch < 27 and ch + 96) or
          (ch == 27 and 91) or -- [
          (ch == 28 and 92) or -- \
          (ch == 29 and 93) or -- ]
          (ch == 30 and 126) or
          (ch == 31 and 63) or ch
        ):upper()
    
      if sigacts[tch] and not self.disabled[tch] and k.scheduler.processes
          and not self.attributes.raw then
        -- fairly stupid method of determining the foreground process:
        -- find the highest PID associated with this TTY
        -- yeah, it's stupid, but it should work in most cases.
        -- and where it doesn't the shell should handle it.
        local mxp = 0

        for _k, v in pairs(k.scheduler.processes) do
          --k.log(k.loglevels.error, _k, v.name, v.io.stderr.tty, self.ttyn)
          if v.io.stderr.tty == self.tty then
            mxp = math.max(mxp, _k)
          elseif v.io.stdin.tty == self.tty then
            mxp = math.max(mxp, _k)
          elseif v.io.stdout.tty == self.tty then
            mxp = math.max(mxp, _k)
          end
        end

        --k.log(k.loglevels.error, "sending", sigacts[tch], "to", mxp == 0 and mxp or k.scheduler.processes[mxp].name)

        if mxp > 0 then
          k.scheduler.kill(mxp, sigacts[tch])
        end

        self.rb = ""
        if tch == "\4" then self.rb = tch end
        char = ""
      end

      tw = "^" .. tch
    end
    
    if not self.attributes.raw then
      if ch == 13 then
        char = "\n"
        tw = "\n"
      elseif ch == 8 then
        if #self.rb > 0 then
          tw = "\27[D \27[D"
          self.rb = self.rb:sub(1, -2)
        else
          tw = ""
        end
        char = ""
      end
    end
    
    if self.attributes.echo and not self.attributes.xoff then
      self:write_str(tw or "")
    end
    
    if not self.attributes.xoff then
      self.rb = self.rb .. char
    end
  end

  function _stream:clipboard(...)
    local signal = table.pack(...)

    for c in signal[3]:gmatch(".") do
      self:key_down(signal[1], signal[2], c:byte(), 0)
    end
  end
  
  function _stream:read(n)
    checkArg(1, n, "number")

    self:flush()

    local dd = self.disabled.D or self.attributes.raw

    if self.attributes.line then
      while (not self.rb:find("\n")) or (len(self.rb:sub(1, (self.rb:find("\n")))) < n)
          and not (self.rb:find("\4") and not dd) do
        coroutine.yield()
      end
    else
      while len(self.rb) < n and (self.attributes.raw or not
          (self.rb:find("\4") and not dd)) do
        coroutine.yield()
      end
    end

    if self.rb:find("\4") and not dd then
      self.rb = ""
      return nil
    end

    local data = sub(self.rb, 1, n)
    self.rb = sub(self.rb, n + 1)
    return data
  end

  local function closed()
    return nil, "stream closed"
  end

  function _stream:close()
    self:flush()
    self.closed = true
    self.read = closed
    self.write = closed
    self.flush = closed
    self.close = closed
    k.event.unregister(self.key_handler_id)
    k.event.unregister(self.clip_handler_id)
    if self.ttyn then k.sysfs.unregister("/dev/tty"..self.ttyn) end
    return true
  end

  local ttyn = 0

  -- this is the raw function for creating TTYs over components
  -- userspace gets somewhat-abstracted-away stuff
  function k.create_tty(gpu, screen)
    checkArg(1, gpu, "string", "table")
    checkArg(2, screen, "string", "nil")

    local proxy
    if type(gpu) == "string" then
      proxy = component.proxy(gpu)

      if screen then proxy.bind(screen) end
    else
      proxy = gpu
    end

    -- set the gpu's palette
    for i=1, #colors, 1 do
      proxy.setPaletteColor(i - 1, colors[i])
    end

    proxy.setForeground(7, true)
    proxy.setBackground(0, true)

    proxy.setDepth(proxy.maxDepth())
    -- optimizations for no color on T1
    if proxy.getDepth() == 1 then
      local fg, bg = proxy.setForeground, proxy.setBackground
      local f, b = 7, 0
      function proxy.setForeground(c)
        -- [[
        if c >= 0xAAAAAA or c <= 0x000000 and f ~= c then
          fg(c)
        end
        f = c
        --]]
      end
      function proxy.setBackground(c)
        -- [[
        if c >= 0xDDDDDD or c <= 0x000000 and b ~= c then
          bg(c)
        end
        b = c
        --]]
      end
      proxy.getBackground = function()return f end
      proxy.getForeground = function()return b end
    end

    -- userspace will never directly see this, so it doesn't really matter what
    -- we put in this table
    local new = setmetatable({
      attributes = {echo=true,line=true,raw=false,cursor=false,xoff=false}, -- terminal attributes
      disabled = {}, -- disabled signals
      keyboards = {}, -- all attached keyboards on terminal initialization
      in_esc = false, -- was a partial escape sequence written
      gpu = proxy, -- the associated GPU
      esc = "", -- the escape sequence buffer
      cx = 1, -- the cursor's X position
      cy = 1, -- the cursor's Y position
      fg = 7, -- the current foreground color
      bg = 0, -- the current background color
      fgp = true, -- whether the foreground color is a palette index
      bgp = true, -- whether the background color is a palette index
      rb = "", -- a buffer of characters read from the input
      wb = "", -- line buffering at its finest
    }, {__index = _stream})

    -- avoid gpu.getResolution calls
    new.w, new.h = proxy.maxResolution()

    proxy.setResolution(new.w, new.h)
    proxy.fill(1, 1, new.w, new.h, " ")
    
    if screen then
      -- register all keyboards attached to the screen
      for _, keyboard in pairs(component.invoke(screen, "getKeyboards")) do
        new.keyboards[keyboard] = true
      end
    end
    
    -- register a keypress handler
    new.key_handler_id = k.event.register("key_down", function(...)
      return new:key_down(...)
    end)

    new.clip_handler_id = k.event.register("clipboard", function(...)
      return new:clipboard(...)
    end)
    
    -- register the TTY with the sysfs
    if k.sysfs then
      k.sysfs.register(k.sysfs.types.tty, new, "/dev/tty"..ttyn)
      new.ttyn = ttyn
    end

    new.tty = ttyn

    if k.gpus then
      k.gpus[ttyn] = proxy
    end
    
    ttyn = ttyn + 1
    
    return new
  end
end
