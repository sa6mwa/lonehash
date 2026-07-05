#include "lonehash/lonehash.h"

#include <lauxlib.h>
#include <lua.h>

#include <string.h>

typedef struct lh_lua_sha256 {
  lonehash_sha256 *hash;
} lh_lua_sha256;

typedef struct lh_lua_md5 {
  lonehash_md5 *hash;
} lh_lua_md5;

static int lh_lua_error(lua_State *L, lonehash_status status) {
  return luaL_error(L, "%s", lonehash_status_string(status));
}

static lonehash_sha256 *lh_lua_check_sha256(lua_State *L, int index) {
  lh_lua_sha256 *self;

  self = (lh_lua_sha256 *)luaL_checkudata(L, index, "lonehash.sha256");
  luaL_argcheck(L, self->hash != 0, index, "closed sha256 handle");
  return self->hash;
}

static lonehash_md5 *lh_lua_check_md5(lua_State *L, int index) {
  lh_lua_md5 *self;

  self = (lh_lua_md5 *)luaL_checkudata(L, index, "lonehash.md5");
  luaL_argcheck(L, self->hash != 0, index, "closed md5 handle");
  return self->hash;
}

static int lh_lua_sha256_new(lua_State *L) {
  lh_lua_sha256 *self;
  lonehash_status status;

  self = (lh_lua_sha256 *)lua_newuserdatauv(L, sizeof(*self), 0);
  self->hash = 0;
  luaL_getmetatable(L, "lonehash.sha256");
  lua_setmetatable(L, -2);
  status = lonehash_sha256_create(&self->hash);
  if (status != LONEHASH_OK) {
    return lh_lua_error(L, status);
  }
  return 1;
}

static int lh_lua_md5_new(lua_State *L) {
  lh_lua_md5 *self;
  lonehash_status status;

  self = (lh_lua_md5 *)lua_newuserdatauv(L, sizeof(*self), 0);
  self->hash = 0;
  luaL_getmetatable(L, "lonehash.md5");
  lua_setmetatable(L, -2);
  status = lonehash_md5_create(&self->hash);
  if (status != LONEHASH_OK) {
    return lh_lua_error(L, status);
  }
  return 1;
}

static int lh_lua_sha256_gc(lua_State *L) {
  lh_lua_sha256 *self;

  self = (lh_lua_sha256 *)luaL_checkudata(L, 1, "lonehash.sha256");
  lonehash_sha256_destroy(self->hash);
  self->hash = 0;
  return 0;
}

static int lh_lua_md5_gc(lua_State *L) {
  lh_lua_md5 *self;

  self = (lh_lua_md5 *)luaL_checkudata(L, 1, "lonehash.md5");
  lonehash_md5_destroy(self->hash);
  self->hash = 0;
  return 0;
}

static int lh_lua_sha256_reset(lua_State *L) {
  lonehash_sha256 *hash;
  lonehash_status status;

  hash = lh_lua_check_sha256(L, 1);
  status = hash->reset(hash);
  if (status != LONEHASH_OK) {
    return lh_lua_error(L, status);
  }
  lua_settop(L, 1);
  return 1;
}

static int lh_lua_md5_reset(lua_State *L) {
  lonehash_md5 *hash;
  lonehash_status status;

  hash = lh_lua_check_md5(L, 1);
  status = hash->reset(hash);
  if (status != LONEHASH_OK) {
    return lh_lua_error(L, status);
  }
  lua_settop(L, 1);
  return 1;
}

static int lh_lua_sha256_update(lua_State *L) {
  lonehash_sha256 *hash;
  const char *data;
  size_t len;
  lonehash_status status;

  hash = lh_lua_check_sha256(L, 1);
  data = luaL_checklstring(L, 2, &len);
  status = hash->update(hash, data, len);
  if (status != LONEHASH_OK) {
    return lh_lua_error(L, status);
  }
  lua_settop(L, 1);
  return 1;
}

static int lh_lua_md5_update(lua_State *L) {
  lonehash_md5 *hash;
  const char *data;
  size_t len;
  lonehash_status status;

  hash = lh_lua_check_md5(L, 1);
  data = luaL_checklstring(L, 2, &len);
  status = hash->update(hash, data, len);
  if (status != LONEHASH_OK) {
    return lh_lua_error(L, status);
  }
  lua_settop(L, 1);
  return 1;
}

