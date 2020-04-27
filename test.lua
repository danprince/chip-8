test = require "luaunit"
VM = require "./vm"

function test_new()
  local vm = VM.new()
  test.assertEquals(vm.pc, 0x200)
end

function test_load()
  local vm = VM.new()

  VM.load(vm, { 0x1122, 0x3344, 0x5566 })

  test.assertEquals(vm.memory[0x200], 0x11)
  test.assertEquals(vm.memory[0x201], 0x22)

  test.assertEquals(vm.memory[0x202], 0x33)
  test.assertEquals(vm.memory[0x203], 0x44)

  test.assertEquals(vm.memory[0x204], 0x55)
  test.assertEquals(vm.memory[0x205], 0x66)
end

function test_invalid_opcode()
  local vm = VM.new()
  VM.load(vm, { 0x0000 })
  test.assertError(function() VM.emulate(vm) end)
end

function test_CLS_00E0()
  local vm = VM.new()

  vm.display[0x55] = 1

  VM.load(vm, { 0x00E0 })
  VM.emulate(vm)

  test.assertEquals(vm.display[0x55], 0)
end

function test_RET_00EE()
  local vm = VM.new()

  -- setup a pretend call on the stack so there is somewhere to return to
  vm.stack[1] = 0x5
  vm.sp = 1

  VM.load(vm, { 0x00EE })
  VM.emulate(vm)

  test.assertEquals(vm.pc, 0x7)
  test.assertEquals(vm.sp, 0)
end

function test_JP_1nnn()
  local vm = VM.new()
  VM.load(vm, { 0x1444 })
  VM.emulate(vm)
  test.assertEquals(vm.pc, 0x444)
end

function test_CALL_2nnn()
  local vm = VM.new()
  VM.load(vm, { 0x2444 })
  VM.emulate(vm)
  test.assertEquals(vm.sp, 1)
  test.assertEquals(vm.stack, { 0x200 })
  test.assertEquals(vm.pc, 0x444)
end

function test_SE_3xkk()
  local vm = VM.new()
  local pc = vm.pc;

  vm.registers[0] = 0x11

  -- skip next instruction if v0 is 0x11
  VM.load(vm, { 0x3011 })

  VM.emulate(vm)

  -- Should have skipped the next instruction
  test.assertEquals(vm.pc, pc + 4)
end

function test_SE_3xkk_alt()
  local vm = VM.new()
  local pc = vm.pc;

  vm.registers[0] = 0x22

  -- skip next instruction if v0 is 0x11
  VM.load(vm, { 0x3011 })

  VM.emulate(vm)

  -- Should not have skipped the next instruction
  test.assertEquals(vm.pc, pc + 2)
end

function test_SNE_4xkk()
  local vm = VM.new()
  local pc = vm.pc;

  vm.registers[0] = 0x22

  -- skip next instruction if v0 is not 0x11
  VM.load(vm, { 0x4011 })

  VM.emulate(vm)

  -- Should have skipped the next instruction
  test.assertEquals(vm.pc, pc + 4)
end

function test_SNE_4xkk_alt()
  local vm = VM.new()
  local pc = vm.pc;

  vm.registers[0] = 0x11

  -- skip next instruction if v0 is not 0x11
  VM.load(vm, { 0x4011 })

  VM.emulate(vm)

  -- Should not have skipped the next instruction
  test.assertEquals(vm.pc, pc + 2)
end

function test_SE_5xy0()
  local vm = VM.new()
  local pc = vm.pc;

  vm.registers[1] = 0x22
  vm.registers[2] = 0x22

  -- skip next instruction if v1 = v2
  VM.load(vm, { 0x5120 })

  VM.emulate(vm)

  -- Should have skipped the next instruction
  test.assertEquals(vm.pc, pc + 4)
end

function test_SE_5xy0()
  local vm = VM.new()
  local pc = vm.pc;

  vm.registers[1] = 0x11
  vm.registers[2] = 0x22

  -- skip next instruction if v1 = v2
  VM.load(vm, { 0x5120 })

  VM.emulate(vm)

  -- Should not have skipped the next instruction
  test.assertEquals(vm.pc, pc + 2)
end

function test_LD_6xkk()
  local vm = VM.new()

  -- load 0x99 into v1
  VM.load(vm, { 0x6199 })
  VM.emulate(vm)

  test.assertEquals(vm.registers[1], 0x99)
end

function test_ADD_7xkk()
  local vm = VM.new()
  vm.registers[1] = 0x08

  -- add 0x08 to v1
  VM.load(vm, { 0x7108 })
  VM.emulate(vm)

  test.assertEquals(vm.registers[1], 0x10)
