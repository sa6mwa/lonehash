local lonehash = require("lonehash")

local function basename(path)
  return (path:gsub("\\", "/"):match("([^/]+)$")) or path
end

local function usage(out, prog)
  out:write(("usage: %s [--sha256|-s] [--md5|-5] [-q] [-z] [FILE]...\n"):format(prog))
end

local function parse_short(arg, opts, prog)
  for i = 2, #arg do
    local ch = arg:sub(i, i)
    if ch == "5" then
      opts.alg = "md5"
    elseif ch == "s" then
      opts.alg = "sha256"
    elseif ch == "q" then
      opts.quiet = true
    elseif ch == "z" then
      opts.nul = true
    else
      io.stderr:write(("%s: unknown option: -%s\n"):format(prog, ch))
      usage(io.stderr, prog)
      os.exit(2)
    end
  end
end

local function hash_stdin(alg)
  local h = alg == "md5" and lonehash.md5() or lonehash.sha256()
  while true do
    local chunk = io.stdin:read(32768)
    if not chunk then
      break
    end
    h:update(chunk)
  end
  return h:final_hex()
end

local function hash_file(alg, path)
  if path == "-" then
    return hash_stdin(alg)
  end
  if alg == "md5" then
    return lonehash.md5_file_hex(path)
  end
  return lonehash.sha256_file_hex(path)
end

local function print_sum(hex, name, nul)
  io.stdout:write(hex, "  ", name, nul and "\0" or "\n")
end

local function print_quiet(hex, nul)
  io.stdout:write(hex)
  if not nul then
    io.stdout:write("\n")
  end
end

local argv = arg or {}
local prog = basename(argv[0] or "lh.lua")
local opts = { alg = prog == "md5sum" and "md5" or "sha256", quiet = false, nul = false }
local first_file = #argv + 1

local i = 1
while i <= #argv do
  local a = argv[i]
  if a == "--" then
    first_file = i + 1
    break
  elseif a == "--help" then
    usage(io.stdout, prog)
    os.exit(0)
  elseif a == "--md5" or a == "-5" then
    opts.alg = "md5"
  elseif a == "--sha256" or a == "-s" then
    opts.alg = "sha256"
  elseif a == "--quiet" or a == "-q" then
    opts.quiet = true
  elseif a == "-z" then
    opts.nul = true
  elseif a:sub(1, 1) == "-" and a ~= "-" then
    parse_short(a, opts, prog)
  else
    first_file = i
    break
  end
  i = i + 1
end

if first_file > #argv then
  local ok, hex = pcall(hash_stdin, opts.alg)
  if not ok then
    io.stderr:write(("%s: stdin: read failed\n"):format(prog))
    os.exit(1)
  end
  if opts.quiet then
    print_quiet(hex, opts.nul)
  else
    print_sum(hex, "-", opts.nul)
  end
  os.exit(0)
end

if opts.quiet and (#argv - first_file + 1) ~= 1 then
  io.stderr:write(("%s: --quiet requires stdin or exactly one FILE\n"):format(prog))
  os.exit(2)
end

local failed = false
for j = first_file, #argv do
  local path = argv[j]
  local ok, hex = pcall(hash_file, opts.alg, path)
  if not ok then
    io.stderr:write(("%s: %s: read failed\n"):format(prog, path))
    failed = true
  elseif opts.quiet then
    print_quiet(hex, opts.nul)
  else
    print_sum(hex, path == "-" and "-" or path, opts.nul)
  end
end

os.exit(failed and 1 or 0)
