local VM = {}

VM.DISPLAY_WIDTH = 64
VM.DISPLAY_HEIGHT = 32
VM.MEMORY_SIZE = 0xFFF

local font_set = {
  0xF0, 0x90, 0x90, 0x90, 0xF0,  -- 0
  0x20, 0x60, 0x20, 0x20, 0x70,  -- 1
  0xF0, 0x10, 0xF0, 0x80, 0xF0,  -- 2
  0xF0, 0x10, 0xF0, 0x10, 0xF0,  -- 3
  0x90, 0x90, 0xF0, 0x10, 0x10,  -- 4
  0xF0, 0x80, 0xF0, 0x10, 0xF0,  -- 5
  0xF0, 0x80, 0xF0, 0x90, 0xF0,  -- 6
  0xF0, 0x10, 0x20, 0x40, 0x40,  -- 7
  0xF0, 0x90, 0xF0, 0x90, 0xF0,  -- 8
  0xF0, 0x90, 0xF0, 0x10, 0xF0,  -- 9
  0xF0, 0x90, 0xF0, 0x90, 0x90,  -- A
  0xE0, 0x90, 0xE0, 0x90, 0xE0,  -- B
  0xF0, 0x80, 0x80, 0x80, 0xF0,  -- C
  0xE0, 0x90, 0x90, 0x90, 0xE0,  -- D
  0xF0, 0x80, 0xF0, 0x80, 0xF0,  -- E
  0xF0, 0x80, 0xF0, 0x80, 0x80   -- F
}

function VM.new()
  local vm = {
    registers = {},
    memory = {},
    display = {},
    keyboard = {},
    stack = {},
    pc = 0x200, -- program counter
    i = 0,  -- memory index register
    sp = 0, -- stack pointer
    dt = 0, -- delay timer
    st = 0, -- sound timer
    redraw = false, -- flag set when the display has updated
  }

  for i = 0, 15 do
    vm.registers[i] = 0
  end

  for i = 0, VM.MEMORY_SIZE - 1 do
    vm.memory[i] = 0
  end

  for i = 0, 15 do
    vm.keyboard[i] = false
  end

  for i = 0, VM.DISPLAY_WIDTH * VM.DISPLAY_HEIGHT - 1 do
    vm.display[i] = 0
  end

  -- store the font sprites from 0x00-0x80
  for i = 1, #font_set do
    vm.memory[i - 1] = font_set[i]
  end

  return vm
end

function VM.load(vm, program)
  local i = 0x200

  for _, value in ipairs(program) do
    local high_byte = value >> 8
    local low_byte = value & 0x00FF
    vm.memory[i] = high_byte
    vm.memory[i + 1] = low_byte
    i = i + 2
  end
end

function VM.load_from_disk(vm, path)
  local file = assert(io.open(path, "rb"))
  local i = 0x200

  while true do
    local byte = file:read(1)

    if not byte then
      break
    end

    vm.memory[i] = string.byte(byte)
    i = i + 1
  end
end

function VM.fetch(vm)
  local high_byte = vm.memory[vm.pc]
  local low_byte = vm.memory[vm.pc + 1]
  return high_byte << 8 | low_byte
end

function VM.emulate(vm)
  -- count down sound timer
  if vm.st > 0 then
    vm.st = vm.st - 1
  end

  -- count down delay timer
  if vm.dt > 0 then
    vm.dt = vm.dt - 1
  end

  local opcode = VM.fetch(vm)

  VM.execute(vm, opcode)
end

