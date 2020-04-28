emulator = require "./emulator"

emulator.init()
emulator.load_from_disk("rom/hello_keyboard.rom")
emulator.start()