end

function test_LD_8xy0()
  local vm = VM.new()
  vm.registers[1] = 0x0
  vm.registers[2] = 0xF

  -- set vx to vy
  VM.load(vm, { 0x8120 })
  VM.emulate(vm)

  test.assertEquals(vm.registers[1], 0xF)
end

function test_OR_8xy1()
  local a = tonumber("10101010", 2)
  local b = tonumber("01010101", 2)
  local c = tonumber("11111111", 2)

  local vm = VM.new()
  vm.registers[1] = a
  vm.registers[2] = b

  -- set vx to vx OR vy
  VM.load(vm, { 0x8121 })
  VM.emulate(vm)

  test.assertEquals(vm.registers[1], c)
end

function test_AND_8xy2()
  local a = tonumber("11111000", 2)
  local b = tonumber("00011111", 2)
  local c = tonumber("00011000", 2)

  local vm = VM.new()
  vm.registers[1] = a
  vm.registers[2] = b

  -- set vx to vx AND vy
  VM.load(vm, { 0x8122 })
  VM.emulate(vm)

  test.assertEquals(vm.registers[1], c)
end

function test_XOR_8xy3()
  local a = tonumber("11111111", 2)
  local b = tonumber("10101010", 2)
  local c = tonumber("01010101", 2)

  local vm = VM.new()
  vm.registers[1] = a
  vm.registers[2] = b

  -- set vx to vx XOR vy
  VM.load(vm, { 0x8123 })
  VM.emulate(vm)

  test.assertEquals(vm.registers[1], c)
end

function test_ADD_8xy4()
  local vm = VM.new()
  vm.registers[1] = 0x3
  vm.registers[2] = 0x7

  -- set vx to vx + vy
  VM.load(vm, { 0x8124 })
  VM.emulate(vm)

  test.assertEquals(vm.registers[1], 0xA)
  test.assertEquals(vm.registers[0xF], 0x0)
end

function test_ADD_8xy4_overflow()
  local vm = VM.new()
  vm.registers[1] = 0xFF
  vm.registers[2] = 0x1

  -- set vx to vx + vy
  VM.load(vm, { 0x8124 })
  VM.emulate(vm)

  test.assertEquals(vm.registers[1], 0x0)
  test.assertEquals(vm.registers[0xF], 0x1)
end

function test_SUB_8xy5()
  local vm = VM.new()
  vm.registers[1] = 0xFF
  vm.registers[2] = 0x1

  -- set vx to vx - vy
  VM.load(vm, { 0x8125 })
  VM.emulate(vm)

  test.assertEquals(vm.registers[1], 0xFE)
  test.assertEquals(vm.registers[0xF], 0x0)
end

function test_SUB_8xy5_overflow()
  local vm = VM.new()
  vm.registers[1] = 0x2
  vm.registers[2] = 0x4

  -- set vx to vx - vy
  VM.load(vm, { 0x8125 })
  VM.emulate(vm)

  test.assertEquals(vm.registers[1], 0x2)
  test.assertEquals(vm.registers[0xF], 0x1)
end

function test_SHR_8xy6()
  local a = tonumber("00001000", 2)
  local b = tonumber("00000100", 2)

  local vm = VM.new()
  vm.registers[1] = a

  -- set v1 to v1 >> 1
  VM.load(vm, { 0x8126 })
  VM.emulate(vm)

  test.assertEquals(vm.registers[1], b)

  -- should NOT have overflow
  test.assertEquals(vm.registers[0xF], 0x0)
end

function test_SHR_8xy6_overflow()
  local a = tonumber("00000001", 2)
  local b = tonumber("00000000", 2)

  local vm = VM.new()
  vm.registers[1] = a

  -- set v1 to v1 >> 1
  VM.load(vm, { 0x8126 })
  VM.emulate(vm)

  test.assertEquals(vm.registers[1], b)

  -- should have overflow
  test.assertEquals(vm.registers[0xF], 0x1)
end

function test_SUBN_8xy7()
  local vm = VM.new()
  vm.registers[1] = 0x01
  vm.registers[2] = 0xFF

  -- set v1 to v2 - v1
  VM.load(vm, { 0x8127 })
  VM.emulate(vm)

  test.assertEquals(vm.registers[1], 0xFE)

  -- should NOT have overflow
  test.assertEquals(vm.registers[0xF], 0x0)
end

function test_SUBN_8xy7_overflow()
  local vm = VM.new()
  vm.registers[1] = 0x4
  vm.registers[2] = 0x2

  -- set v1 to v2 - v1
  VM.load(vm, { 0x8127 })
  VM.emulate(vm)

  test.assertEquals(vm.registers[1], 0x2)

  -- should have overflow
  test.assertEquals(vm.registers[0xF], 0x1)
