local gl = require "moongl"
local glfw = require "moonglfw"
local VM = require "./vm"

local CELL_WIDTH = 5
local CELL_HEIGHT = 5
local WINDOW_WIDTH = VM.DISPLAY_WIDTH * CELL_WIDTH
local WINDOW_HEIGHT = VM.DISPLAY_HEIGHT * CELL_HEIGHT

local key_map = {
  ["0"] = 0x0,
  ["1"] = 0x1,
  ["2"] = 0x2,
  ["3"] = 0x3,
  ["4"] = 0x4,
  ["5"] = 0x5,
  ["6"] = 0x6,
  ["7"] = 0x7,
  ["8"] = 0x8,
  ["9"] = 0x9,
  ["a"] = 0xA,
  ["b"] = 0xB,
  ["c"] = 0xC,
  ["d"] = 0xD,
  ["e"] = 0xE,
  ["f"] = 0xF,
}

local vm = VM.new()

local a_position = 0
local a_color = 1

local vertex_shader_source = string.format([[
#version 330 core

layout(location=%d) in vec4 a_position;
layout(location=%d) in float a_color;

out vec4 v_color;

void main() {
   gl_Position = a_position;
   v_color = vec4(a_color, a_color, a_color, 1);
}
]], a_position, a_color)

local fragment_shader_source = [[
#version 330 core

in vec4 v_color;

out vec4 out_Color;

void main() {
  out_Color = v_color;
}
]]

local window
local program

local position_buffer = {}
local color_buffer = {}

local vao
local vbo_positions
local vbo_colors

local function init_cell_vertices()
  -- Each cell is rendered as a unit quad. We only need to generate the
  -- vertices for the display once.
  --
  -- A---B
  -- |  /|
  -- | / |
  -- |/  |
  -- C---D

  local width = VM.DISPLAY_WIDTH
  local height = VM.DISPLAY_HEIGHT
  local cell_width = 1 / width * 2
  local cell_height = 1 / height * 2

  local position_buffer_index = 1

  for x = 0, width - 1 do
    for y = 0, height - 1 do
      -- cell coords in clip space
      local x1 = x / width * 2 - 1
      local y1 = y / height * 2 - 1
      local x2 = x1 + cell_width
      local y2 = y1 + cell_height

      y1 = y1 * -1
      y2 = y2 * -1

      -- A
      position_buffer[position_buffer_index + 0] = x1
      position_buffer[position_buffer_index + 1] = y1
      -- B
      position_buffer[position_buffer_index + 2] = x2
      position_buffer[position_buffer_index + 3] = y1
      -- C
      position_buffer[position_buffer_index + 4] = x1
      position_buffer[position_buffer_index + 5] = y2

      -- B
      position_buffer[position_buffer_index + 6] = x2
      position_buffer[position_buffer_index + 7] = y1
      -- D
      position_buffer[position_buffer_index + 8] = x2
      position_buffer[position_buffer_index + 9] = y2
      -- C
      position_buffer[position_buffer_index + 10] = x1
      position_buffer[position_buffer_index + 11] = y2

      position_buffer_index = position_buffer_index + 12
    end
  end
end

local function flush_display()
  -- Update the color buffer from the display

  local color_buffer_index = 1

  for x = 0, VM.DISPLAY_WIDTH - 1 do
    for y = 0, VM.DISPLAY_HEIGHT - 1 do
      local cell_index = x + y * VM.DISPLAY_WIDTH
      local color = vm.display[cell_index]

      color_buffer[color_buffer_index + 0] = color
      color_buffer[color_buffer_index + 1] = color
      color_buffer[color_buffer_index + 2] = color
      color_buffer[color_buffer_index + 3] = color
      color_buffer[color_buffer_index + 4] = color
      color_buffer[color_buffer_index + 5] = color
      color_buffer_index = color_buffer_index + 6
    end
  end
end

local function render_display()
  gl.clear_color(0, 0, 0, 1)
  gl.clear("color")

  local vertex_count = VM.DISPLAY_WIDTH * VM.DISPLAY_HEIGHT * 3 * 2

  gl.use_program(program)
  gl.bind_vertex_array(vao)

  gl.bind_buffer("array", vbo_colors)
  gl.buffer_data("array", gl.pack("float", color_buffer), "static draw")
  gl.vertex_attrib_pointer(a_color, 1, "float", false, 0, 0)
  gl.unbind_buffer("array")

  gl.draw_arrays("triangles", 0, vertex_count)
  gl.unbind_vertex_array()
end

local function handle_key(window, key, scancode, action)
  local key_index = key_map[key]

  if key_index then
    if action == "press" then
      vm.keyboard[key_index] = true
    elseif action == "release" then
      vm.keyboard[key_index] = false
    end
  end
end

local function init()
  glfw.window_hint("context version major", 3)
  glfw.window_hint("context version minor", 3)
  glfw.window_hint("opengl profile", "core")

  window = glfw.create_window(WINDOW_WIDTH, WINDOW_HEIGHT, "Chip-8 Emulator")
  glfw.set_key_callback(window, handle_key)
  glfw.make_context_current(window)
  gl.init()

  program = gl.make_program_s(
    "vertex", vertex_shader_source,
    "fragment", fragment_shader_source
  )

  local screen_width, screen_height = glfw.get_framebuffer_size(window)
  gl.viewport(0, 0, screen_width, screen_height)

  -- Create an array of vertex buffers
  vao = gl.new_vertex_array()

  -- Position attribute
  vbo_positions = gl.new_buffer("array")
  init_cell_vertices()
  gl.buffer_data("array", gl.pack("float", position_buffer), "static draw")
  gl.vertex_attrib_pointer(a_position, 2, "float", false, 0, 0)
  gl.enable_vertex_attrib_array(a_position)
  gl.unbind_buffer("array")

  -- Color attribute
  vbo_colors = gl.new_buffer("array")
  gl.enable_vertex_attrib_array(a_color)
  gl.unbind_buffer("array")
  gl.unbind_vertex_array()
end

local function start()
  while not glfw.window_should_close(window) do
    glfw.poll_events()

    pcall(function()
      VM.emulate(vm)
    end)

    if vm.redraw then
      vm.redraw = false
      flush_display()
      render_display()
      glfw.swap_buffers(window)
    end
  end

  gl.delete_buffers(vbo_pos)
  gl.delete_buffers(vbo_col)
  gl.delete_vertex_arrays(vao)
  gl.clean_program(prog)
end

local function load_from_disk(path)
  VM.load_from_disk(vm, path)
end

return {
  init = init,
  start = start,
  load_from_disk = load_from_disk,
}