function VM.execute(vm, opcode)
  -- We can determine which type of instruction from the first nybble
  -- of the opcode.
  local instr = opcode & 0xF000

  -- Keep track of whether we've jumped, so we can increment the program
  -- counter safely later.
  local jumped = false

  if instr == 0x0000 then
    -- 00E0 - CLS -- Clear the display.
    if opcode == 0x00E0 then
      for i = 0, VM.DISPLAY_WIDTH * VM.DISPLAY_HEIGHT - 1 do
        vm.display[i] = 0
      end

      vm.redraw = true

    -- 00EE - RET -- Return from a subroutine.
    elseif opcode == 0x00EE then
      vm.pc = vm.stack[vm.sp]
      vm.sp = vm.sp - 1

    else
      error(string.format("invalid opcode %X", opcode))
    end

  -- 1nnn - JP addr -- Jump to location nnn.
  elseif instr == 0x1000 then
    vm.pc = opcode & 0x0FFF
    jumped = true

  -- 2nnn - CALL addr -- Call subroutine at nnn.
  elseif instr == 0x2000 then
    vm.sp = vm.sp + 1
    vm.stack[vm.sp] = vm.pc
    vm.pc = opcode & 0x0FFF
    jumped = true

  -- 3xkk - SE Vx, byte -- Skip next instruction if Vx = kk.
  elseif instr == 0x3000 then
    local x = opcode >> 8 & 0x000F
    local kk = opcode & 0x00FF
    local vx = vm.registers[x]

    if vx == kk then
      vm.pc = vm.pc + 2
    end

  -- 4xkk - SNE Vx, byte -- Skip next instruction if Vx != kk.
  elseif instr == 0x4000 then
    local x = opcode >> 8 & 0x000F
    local kk = opcode & 0x00FF
    local vx = vm.registers[x]

    if vx ~= kk then
      vm.pc = vm.pc + 2
    end

  -- 5xy0 - SE Vx, Vy -- Skip next instruction if Vx = Vy.
  elseif instr == 0x5000 then
    local x = opcode >> 8 & 0x000F
    local y = opcode >> 4 & 0x000F
    local vx = vm.registers[x]
    local vy = vm.registers[y]

    if vx == vy then
      vm.pc = vm.pc + 2
    end

  -- 6xkk - LD Vx, byte -- Set Vx = kk.
  elseif instr == 0x6000 then
    local x = opcode >> 8 & 0x000F
    local kk = opcode & 0x00FF
    vm.registers[x] = kk

  -- 7xkk - ADD Vx, byte -- Set Vx = Vx + kk.
  elseif instr == 0x7000 then
    local x = opcode >> 8 & 0x000F
    local kk = opcode & 0x00FF
    vm.registers[x] = vm.registers[x] + kk

  elseif instr == 0x8000 then
    local mode = opcode & 0x000F
    local x = opcode >> 8 & 0x000F
    local y = opcode >> 4 & 0x000F
    local vx = vm.registers[x]
    local vy = vm.registers[y]

    -- 8xy0 - LD Vx, Vy -- Set Vx = Vy.
    if mode == 0x0000 then
      vm.registers[x] = vy

    -- 8xy1 - OR Vx, Vy -- Set Vx = Vx OR Vy.
    elseif mode == 0x0001 then
      vm.registers[x] = vx | vy

    -- 8xy2 - AND Vx, Vy -- Set Vx = Vx AND Vy.
    elseif mode == 0x0002 then
      vm.registers[x] = vx & vy

    -- 8xy3 - XOR Vx, Vy -- Set Vx = Vx XOR Vy.
    elseif mode == 0x0003 then
      vm.registers[x] = vx ~ vy

    -- 8xy4 - ADD Vx, Vy -- Set Vx = Vx + Vy, set VF = carry.
    elseif mode == 0x0004 then
      local val = vx + vy
      vm.registers[x] = val & 0xFF
      vm.registers[0xF] = val > 0xFF and 1 or 0

    -- 8xy5 - SUB Vx, Vy -- Set Vx = Vx - Vy, set VF = NOT borrow.
    elseif mode == 0x0005 then
      local val = vx - vy
      vm.registers[x] = math.abs(val)
      vm.registers[0xF] = val < 0 and 1 or 0

    -- 8xy6 - SHR Vx {, Vy} -- Set Vx = Vx SHR 1.
    elseif mode == 0x0006 then
      local lsb = vx & 1
      vm.registers[x] = vx >> 1
      vm.registers[0xF] = lsb

    -- 8xy7 - SUBN Vx, Vy -- Set Vx = Vy - Vx, set VF = NOT borrow.
    elseif mode == 0x0007 then
      local val = vy - vx
      vm.registers[x] = math.abs(val)
      vm.registers[0xF] = val < 0 and 1 or 0

    -- 8xyE - SHL Vx {, Vy} -- Set Vx = Vx SHL 1.
    elseif mode == 0x000E then
      local msb = vx >> 7
      vm.registers[x] = (vx << 1) & 0xFF
      vm.registers[0xF] = msb

    else
      error(string.format("invalid opcode %X", opcode), 2)
    end

  -- 9xy0 - SNE Vx, Vy -- Skip next instruction if Vx != Vy.
  elseif instr == 0x9000 then
    local x = opcode >> 8 & 0x000F
    local y = opcode >> 4 & 0x000F

    if vm.registers[x] ~= vm.registers[y] then
      vm.pc = vm.pc + 2
    end

  -- Annn - LD I, addr -- Set I = nnn.
  elseif instr == 0xA000 then
    vm.i = opcode & 0x0FFF

  -- Bnnn - JP V0, addr -- Jump to location nnn + V0.
  elseif instr == 0xB000 then
    vm.pc = (opcode & 0x0FFF) + vm.registers[0]
    jumped = true

  -- Cxkk - RND Vx, byte -- Set Vx = random byte AND kk.
  elseif instr == 0xC000 then
    local x = opcode >> 8 & 0x000F
    local kk = opcode & 0x00FF
    local val = math.random(0, 0xFF)
    vm.registers[x] = val & kk

  -- Dxyn - DRW Vx, Vy, nibble -- Display n-byte sprite starting at memory location I at (Vx, Vy), set VF = collision.
  elseif instr == 0xD000 then
    local x = opcode >> 8 & 0x000F
    local y = opcode >> 4 & 0x000F
    local n = opcode & 0x000F
    local vx = vm.registers[x]
    local vy = vm.registers[y]
    local collision = false

    -- we need to redraw the display
    vm.redraw = true

    -- for each byte in the sprite
    for i = 0, n do
      local byte = vm.memory[vm.i + i]

      -- for each bit in the byte
      for j = 0, 7 do
        local bit = byte >> (7 - j) & 0x1

        local dx = vx + j
        local dy = vy + i

        -- wrap around if pixels are drawn offscreen

        if dx < 0 then
          dx = VM.DISPLAY_WIDTH + dx
        end

        if dy < 0 then
          dy = VM.DISPLAY_HEIGHT + dy
        end

        if dx >= VM.DISPLAY_WIDTH then
          dx = dx - VM.DISPLAY_WIDTH
        end

        if dy >= VM.DISPLAY_HEIGHT then
          dy = dy - VM.DISPLAY_HEIGHT
        end

        local index = dx + dy * VM.DISPLAY_WIDTH
        local old_bit = vm.display[index]
        local new_bit = old_bit ~ bit

        vm.display[index] = new_bit

        -- flag a collision if an existing cell was erased
        if new_bit == 0 and old_bit == 1 then
          collision = true
        end
      end
    end

    vm.registers[0xF] = collision and 1 or 0

  elseif instr == 0xE000 then
    local mode = opcode & 0x00FF
    local x = opcode >> 8 & 0x000F
    local vx = vm.registers[x]

    -- Ex9E - SKP Vx -- Skip next instruction if key with the value of Vx is pressed.
    if mode == 0x009E then
      if vm.keyboard[vx] then
        vm.pc = vm.pc + 2
      end

    -- ExA1 - SKNP Vx -- Skip next instruction if key with the value of Vx is not pressed.
    elseif mode == 0x00A1 then
      if not vm.keyboard[vx] then
        vm.pc = vm.pc + 2
      end

    else
      error(string.format("invalid opcode %X", opcode))
    end

  elseif instr == 0xF000 then
    local mode = opcode & 0x00FF
    local x = opcode >> 8 & 0x000F
    local vx = vm.registers[x]

    -- Fx07 - LD Vx, DT -- Set Vx = delay timer value.
    if mode == 0x0007 then
      vm.registers[x] = vm.dt

    -- Fx0A - LD Vx, K -- Wait for a key press, store the value of the key in Vx.
    elseif mode == 0x000A then
      local pressed = false

      for i = 0, 15 do
        if vm.keyboard[i] then
          pressed = true
          vm.registers[x] = i
          break
        end
      end

      if pressed == false then
        return
      end

    -- Fx15 - LD DT, Vx -- Set delay timer = Vx.
    elseif mode == 0x0015 then
      vm.dt = vx

    -- Fx18 - LD ST, Vx -- Set sound timer = Vx.
    elseif mode == 0x0018 then
      vm.st = vx

    -- Fx1E - ADD I, Vx -- Set I = I + Vx.
    elseif mode == 0x001E then
      vm.i = vm.i + vx

    -- Fx29 - LD F, Vx -- Set I = location of sprite for digit Vx.
    elseif mode == 0x0029 then
      vm.i = vx * 5 -- each sprite is 5 bytes long

    -- Fx33 - LD B, Vx -- Store BCD representation of Vx in memory locations I, I+1, and I+2.
    elseif mode == 0x0033 then
      local hundreds = math.floor(vx / 100)
      local tens = math.floor((vx % 100) / 10)
      local ones = vx % 10
      vm.memory[vm.i] = hundreds
      vm.memory[vm.i + 1] = tens
      vm.memory[vm.i + 2] = ones

    -- Fx55 - LD [I], Vx -- Store registers V0 through Vx in memory starting at location I.
    elseif mode == 0x0055 then
      for i = 0, x do
        vm.memory[vm.i + i] = vm.registers[i]
      end

    -- Fx65 - LD Vx, [I] -- Read registers V0 through Vx from memory starting at location I.
    elseif mode == 0x0065 then
      for i = 0, x do
        vm.registers[i] = vm.memory[vm.i + i]
      end

    else
      error(string.format("invalid opcode %X", opcode))
    end

  else
    error(string.format("invalid opcode %X", opcode))
  end

  if not jumped then
    vm.pc = vm.pc + 2
  end
end

function VM.print_display(vm)
  for y = 0, VM.DISPLAY_HEIGHT - 1 do
    for x = 0, VM.DISPLAY_WIDTH -1 do
      local i = x + y * VM.DISPLAY_WIDTH
      local cell = vm.display[i]

      if cell == 1 then
        io.write("#")
      else
        io.write(" ")
      end
    end

    io.write("\n")
  end
end

function VM.print_stack(vm)
  if vm.sp == 0 then
    print("(empty)")
  else
    for i = 1, vm.sp do
      io.write(string.format("%1x = %4x", i, vm.stack[i]))

      if vm.sp == i then
        io.write("  <-- SP")
      end

      io.write("\n")
    end
  end
end

function VM.print_registers(vm)
  for i = 0, 15 do
    print(string.format("v%1x = %04x", i, vm.registers[i]))
  end
end

return VM
