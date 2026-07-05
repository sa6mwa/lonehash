local core = require("lonehash.core")

local lonehash = {
  version = core.version,
}

function lonehash.sha256()
  return core.sha256()
end

function lonehash.md5()
  return core.md5()
end

function lonehash.sha256_hex(data)
  return core.sha256():digest_hex(data)
end

function lonehash.md5_hex(data)
  return core.md5():digest_hex(data)
end

function lonehash.sha256_file_hex(path)
  return core.sha256():file_hex(path)
end

function lonehash.md5_file_hex(path)
  return core.md5():file_hex(path)
end

function lonehash.sha256_digest(data)
  return core.sha256():digest(data)
end

function lonehash.md5_digest(data)
  return core.md5():digest(data)
end

function lonehash.sha256_file(path)
  return core.sha256():file(path)
end

function lonehash.md5_file(path)
  return core.md5():file(path)
end

return lonehash
