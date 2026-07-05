local lonehash = require("lonehash")

local path = assert(arg[1], "usage: lua hash_file.lua FILE")
print(lonehash.sha256_file_hex(path))