end

function test_SHL_8xy8()
  local a = tonumber("00000001", 2)
  local b = tonumber("00000010", 2)

  local vm = VM.new()
  vm.registers[1] = a

  -- set v1 to v1 << 1
  VM.load(vm, { 0x812E })
  VM.emulate(vm)

  test.assertEquals(vm.registers[1], b)

  -- should NOT have overflow
  test.assertEquals(vm.registers[0xF], 0x0)
end

function test_SHL_8xy6_overflow()
  local a = tonumber("10000000", 2)
  local b = tonumber("00000000", 2)

  local vm = VM.new()
  vm.registers[1] = a

  -- set v1 to v1 << 1
  VM.load(vm, { 0x812E })
  VM.emulate(vm)

  test.assertEquals(vm.registers[1], b)

  -- should have overflow
  test.assertEquals(vm.registers[0xF], 0x1)
end

function test_8XXX_invalid()
  local vm = VM.new()
  VM.load(vm, { 0x812D })
  test.assertError(function() VM.emulate(vm) end)
end

function test_SNE_9xy0()
  local vm = VM.new()
  local pc = vm.pc
  vm.registers[1] = 0x3
  vm.registers[2] = 0x5

  -- skip next instruction if v1 != v2
  VM.load(vm, { 0x9120 })
  VM.emulate(vm)

  test.assertEquals(vm.pc, pc + 4)
end

function test_SNE_9xy0_alt()
  local vm = VM.new()
  local pc = vm.pc
  vm.registers[1] = 0x3
  vm.registers[2] = 0x3

  -- skip next instruction if v1 != v2
  VM.load(vm, { 0x9120 })
  VM.emulate(vm)

  test.assertEquals(vm.pc, pc + 2)
end

function test_LD_Annn()
  local vm = VM.new()

  -- set register i to 123
  VM.load(vm, { 0xA123 })
  VM.emulate(vm)

  test.assertEquals(vm.i, 0x123)
end

function test_JP_Bnnn()
  local vm = VM.new()

  vm.registers[0] = 0x1

  -- jump to 123 + v0
  VM.load(vm, { 0xB123 })
  VM.emulate(vm)

  test.assertEquals(vm.pc, 0x124)
end

function test_RND_Cxkk()
  local vm = VM.new()

  -- set v0 to random AND 0xFF
  VM.load(vm, { 0xC0FF })
  VM.emulate(vm)

  test.assertNotEquals(vm.registers[0], 0x0)
end

function test_DRW_Dxyn()
  local vm = VM.new()

  vm.i = 0x300
  vm.memory[0x300] = tonumber("01000000", 2)
  vm.memory[0x301] = tonumber("10000000", 2)
  vm.registers[0] = 0
  vm.registers[1] = 0

  -- read 2 bytes from memory, starting at i and draw them at v0, v1
  VM.load(vm, { 0xD012 })
  VM.emulate(vm)

  test.assertEquals(vm.display[1], 1)
  test.assertEquals(vm.display[64], 1)

  -- should NOT have erased any existing cells
  test.assertEquals(vm.registers[0xf], 0)
end

function test_DRW_Dxyn_wrap()
  local vm = VM.new()

  vm.i = 0x300
  vm.memory[0x300] = tonumber("10000001", 2)
  vm.registers[0] = 63
  vm.registers[1] = 0

  -- read 1 bytes from memory, starting at i and draw them at v0, v1
  VM.load(vm, { 0xD011 })
  VM.emulate(vm)

  test.assertEquals(vm.display[63], 1)
  test.assertEquals(vm.display[6], 1)

  -- should NOT have erased any existing cells
  test.assertEquals(vm.registers[0xf], 0)
end

function test_DRW_Dxyn_collision()
  local vm = VM.new()

  vm.i = 0x300
  vm.memory[0x300] = tonumber("10000000", 2)
  vm.registers[0] = 0
  vm.registers[1] = 0
  vm.display[0] = 1

  -- read 1 bytes from memory, starting at i and draw them at v0, v1
  VM.load(vm, { 0xD011 })
  VM.emulate(vm)

  test.assertEquals(vm.display[0], 0)

  -- should have erased existing cells
  test.assertEquals(vm.registers[0xf], 1)
end