static int lh_lua_sha256_final(lua_State *L) {
  lonehash_sha256 *hash;
  unsigned char digest[LONEHASH_SHA256_DIGEST_SIZE];
  lonehash_status status;

  hash = lh_lua_check_sha256(L, 1);
  status = hash->final(hash, digest);
  if (status != LONEHASH_OK) {
    return lh_lua_error(L, status);
  }
  lua_pushlstring(L, (const char *)digest, sizeof(digest));
  return 1;
}

static int lh_lua_md5_final(lua_State *L) {
  lonehash_md5 *hash;
  unsigned char digest[LONEHASH_MD5_DIGEST_SIZE];
  lonehash_status status;

  hash = lh_lua_check_md5(L, 1);
  status = hash->final(hash, digest);
  if (status != LONEHASH_OK) {
    return lh_lua_error(L, status);
  }
  lua_pushlstring(L, (const char *)digest, sizeof(digest));
  return 1;
}

static int lh_lua_sha256_final_hex(lua_State *L) {
  lonehash_sha256 *hash;
  unsigned char digest[LONEHASH_SHA256_DIGEST_SIZE];
  char hex[LONEHASH_SHA256_HEX_SIZE];
  lonehash_status status;

  hash = lh_lua_check_sha256(L, 1);
  status = hash->final(hash, digest);
  if (status != LONEHASH_OK) {
    return lh_lua_error(L, status);
  }
  hash->hex(hash, digest, hex);
  lua_pushstring(L, hex);
  return 1;
}

static int lh_lua_md5_final_hex(lua_State *L) {
  lonehash_md5 *hash;
  unsigned char digest[LONEHASH_MD5_DIGEST_SIZE];
  char hex[LONEHASH_MD5_HEX_SIZE];
  lonehash_status status;

  hash = lh_lua_check_md5(L, 1);
  status = hash->final(hash, digest);
  if (status != LONEHASH_OK) {
    return lh_lua_error(L, status);
  }
  hash->hex(hash, digest, hex);
  lua_pushstring(L, hex);
  return 1;
}

static int lh_lua_sha256_digest(lua_State *L) {
  lonehash_sha256 *hash;
  const char *data;
  size_t len;
  unsigned char digest[LONEHASH_SHA256_DIGEST_SIZE];
  lonehash_status status;

  hash = lh_lua_check_sha256(L, 1);
  data = luaL_checklstring(L, 2, &len);
  status = hash->digest_buffer(hash, data, len, digest);
  if (status != LONEHASH_OK) {
    return lh_lua_error(L, status);
  }
  lua_pushlstring(L, (const char *)digest, sizeof(digest));
  return 1;
}

static int lh_lua_md5_digest(lua_State *L) {
  lonehash_md5 *hash;
  const char *data;
  size_t len;
  unsigned char digest[LONEHASH_MD5_DIGEST_SIZE];
  lonehash_status status;

  hash = lh_lua_check_md5(L, 1);
  data = luaL_checklstring(L, 2, &len);
  status = hash->digest_buffer(hash, data, len, digest);
  if (status != LONEHASH_OK) {
    return lh_lua_error(L, status);
  }
  lua_pushlstring(L, (const char *)digest, sizeof(digest));
  return 1;
}

static int lh_lua_sha256_digest_hex(lua_State *L) {
  lonehash_sha256 *hash;
  const char *data;
  size_t len;
  unsigned char digest[LONEHASH_SHA256_DIGEST_SIZE];
  char hex[LONEHASH_SHA256_HEX_SIZE];
  lonehash_status status;

  hash = lh_lua_check_sha256(L, 1);
  data = luaL_checklstring(L, 2, &len);
  status = hash->digest_buffer(hash, data, len, digest);
  if (status != LONEHASH_OK) {
    return lh_lua_error(L, status);
  }
  hash->hex(hash, digest, hex);
  lua_pushstring(L, hex);
  return 1;
}

static int lh_lua_md5_digest_hex(lua_State *L) {
  lonehash_md5 *hash;
  const char *data;
  size_t len;
  unsigned char digest[LONEHASH_MD5_DIGEST_SIZE];
  char hex[LONEHASH_MD5_HEX_SIZE];
  lonehash_status status;

  hash = lh_lua_check_md5(L, 1);
  data = luaL_checklstring(L, 2, &len);
  status = hash->digest_buffer(hash, data, len, digest);
  if (status != LONEHASH_OK) {
    return lh_lua_error(L, status);
  }
  hash->hex(hash, digest, hex);
  lua_pushstring(L, hex);
  return 1;
}