function test_SKP_Ex9E_pressed()
  local vm = VM.new()
  local pc = vm.pc

  vm.registers[0] = 0x3
  vm.keyboard[0x3] = true

  -- skip instruction if key in v0 is pressed
  VM.load(vm, { 0xE09E })
  VM.emulate(vm)

  test.assertEquals(vm.pc, pc + 4)
end

function test_SKP_Ex9E_not_pressed()
  local vm = VM.new()
  local pc = vm.pc

  vm.registers[0] = 0x3
  vm.keyboard[0x3] = false

  -- skip instruction if key in v0 is pressed
  VM.load(vm, { 0xE09E })
  VM.emulate(vm)

  test.assertEquals(vm.pc, pc + 2)
end

function test_EXXX_invalid()
  local vm = VM.new()
  VM.load(vm, { 0xE0FF })
  test.assertError(function() VM.emulate(vm) end)
end

function test_LD_Fx07()
  local vm = VM.new()
  vm.dt = 10

  -- set v1 to dt
  VM.load(vm, { 0xF107 })
  VM.emulate(vm)

  test.assertEquals(vm.registers[1], 10)
end

function test_LD_Fx0A()
  local vm = VM.new()
  local pc = vm.pc

  -- store the value of next key press in v1
  VM.load(vm, { 0xF10A })

  -- should not advance with no keys pressed
  VM.emulate(vm)
  test.assertEquals(vm.pc, pc)
  test.assertEquals(vm.registers[1], 0)

  -- press the 3 key
  vm.keyboard[0x3] = true

  -- should advance and store the key
  VM.emulate(vm)
  test.assertEquals(vm.pc, pc + 2)
  test.assertEquals(vm.registers[1], 0x3)
end

function test_LD_Fx15()
  local vm = VM.new()
  vm.registers[0] = 0x8

  -- set dt to v0
  VM.load(vm, { 0xF015 })
  VM.emulate(vm)

  -- delay timer will have decreased by 1 after the cycle finished
  test.assertEquals(vm.dt, 0x7)
end

function test_LD_Fx18()
  local vm = VM.new()
  vm.registers[0] = 0x8

  -- set st to v0
  VM.load(vm, { 0xF018 })
  VM.emulate(vm)

  -- sound timer will have decreased by 1 after the cycle finished
  test.assertEquals(vm.st, 0x7)
end

function test_ADD_Fx1E()
  local vm = VM.new()
  vm.i = 0x3
  vm.registers[0] = 0x5

  -- increment i by v0
  VM.load(vm, { 0xF01E })
  VM.emulate(vm)

  test.assertEquals(vm.i, 0x8)
end

function test_LD_Fx29()
  local vm = VM.new()

  vm.registers[1] = 3

  -- set i to address of sprite in v1
  VM.load(vm, { 0xF129 })
  VM.emulate(vm)

  test.assertEquals(vm.i, 0xF)
end

function test_LD_Fx33()
  local vm = VM.new()
  vm.registers[0] = 0xFF
  vm.i = 0x33

  -- store BCD of 0xFF in memory
  VM.load(vm, { 0xF033 })
  VM.emulate(vm)

  test.assertEquals(vm.memory[0x33], 2)
  test.assertEquals(vm.memory[0x34], 5)
  test.assertEquals(vm.memory[0x35], 5)
end

function test_LD_Fx55()
  local vm = VM.new()
  vm.registers[0x0] = 0x0
  vm.registers[0x1] = 0x1
  vm.registers[0x2] = 0x2
  vm.registers[0x3] = 0x3
  vm.i = 0x33

  -- store registers 0-3 in memory
  VM.load(vm, { 0xF355 })
  VM.emulate(vm)

  test.assertEquals(vm.memory[0x33], 0x0)
  test.assertEquals(vm.memory[0x34], 0x1)
  test.assertEquals(vm.memory[0x35], 0x2)
  test.assertEquals(vm.memory[0x36], 0x3)
end

function test_LD_Fx65()
  local vm = VM.new()
  vm.memory[0x30] = 0x0
  vm.memory[0x31] = 0x1
  vm.memory[0x32] = 0x2
  vm.memory[0x33] = 0x3
  vm.i = 0x30

  -- read registers 0-3 from memory
  VM.load(vm, { 0xF365 })
  VM.emulate(vm)

  test.assertEquals(vm.registers[0x0], 0x0)
  test.assertEquals(vm.registers[0x1], 0x1)
  test.assertEquals(vm.registers[0x2], 0x2)
  test.assertEquals(vm.registers[0x3], 0x3)
end

function test_FXXX_invalid()
  local vm = VM.new()
  VM.load(vm, { 0xF066 })
  test.assertError(function() VM.emulate(vm) end)
end

os.exit(test.LuaUnit.run())