static int lh_lua_sha256_file(lua_State *L) {
  lonehash_sha256 *hash;
  const char *path;
  unsigned char digest[LONEHASH_SHA256_DIGEST_SIZE];
  lonehash_status status;

  hash = lh_lua_check_sha256(L, 1);
  path = luaL_checkstring(L, 2);
  status = hash->digest_path(hash, path, digest);
  if (status != LONEHASH_OK) {
    return lh_lua_error(L, status);
  }
  lua_pushlstring(L, (const char *)digest, sizeof(digest));
  return 1;
}

static int lh_lua_md5_file(lua_State *L) {
  lonehash_md5 *hash;
  const char *path;
  unsigned char digest[LONEHASH_MD5_DIGEST_SIZE];
  lonehash_status status;

  hash = lh_lua_check_md5(L, 1);
  path = luaL_checkstring(L, 2);
  status = hash->digest_path(hash, path, digest);
  if (status != LONEHASH_OK) {
    return lh_lua_error(L, status);
  }
  lua_pushlstring(L, (const char *)digest, sizeof(digest));
  return 1;
}

static int lh_lua_sha256_file_hex(lua_State *L) {
  lonehash_sha256 *hash;
  const char *path;
  unsigned char digest[LONEHASH_SHA256_DIGEST_SIZE];
  char hex[LONEHASH_SHA256_HEX_SIZE];
  lonehash_status status;

  hash = lh_lua_check_sha256(L, 1);
  path = luaL_checkstring(L, 2);
  status = hash->digest_path(hash, path, digest);
  if (status != LONEHASH_OK) {
    return lh_lua_error(L, status);
  }
  hash->hex(hash, digest, hex);
  lua_pushstring(L, hex);
  return 1;
}

static int lh_lua_md5_file_hex(lua_State *L) {
  lonehash_md5 *hash;
  const char *path;
  unsigned char digest[LONEHASH_MD5_DIGEST_SIZE];
  char hex[LONEHASH_MD5_HEX_SIZE];
  lonehash_status status;

  hash = lh_lua_check_md5(L, 1);
  path = luaL_checkstring(L, 2);
  status = hash->digest_path(hash, path, digest);
  if (status != LONEHASH_OK) {
    return lh_lua_error(L, status);
  }
  hash->hex(hash, digest, hex);
  lua_pushstring(L, hex);
  return 1;
}

static int lh_lua_version(lua_State *L) {
  lua_pushstring(L, LONEHASH_VERSION);
  return 1;
}

static void lh_lua_new_metatable(lua_State *L, const char *name,
                                 const luaL_Reg *methods) {
  luaL_newmetatable(L, name);
  lua_pushvalue(L, -1);
  lua_setfield(L, -2, "__index");
  luaL_setfuncs(L, methods, 0);
  lua_pop(L, 1);
}

int luaopen_lonehash_core(lua_State *L) {
  static const luaL_Reg sha256_methods[] = {
      {"reset", lh_lua_sha256_reset},
      {"update", lh_lua_sha256_update},
      {"final", lh_lua_sha256_final},
      {"final_hex", lh_lua_sha256_final_hex},
      {"digest", lh_lua_sha256_digest},
      {"digest_hex", lh_lua_sha256_digest_hex},
      {"file", lh_lua_sha256_file},
      {"file_hex", lh_lua_sha256_file_hex},
      {"__gc", lh_lua_sha256_gc},
      {0, 0}};
  static const luaL_Reg md5_methods[] = {
      {"reset", lh_lua_md5_reset},   {"update", lh_lua_md5_update},
      {"final", lh_lua_md5_final},   {"final_hex", lh_lua_md5_final_hex},
      {"digest", lh_lua_md5_digest}, {"digest_hex", lh_lua_md5_digest_hex},
      {"file", lh_lua_md5_file},     {"file_hex", lh_lua_md5_file_hex},
      {"__gc", lh_lua_md5_gc},       {0, 0}};
  static const luaL_Reg module[] = {{"sha256", lh_lua_sha256_new},
                                    {"md5", lh_lua_md5_new},
                                    {"version", lh_lua_version},
                                    {0, 0}};

  lh_lua_new_metatable(L, "lonehash.sha256", sha256_methods);
  lh_lua_new_metatable(L, "lonehash.md5", md5_methods);
  luaL_newlib(L, module);
  return 1;
}
