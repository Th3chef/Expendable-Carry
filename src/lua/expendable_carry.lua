-- HD2-Addon: mods/chef/expendable_carry
-- Expendable Carry for Helldivers 2 (Bingus Shared Loader v19+ addon).
-- Pick up an expendable support weapon (EAT-17, EAT-700, EAT-411, MGX-42, MLS-4X) or the Solo Silo's targeting remote and
-- keep your own support weapon:
-- it stays holstered on your back while the expendable is in your hands. Press your support weapon key with the
-- expendable in hand and the expendable is dropped and your own weapon is back in your hands; use the expendable up and
-- your weapon stays on its sling (on your back) until you draw it.
-- Solo and when you host (your game runs the pickups): all of the above. In a joined game the host's game runs your
-- pickups and owns your weapon once it is set down: it stays where it was set down, and the key asks the host's game
-- for it back from wherever you are (the game's own pickup request; works with an unmodded host).
-- Finds everything it needs in the game's code by itself (no fixed addresses), so a game update doesn't break it;
-- if something can't be found, it stays off and says why in its log.
--
-- How (solo and hosting): the game itself only has one support weapon slot, so when you pick up an expendable it sets
-- your support weapon down as usual. The mod locks that weapon (nobody can pick it up) and has the game attach it to
-- your helldiver's holster spot with the game's own attach, the one it uses for every holstered weapon, so it sits on
-- your back exactly like a holstered weapon. When you press your support weapon key with the expendable in hand, the
-- weapon is unlocked and the game's own routines equip it in your support slot (which drops the expendable at your
-- feet) and switch to it, with the weapon's own weapon-switch sound, the same calls the game makes when you pick a
-- weapon up, minus the pickup itself. When the expendable is used up, your weapon goes back in your support slot the
-- same way but stays on its sling (on your back) until you draw it.
local VERSION = '1.0.1'
local VERBOSE = false          -- more details in the research log (off in the release)

if rawget(_G, 'ChefExpendableCarry') then return end
local EC = { version = VERSION, status = 'starting' }
rawset(_G, 'ChefExpendableCarry', EC)

local ffi = require('ffi')
local bit = require('bit')

-- ======================================================================================================
-- Tuning (only needs a look if the game changes how pickups work)
-- ======================================================================================================
local WATCH_SECONDS = 300     -- how long a set-down support weapon is followed in the log
local WATCH_FAST = 20         -- ... every quarter second for this long, then every 2 s

-- the support weapons by entity type (the resource hash of the weapon's entity name: the same in every game build)
local WEAPONS = {
  ['80932fa0ed6901d3'] = { 'EAT-17 Expendable Anti-Tank', true },
  ['b2b5e0d185605f9e'] = { 'EAT-700 Expendable Napalm', true },
  ['7617642765ac38c7'] = { 'EAT-411 Leveller', true },
  ['b16c9d490aa59b77'] = { 'MGX-42 Bullet Storm', true },
  ['5990123d142b16cb'] = { 'MLS-4X Commando', true },
  ['fc13460592ca79aa'] = { 'Solo Silo Targeting Remote', true },   -- MS-11 Solo Silo: sits in the support slot too
  ['6cfcc7f8801a0266'] = { '40-K Meltagun' }, ['a8cffb316f0b5c5f'] = { 'AC-8 Autocannon' },
  ['89c5493e08ca4207'] = { 'APW-1 Anti-Materiel Rifle' }, ['96de9cd50f7306e6'] = { 'ARC-3 Arc Thrower' },
  ['78a8185f63a70795'] = { 'B/FLAM-80 Cremator' }, ['25aa2fd4643cf4ee'] = { 'FAF-14 Spear' },
  ['39ab99895147a3bf'] = { 'FLAM-40 Flamethrower' }, ['02eecd0b1fa49630'] = { 'GL-21 Grenade Launcher' },
  ['88c2d09ad85a7c9f'] = { 'GL-28 Belt-Fed Grenade Launcher' }, ['fe3b29b2cfa63f9b'] = { 'GL-52 De-Escalator' },
  ['9f80d67a12a7e40f'] = { 'GR-8 Recoilless Rifle' }, ['d54b9505c0f72873'] = { 'LAS-98 Laser Cannon' },
  ['35a61296619cc47e'] = { 'LAS-99 Quasar Cannon' }, ['43a58cb89cfa197c'] = { 'M-1000 Maxigun' },
  ['2152d5147b0ac418'] = { 'MG-206 Heavy Machine Gun' }, ['11c27d3babb38956'] = { 'MG-43 Machine Gun' },
  ['e8d5f49ad7780e54'] = { 'PLAS-45 Epoch' }, ['26e40437ea275296'] = { 'RL-77 Airburst Rocket Launcher' },
  ['2e9d0bdc48b09e60'] = { 'RS-422 Railgun' }, ['3828e2051aa9e897'] = { 'S-11 Speargun' },
  ['cc786f6491fe7e65'] = { 'StA-X3 W.A.S.P. Launcher' },
  -- the other weapons that sit in the support slot (their own folders: the Stalwart is under primary_weapons)
  ['085c1edb038ec24e'] = { 'MG-206 Heavy Machine Gun' },
  ['1d5943301a29c940'] = { 'E/GL-21 Grenadier Battlement' },
  ['372481e910c05a76'] = { 'TACTICAL VIDEO CAMERA' },
  ['444880f62ca7eae8'] = { 'B/FLAM-80 Cremator' },
  ['52071f49263415e4'] = { 'SG-88 Break-Action Shotgun' },
  ['5f3ec9bda2bd8553'] = { 'CQC-20 Breaching Hammer' },
  ['88f61afff48ac8a4'] = { 'TX-41 Sterilizer' },
  ['a6a735accb4a327f'] = { 'M-105 Stalwart' },
  ['b0f1b354ba1d38d8'] = { 'CQC-1 One True Flag' },
  ['b43235dbd493750c'] = { 'M-105 Stalwart' },
  ['b9606c5aab32c3c2'] = { 'M-105 Stalwart' },
  ['bf4cfd2aeabfb5a4'] = { 'CQC-9 Defoliation Tool' },
  ['cd00bdc1149c2928'] = { 'MG-206 Heavy Machine Gun' },
  ['d53ee03481ae73fd'] = { 'M-105 Stalwart' },
  ['e85e623f93f96fb3'] = { 'CQC-72 Entrenchment Tool' },
}
local AVATAR_TYPE = '4d1c334d294dfa97'   -- your helldiver's entity type (and its unit model)
local SLOT_NAMES = { [0] = 'primary', 'secondary', 'support', 'backpack', 'slot 5', 'slot 6' }

-- ======================================================================================================
-- Windows API (private names, so they never clash with another mod's declarations)
-- ======================================================================================================
for _, d in ipairs({
  'void *EcGetModuleHandleA(const char *name) __asm__("GetModuleHandleA");',
  'void *EcGetCurrentProcess(void) __asm__("GetCurrentProcess");',
  'int EcReadProcessMemory(void *process, const void *address, void *buffer, size_t size, size_t *done) __asm__("ReadProcessMemory");',
  'int EcCreateDirectoryA(const char *path, void *security) __asm__("CreateDirectoryA");',
  'int EcWriteProcessMemory(void *process, void *address, const void *buffer, size_t size, size_t *done) __asm__("WriteProcessMemory");',
  'typedef struct { void *base; void *alloc_base; uint32_t alloc_protect; uint16_t partition; uint16_t pad; size_t size; uint32_t state; uint32_t protect; uint32_t type; } EcRegion;',
  'size_t EcVirtualQuery(const void *address, void *region, size_t size) __asm__("VirtualQuery");',
  'int EcGetModuleHandleExA(uint32_t flags, const void *address, void **module) __asm__("GetModuleHandleExA");',
  'uint32_t EcGetModuleFileNameA(void *module, char *name, uint32_t size) __asm__("GetModuleFileNameA");',
  'int32_t EcRegGetValueA(void *key, const char *subkey, const char *value, uint32_t flags, uint32_t *type, void *data, uint32_t *size) __asm__("RegGetValueA");',
  'typedef struct { uint32_t attrs; uint32_t times[6]; uint32_t size_hi; uint32_t size_lo; uint32_t r0; uint32_t r1; char name[260]; char alt[14]; } EcFind;',
  'void *EcFindFirstFileA(const char *pattern, EcFind *data) __asm__("FindFirstFileA");',
  'int EcFindNextFileA(void *find, EcFind *data) __asm__("FindNextFileA");',
  'int EcFindClose(void *find) __asm__("FindClose");',
}) do pcall(ffi.cdef, d) end
local K32 = ffi.load('kernel32')
local ADV = (pcall(ffi.load, 'advapi32')) and ffi.load('advapi32') or nil
local PROCESS = K32.EcGetCurrentProcess()

-- ======================================================================================================
-- Log: Logs\ExpendableCarry.log
-- ======================================================================================================
local LOADER = rawget(_G, 'CowboyBingusModLoader')
local V19 = type(LOADER) == 'table' and type(rawget(LOADER, 'capabilities')) == 'table'
  and type(rawget(LOADER, 'after_startup')) == 'function'
local LOGDIR
do
  local dir = type(LOADER) == 'table' and type(rawget(LOADER, 'log_directory')) == 'string' and LOADER.log_directory or nil
  if not dir then
    local base = os.getenv('LOCALAPPDATA')
    dir = base and (base .. '\\CowboyBingus\\Helldivers2\\Logs') or nil
  end
  if dir then dir = dir:gsub('[\\/]+$', '') end
  LOGDIR = dir
end
local LOGFILE = LOGDIR and (LOGDIR .. '\\ExpendableCarry.log') or nil
local RECFILE = LOGDIR and (LOGDIR .. '\\ExpendableCarry.research.log') or nil
if LOGDIR then                          -- each session starts fresh logs; the previous session's are kept (a crash leaves no other trace)
  for _, f in ipairs({ LOGFILE, RECFILE }) do
    local prev = f:gsub('%.log$', '.previous.log')
    pcall(os.remove, prev); pcall(os.rename, f, prev)
  end
end
local T0 = os.clock()
local session = { started = os.date('%Y-%m-%d %H:%M:%S'), events = {}, notes = {} }
local rec_lines = {}
-- the research log is written as it goes (appended every second), so a crash or a quit never loses it
local function rec(msg) rec_lines[#rec_lines + 1] = string.format('%s %8.2f  %s', os.date('%H:%M:%S'), os.clock() - T0, msg) end
local function event(msg)
  local e = session.events
  e[#e + 1] = os.date('%H:%M:%S ') .. msg
  if #e > 60 then table.remove(e, 1) end
  rec('** ' .. msg)
end
local function note(key, msg) session.notes[#session.notes + 1] = key .. ': ' .. msg end
local stats = { reads = 0, read_fails = 0, frames = 0, swaps = 0, ms = 0, worst_ms = 0 }

-- ======================================================================================================
-- Memory: ReadProcessMemory on our own process into one reusable buffer (a bad address fails cleanly)
-- ======================================================================================================
local BUF_SIZE = 65536
local BUF = ffi.new('uint8_t[?]', BUF_SIZE)
local DONE = ffi.new('size_t[1]')
local PVOID = ffi.typeof('const void *')
local PU32, PU64, PF32 = ffi.typeof('const uint32_t *'), ffi.typeof('const uint64_t *'), ffi.typeof('const float *')
local cast = ffi.cast
local function fetch(addr, n)
  if type(addr) ~= 'number' or addr < 65536 or addr >= 140737488355328 or n <= 0 then return false end
  if n > BUF_SIZE then
    while BUF_SIZE < n do BUF_SIZE = BUF_SIZE * 2 end
    BUF = ffi.new('uint8_t[?]', BUF_SIZE)
  end
  stats.reads = stats.reads + 1
  if K32.EcReadProcessMemory(PROCESS, cast(PVOID, addr), BUF, n, DONE) == 0 or DONE[0] ~= n then
    stats.read_fails = stats.read_fails + 1
    return false
  end
  return true
end
local function shrink_buf() if BUF_SIZE > 65536 then BUF_SIZE = 65536; BUF = ffi.new('uint8_t[?]', BUF_SIZE) end end
local function b8(o) return BUF[o] end
local function b32(o) return tonumber(cast(PU32, BUF + o)[0]) end
local function b64(o) return tonumber(cast(PU64, BUF + o)[0]) end
local function bf32(o)
  local v = tonumber(cast(PF32, BUF + o)[0])
  if v == nil or v ~= v or v == math.huge or v == -math.huge then return nil end
  return v
end
local function bptr(o)
  local p = b64(o)
  if p < 65536 or p >= 140737488355328 then return nil end
  return p
end
local function read_ptr(addr) return fetch(addr, 8) and bptr(0) or nil end
local function read_u64(addr) return fetch(addr, 8) and b64(0) or nil end
local function read_u32(addr) return fetch(addr, 4) and b32(0) or nil end
local function read_string(addr, n) return fetch(addr, n) and ffi.string(BUF, n) or nil end
local function su32(t, o) local a, b, c, d = t:byte(o + 1, o + 4); return a + b * 256 + c * 65536 + d * 16777216 end
local function si32(t, o) local v = su32(t, o); return v >= 2147483648 and v - 4294967296 or v end
local function hex(s) return (s:gsub('.', function(c) return string.format('%02x', c:byte()) end)) end
local function type_hex(s, o)          -- an 8-byte type hash as the usual hex (high byte first)
  local h = {}
  for k = o + 8, o + 1, -1 do h[#h + 1] = string.format('%02x', s:byte(k)) end
  return table.concat(h)
end

-- ======================================================================================================
-- Finding the game's code: byte patterns ('??' = any byte), each must match exactly once
-- ======================================================================================================
local function compile(p)
  p = p:gsub(' ', '')
  local segs, cur_off, cur = {}, nil, {}
  for k = 0, #p / 2 - 1 do
    local h = p:sub(2 * k + 1, 2 * k + 2)
    if h == '??' then
      if cur_off then segs[#segs + 1] = { cur_off, table.concat(cur) }; cur_off, cur = nil, {} end
    else
      cur_off = cur_off or k
      cur[#cur + 1] = string.char(tonumber(h, 16))
    end
  end
  if cur_off then segs[#segs + 1] = { cur_off, table.concat(cur) } end
  local anchor = 1
  for j = 2, #segs do if #segs[j][2] > #segs[anchor][2] then anchor = j end end
  return segs, anchor, #p / 2
end
local function find_all(text, p, limit)
  local segs, anchor, n = compile(p)
  local a = segs[anchor]
  local init, out = 1, {}
  while #out < (limit or 8) do
    local s = string.find(text, a[2], init, true)
    if not s then break end
    local start = s - 1 - a[1]
    local ok = start >= 0 and start + n <= #text
    if ok then
      for j, seg in ipairs(segs) do
        if j ~= anchor and text:sub(start + seg[1] + 1, start + seg[1] + #seg[2]) ~= seg[2] then ok = false; break end
      end
    end
    if ok then out[#out + 1] = start end
    init = s + 1
  end
  return out
end
local function find_once(text, p, what)
  local r = find_all(text, p, 2)
  if #r == 0 then error(what .. ': not found', 0) end
  if #r > 1 then error(what .. ': found more than once', 0) end
  return r[1]
end
local function module_info(module)
  local b = ffi.cast('uint8_t *', module)
  local function r32(p) return tonumber(ffi.cast('uint32_t *', p)[0]) end
  local function r16(p) return tonumber(ffi.cast('uint16_t *', p)[0]) end
  local pe = r32(b + 0x3c)
  local stamp, image = r32(b + pe + 8), r32(b + pe + 24 + 56)
  local count, optsize = r16(b + pe + 6), r16(b + pe + 20)
  local sec = b + pe + 24 + optsize
  local code
  for i = 0, count - 1 do
    local s = sec + 40 * i
    local vsize, rva, flags = r32(s + 8), r32(s + 12), r32(s + 36)
    if bit.band(flags, 0x20000000) ~= 0 and vsize > 0x100000 and not code then code = { rva = rva, size = vsize } end
  end
  return { base = tonumber(ffi.cast('uintptr_t', module)), stamp = stamp, image = image, code = code }
end

-- The code we look for (game build of September 2026; the comments say what each piece is)
local P = {
  -- the players block (+132 player count, +136 local players, +936 your helldiver's entity id)
  players = '48 8B 05 ?? ?? ?? ?? 48 8D 54 24 48 48 8B 88 E8 00 00 00',
  -- the entity table (entity id -> row of 24 bytes: type hash, entity id, unit, ..., flags +20)
  owners = '48 8B 0D ?? ?? ?? ?? 8B 50 08 E8 ?? ?? ?? ?? EB ?? 48 8B CF E8 ?? ?? ?? ?? BA 5F 21 8B 6F 48 8B CF',
  owner_index = '45 8B 93 ?? ?? ?? ?? 33 D2 48 89 5C 24 10 41 ?? ?? ?? ?? ?? ?? 48 89 6C 24 18 41 0F AF D8 41 8D 6A FF'
             .. ' 48 89 74 24 20 48 89 3C 24 45 85 D2 74 ?? 49 8B BB ?? ?? ?? ?? 41 8B B3 ?? ?? ?? ?? 66 66 66 0F 1F 84 00 00 00 00 00',
  owner_rows = '8B 41 04 48 8D 0C 40 48 8D 85 ?? ?? ?? ?? 48 8D 04 C8 EB ?? 48 8D 05 ?? ?? ?? ??',
  -- the entity table's free-row search: compares each row's id (row + 8) and wraps at the row count (twice the same)
  owner_count = '42 39 94 C1 ?? ?? ?? ?? 74 ?? FF C0 89 81 ?? ?? ?? ?? 3D ?? ?? ?? ?? 75 ?? 44 89 91 ?? ?? ?? ?? 41 8B C2 41 FF C1'
             .. ' 41 81 F9 ?? ?? ?? ?? 72 ??',
  -- the equipment component (your loadout slots: map +0x28 by helldiver, 48-byte records +0x50:
  -- +0 primary, +4 secondary, +8 support weapon, +12 backpack ...)
  equipment = '4C 8B 05 ?? ?? ?? ?? 33 DB 8B CB 45 8B 48 30 45 8B 50 38',
  -- the helldiver state component (per helldiver, by entity id; what is wielded and being switched to)
  state = '4C 8B 35 ?? ?? ?? ?? 4D 89 7B D8 74 ?? 45 8B 8E ?? ?? ?? ?? 44 8B C3 45 8B 9E ?? ?? ?? ?? 44 0F AF D8 45 8D 69 FF'
       .. ' 45 85 C9 74 ?? 4D 8B BE ?? ?? ?? ?? 45 8B A6 ?? ?? ?? ?? 66 66 0F 1F 84 00 00 00 00 00 41 8B CD 43 8D 14 18'
       .. ' 48 23 D1 41 8B 0C D7 4D 8D 14 D7 41 3B CC 0F 84 ?? ?? ?? ?? 3B C8 0F 84 ?? ?? ?? ?? 41 FF C0 45 3B C1 72 ??'
       .. ' B8 FF FF FF FF 8B C8 4D 8D AE ?? ?? ?? ?? 48 69 C1 ?? ?? ?? ??',
  -- interactors (Solo Buddy Bunkers): the manager, its list and instances, the interaction routine
  head = '3B 15 ?? ?? ?? ?? 48 8B 1D ?? ?? ?? ?? 0F 84 ?? ?? ?? ?? 44 8B 5B 30 45 33 D2 48 89 78 20 45 8B C2 8B 7B 38 0F AF FA',
  inst = '41 8B 49 04 B8 FF FF FF FF 3B C8 0F 84 ?? ?? ?? ?? 8B D1 48 8B 4B 40 4C 8B 04 D1 4C 89 84 24 80 00 00 00'
      .. ' 41 F6 40 14 01 0F 84 ?? ?? ?? ?? 4C 89 6C 24 60 4C 69 EA 80 08 00 00 4C 03 6B 48',
  call = '8B 4B 08 48 8B D6 4C 6B C7 68 4D 03 C4 E8 ?? ?? ?? ?? 8B 46 04 48 8D 54 24 30 44 8B 4B 08 44 8B 06 89 44 24 20'
      .. ' E8 ?? ?? ?? ?? 0F 10 00 41 0F 11 85 ?? ?? ?? ?? F2 0F 10 48 10 F2 41 0F 11 8D ?? ?? ?? ??',
  count = '48 89 4C 24 38 0F 28 F9 48 8B D1 89 5C 24 30 39 59 1C 0F 86',
  -- the interactables by entity id (hash buckets, size, empty key, multiplier; then entities, records, enabled bits)
  im = '3B 15 ?? ?? ?? ?? 4C 8B 1D ?? ?? ?? ?? 4D 63 F1 75 07 B8 FF FF FF FF EB ?? 45 8B 8B ?? ?? ?? ?? 45 33 C0 48 89 5C 24 10'
    .. ' 41 8B 9B ?? ?? ?? ?? 48 89 6C 24 18 0F AF DA 41 8D 69 FF 48 89 74 24 20 48 89 7C 24 28 45 85 C9 74 ?? 49 8B BB ?? ?? ?? ??'
    .. ' 41 8B B3 ?? ?? ?? ??',
  -- the weapon pickup case of the interaction routine: the equipment's 'set slot' call (which first drops what the
  -- slot held) and the slot number (1 primary, 2 secondary, 3 support)
  pickup = '41 83 FE 01 B8 03 00 00 00 0F 44 C2 3B 1D ?? ?? ?? ?? 89 44 24 50 48 8B 05 ?? ?? ?? ?? 48 89 45 C0',
  setslot = '44 8B 4C 24 50 44 8B C6 48 8B 0D ?? ?? ?? ?? 8B D3 C6 44 24 20 00 E8 ?? ?? ?? ??',
  -- ... then the network event for it (-2, helldiver, weapon, slot)
  netslot = '44 8B 4C 24 50 44 8B C6 8B D3 48 C7 C1 FE FF FF FF E8 ?? ?? ?? ??',
  -- ... and the wield request (the weapon-switch: helldiver state record + 0x3D0, slot, 0) and its follow-up
  wield = '8B 54 24 50 45 33 C0 8B C8 48 69 C1 ?? ?? ?? ?? 48 8B 4D C0 48 81 C1 ?? ?? ?? ?? 48 03 C8 E8 ?? ?? ?? ??',
  wield2 = '8B C7 48 69 C8 ?? ?? ?? ?? 48 8B 45 C0 48 05 ?? ?? ?? ?? 48 03 C8 E8 ?? ?? ?? ??',
  -- (optional) the game's weapon-switch sound: the wield handler gets the audio world (audio API +0x58 on the world's
  -- +0x10E8), the wielder's unit (entity API +0x18 table +0x748), its audio source (audio API +0x2C8) ...
  audio = '48 8B 05 ?? ?? ?? ?? 48 8B 0D ?? ?? ?? ?? 48 8B 50 ?? 48 8B 89 ?? ?? ?? ?? FF D2 48 8B 0D ?? ?? ?? ?? 48 8B F8'
       .. ' 48 8B 74 24 ?? 48 8B 99 ?? ?? ?? ?? 48 8B 0D ?? ?? ?? ?? 48 8B 51 ?? 8B 4E 0C 4C 8B 82 ?? ?? ?? ?? 41 FF D0'
       .. ' 45 33 C0 48 8B D0 48 8B CF FF D3',
  -- ... and plays the weapon's wield sound there (audio API +0x1E8: event, source, 0; the event from Equipment +0xB0)
  play = '48 8B 05 ?? ?? ?? ?? 45 33 C0 41 8B 8F B0 00 00 00 48 8B D6 FF 90 ?? ?? ?? ??',
  -- ... after setting the source's first- or third-person mix ('avatar_perspective': the helldiver state's answer)
  persp = '41 8B 55 04 48 8B 0D ?? ?? ?? ?? 48 8B 9B ?? ?? ?? ?? E8 ?? ?? ?? ?? 8B C8 48 8D 15 ?? ?? ?? ?? 0F 57 D2'
       .. ' F3 48 0F 2A D1 48 8B CE FF D3',
  -- the same handler turning the wielder's entity into its UNIT (the entity table's row +12), then asking the
  -- entity API (+0x18 table) whether that unit is alive (+0x720): the API's functions take units, not entity ids
  unit_alive = '41 8B 55 04 48 8D 4C 24 40 4C 8B F8 E8 ?? ?? ?? ?? 8B 7C 24 40 85 FF 0F 84 ?? ?? ?? ?? 48 8B 0D ?? ?? ?? ??'
            .. ' 48 8B 51 18 8B CF 4C 8B 82 ?? ?? ?? ?? 41 FF D0',
  -- the same handler holstering a weapon: the wielder's holster node (Equipment +0x1C, the entity API +0x18 table
  -- +0x6D8: entity, node name hash -> node index) ...
  holster_node = '41 8B 57 1C 44 0F 29 BC 24 A0 00 00 00 85 D2 75 ?? 45 8B E6 EB ?? 48 8B 05 ?? ?? ?? ?? 48 8B 48 18'
              .. ' 48 8B 81 D8 06 00 00 8B CF FF D0 44 8B E0',
  -- ... and the game's attach there (the attachables: weapon, wielder, node, &position offset (Equipment +0x2C),
  -- &rotation, lerp time): the one call that puts every holstered weapon on a helldiver's back
  attach = 'F2 41 0F 10 47 2C F2 0F 11 44 24 60 F3 0F 11 64 24 74 F3 0F 11 54 24 78 48 8B 0D ?? ?? ?? ?? 48 8D 44 24 60'
        .. ' 45 8B CC 48 89 44 24 20 44 8B C7 8B D3 E8 ?? ?? ?? ??',
  -- the interactables' switch for one interaction (manager, entity, interaction, on): the game's own way to
  -- turn a pick-up on or off; it keeps one bit per interaction in the enabled words (+0x14078, 16 bytes per
  -- interactable) and refuses to turn one on while the interactable's 'blocked' byte is set. Found where a pick-up's
  -- delay runs out and the game turns it on.
  iswitch = '41 8B 55 08 41 B1 01 44 8B C3 48 8B CD E8 ?? ?? ?? ??',
  -- the attachables' detach (entity, 0, 0), from one of its many callers
  detach = '48 8B 0D ?? ?? ?? ?? 45 33 C0 48 C7 44 24 48 00 00 00 00 4C 8B 4C 24 48 E8 ?? ?? ?? ??',
}
-- (inside the attach routine) its map by entity and its records: the attached-to entity is a record's first word
local P_ATT_MAP = '44 8B 41 ?? 44 8B 49 ??'
local P_ATT_MAP2 = '4D 8B 56 ?? 45 8B 5E ??'
local P_ISW_SIZE = '44 8B 99 ?? ?? ?? ?? 45 33 C9'                 -- (inside the switch) the map size: the same manager
local P_ISW_BLOCK = '41 80 7C C0 ?? 00 75 ?? 8B D1 48 C1 E2 ??'     -- ... the 'blocked' byte and the record size (shift)
local P_ATT_RECS = '4D 69 E4 ?? ?? ?? ?? ?? ?? ?? ?? ?? ?? ?? ?? ?? ?? ?? ?? ?? ?? ?? ?? ?? ?? 4D 03 66 ??'
-- (helldivers2.exe) a unit by its id: index = id & 0x3FFFFF below the count (+0x98), generation byte (+0xA0) = id >> 22,
-- the unit object at +0x88 [index] (its own id at +8, world poses at +0x88, root position at +48)
local P_UNITS = '48 8B 35 ?? ?? ?? ?? 8B D9 48 8D 8E D0 00 00 00 FF 15 ?? ?? ?? ?? 8B C3 25 FF FF 3F 00 3B 86 98 00 00 00'
             .. ' 72 04 33 DB EB 1C 8B C8 48 8B 86 A0 00 00 00 C1 EB 16 38 1C 01 75 EB 48 8B 86 88 00 00 00 48 8B 1C C8'
local KNOWN = { players = 0x3326468, owners = 0x346BF98, equipment = 0x3326738, state = 0x3326D20, imgr = 0x33269A0,
                im = 0x3326D68, setslot = 0x9AE030, netslot = 0xBF0950, wield = 0xA93E90, wield2 = 0xA951D0, units = 0x1A100F0,
                attach = 0x812540, detach = 0x813250, attachables = 0x3326698, iswitch = 0x978610 }
local UNIT = { id = 8, poses = 0x88, pos = 48 }

local G = {}
local function resolve()
  local t0 = os.clock()
  local gmod, emod = K32.EcGetModuleHandleA('game.dll'), K32.EcGetModuleHandleA(nil)
  if gmod == nil or emod == nil then error('game modules not loaded', 0) end
  local GM, EM = module_info(gmod), module_info(emod)
  if not (GM.code and EM.code) then error('no code section', 0) end
  local text = read_string(GM.base + GM.code.rva, GM.code.size)
  if not text then error('cannot read the game code', 0) end
  local crva, gb = GM.code.rva, GM.base
  local function at(name) local o = find_once(text, P[name], name); return o, text:sub(o + 1, o + 160) end
  local function rip(o, t, disp, size) return gb + crva + o + size + si32(t, disp) end
  local o, t
  o, t = at('players'); G.players = rip(o, t, 3, 7)
  o, t = at('owners'); G.owners = rip(o, t, 3, 7)
  o, t = at('owner_index'); G.owner_index = su32(t, 3) - 8
  o, t = at('owner_rows'); G.owner_rows = su32(t, 10) - 8
  o, t = at('owner_count')
  G.owner_count = su32(t, 19)
  if su32(t, 4) ~= G.owner_rows + 8 or su32(t, 41) ~= G.owner_count or G.owner_count < 256 or G.owner_count > 65536 then
    error('owner_count: layout not plausible', 0)
  end
  o, t = at('equipment'); G.equipment = rip(o, t, 3, 7)
  o, t = at('state'); G.state = rip(o, t, 3, 7)
  G.state_map, G.state_recs, G.state_stride = su32(t, 46), su32(t, 120), su32(t, 127)
  if su32(t, 16) ~= G.state_map + 8 or su32(t, 53) ~= G.state_map + 12 or su32(t, 26) ~= G.state_map + 16
     or G.state_stride < 0x100 or G.state_stride > 0x10000 then error('state: layout not plausible', 0) end
  -- interactors
  local oh, th = at('head'); local oi, ti = at('inst'); local oc, tc = at('call'); local _, tn = at('count')
  if oi - oh <= 0 or oi - oh > 0x200 or oc - oi <= 0 or oc - oi > 0x400 then error('interactor code: pieces apart', 0) end
  G.imgr = rip(oh, th, 9, 13)
  G.ilist, G.iinsts, G.istride = ti:byte(23), ti:byte(62), su32(ti, 54)
  G.interact = rip(oc, tc, 38, 42); G.iplayer, G.ireq = tc:byte(30), su32(tc, 49)
  G.icount = tn:byte(18)
  G.ihead = math.max(G.icount + 4, G.ilist + 8, G.iinsts + 8)
  o, t = at('im'); G.im = rip(o, t, 9, 13)
  G.im_size, G.im_mult, G.im_buckets, G.im_empty = su32(t, 28), su32(t, 43), su32(t, 77), su32(t, 84)
  -- the pickup case and the 'set slot' call right after it (a cross-check that pickups still go through it)
  local op = at('pickup')
  local os_ = find_all(text:sub(op + 1, op + 0x400), P.setslot, 2)
  if #os_ == 1 then
    local ts = text:sub(op + os_[1] + 1, op + os_[1] + 32)
    G.setslot = gb + crva + op + os_[1] + 27 + si32(ts, 23)
    if rip(op + os_[1], ts, 11, 15) ~= G.equipment then error('setslot: it does not use the equipment', 0) end
  else error('setslot: the set-slot call was not found next to the pickup case', 0) end
  -- the network event and the wield request, in the same pickup case (each must be there exactly once)
  local case = text:sub(op + 1, op + 0x400)
  local function in_case(name, disp, size)
    local r = find_all(case, P[name], 2)
    if #r ~= 1 then error(name .. ': found ' .. #r .. ' times in the pickup case', 0) end
    local t2 = case:sub(r[1] + 1, r[1] + 40)
    return gb + crva + op + r[1] + size + si32(t2, disp), t2
  end
  local tw, tw2
  G.netslot = in_case('netslot', 18, 22)
  G.wield, tw = in_case('wield', 31, 35)
  G.wield2, tw2 = in_case('wield2', 23, 27)
  G.wield_at = su32(tw, 23)                    -- the wield request's part of the helldiver state record
  if su32(tw, 12) ~= G.state_stride or su32(tw2, 5) ~= G.state_stride or su32(tw2, 15) ~= G.wield_at
     or G.wield_at < G.state_recs or G.wield_at >= G.state_recs + G.state_stride then
    error('wield: layout not plausible', 0)
  end
  G.wield_at = G.wield_at - G.state_recs
  -- the weapon-switch sound (optional: without it the swap still works, silently)
  local oka, ea = pcall(function()
    local o1, t1 = at('audio'); local o2, t2 = at('play')
    local a = { api = rip(o1, t1, 3, 7), wb = rip(o1 + 7, t1:sub(8), 3, 7), arg_fn = t1:byte(18), wb_off = su32(t1, 21),
                src_fn = su32(t1, 45), ent = rip(o1 + 49, t1:sub(50), 3, 7), ent_tbl = t1:byte(60), unit_fn = su32(t1, 66),
                play_fn = su32(t2, 22) }
    if rip(o1 + 27, t1:sub(28), 3, 7) ~= a.api or rip(o2, t2, 3, 7) ~= a.api then error('the audio API differs', 0) end
    if a.wb_off > 0x100000 or a.src_fn > 0x2000 or a.unit_fn > 0x2000 or a.play_fn > 0x2000 then error('not plausible', 0) end
    return a
  end)
  if oka then G.audio = ea else G.audio_note = tostring(ea) end
  -- the sound's first- or third-person mix: the helldiver state's routine and the source's parameter call
  if G.audio then
    local okp, ep = pcall(function()
      local o3, t3 = at('persp')
      if rip(o3 + 4, t3:sub(5), 3, 7) ~= G.state then error('not the helldiver state', 0) end
      local pp = { fn = gb + crva + o3 + 23 + si32(t3, 19), param_fn = su32(t3, 14), name = gb + crva + o3 + 32 + si32(t3, 28) }
      if pp.param_fn > 0x2000 then error('not plausible', 0) end
      return pp
    end)
    if okp then G.audio.persp = ep else G.audio.persp_note = tostring(ep) end
  end
  -- the game's attachables: the attach that puts every holstered weapon on a helldiver's back, and its
  -- detach (without them your weapon stays where the game set it down, locked, and the swap back still works)
  local okt, et = pcall(function()
    local oh, th = at('holster_node'); local oa, ta = at('attach'); local od, td = at('detach'); local ou, tu = at('unit_alive')
    if oa - oh <= 0 or oa - oh > 0x400 then error('the holster pieces are apart', 0) end
    local A = { ent = rip(oh + 22, th:sub(23), 3, 7), node_tbl = th:byte(33), node_fn = su32(th, 36),
                mgr = rip(oa + 24, ta:sub(25), 3, 7), attach = gb + crva + oa + 54 + si32(ta, 50),
                detach = gb + crva + od + 29 + si32(td, 25) }
    if rip(od, td, 3, 7) ~= A.mgr then error('the detach is not the attachables\' one', 0) end
    if G.audio and G.audio.ent ~= A.ent then error('the entity API differs', 0) end
    A.alive_fn = su32(tu, 45)
    if rip(ou + 29, tu:sub(30), 3, 7) ~= A.ent or tu:byte(40) ~= A.node_tbl then error('the unit check is not the entity API\'s', 0) end
    if A.node_fn > 0x2000 or A.alive_fn > 0x2000 then error('not plausible', 0) end
    -- the attachables' map and records, read from the attach routine (to see what your weapon is attached to)
    local fo = A.attach - gb - crva
    local body = text:sub(fo + 1, fo + 0x200)
    local r1, r2, r3 = find_all(body, P_ATT_MAP, 2), find_all(body, P_ATT_MAP2, 2), find_all(body, P_ATT_RECS, 2)
    if #r1 >= 1 and #r2 >= 1 and #r3 >= 1 then
      local cap, mult, slots, empty = body:byte(r1[1] + 4), body:byte(r1[1] + 8), body:byte(r2[1] + 4), body:byte(r2[1] + 8)
      if slots + 8 == cap and slots + 12 == empty and slots + 16 == mult then
        A.map, A.stride, A.recs = slots, su32(body, r3[1] + 3), body:byte(r3[1] + 29)
      end
    end
    return A
  end)
  if okt then G.att = et else G.att_note = tostring(et) end
  -- the interactables' switch (optional: without it the pick-up is only kept off by hand)
  local oki, ei = pcall(function()
    local o5, t5 = at('iswitch')
    local f = gb + crva + o5 + 18 + si32(t5, 14)
    local body = text:sub(f - gb - crva + 1, f - gb - crva + 0x120)
    local r1, r2 = find_all(body, P_ISW_SIZE, 2), find_all(body, P_ISW_BLOCK, 2)
    if #r1 < 1 or #r2 ~= 1 then error('its body is not as known', 0) end
    if su32(body, r1[1] + 3) ~= G.im_size then error('not the interactables\' manager', 0) end
    local shift = body:byte(r2[1] + 14)
    if shift < 3 or shift > 6 then error('not plausible', 0) end
    return { fn = f, block = body:byte(r2[1] + 5), stride = 2 ^ shift }
  end)
  if oki then G.isw = ei else G.isw_note = tostring(ei) end
  text = nil
  local etext = read_string(EM.base + EM.code.rva, EM.code.size)
  if not etext then error('cannot read the exe code', 0) end
  o = find_once(etext, P_UNITS, 'units')
  G.units = EM.base + EM.code.rva + o + 7 + si32(etext:sub(o + 1, o + 8), 3)
  etext = nil
  shrink_buf()
  collectgarbage()
  G.game, G.exe = gb, EM.base
  local moved = {}
  local function cmp(k, v) if KNOWN[k] ~= v then moved[#moved + 1] = string.format('%s %x -> %x', k, KNOWN[k], v) end end
  for _, k in ipairs({ 'players', 'owners', 'equipment', 'state', 'imgr', 'im' }) do cmp(k, G[k] - gb) end
  if G.setslot then cmp('setslot', G.setslot - gb) end
  cmp('netslot', G.netslot - gb); cmp('wield', G.wield - gb); cmp('wield2', G.wield2 - gb)
  cmp('units', G.units - EM.base)
  if G.isw then cmp('iswitch', G.isw.fn - gb) end
  if G.att then cmp('attach', G.att.attach - gb); cmp('detach', G.att.detach - gb); cmp('attachables', G.att.mgr - gb) end
  note('weapon-switch sound', G.audio and string.format('found (audio API %x, entity API %x)', G.audio.api - gb, G.audio.ent - gb)
    or ('NOT found - swaps are silent (' .. tostring(G.audio_note) .. ')'))
  note('on your back', G.att and string.format('the game\'s attach found (attachables %x%s)', G.att.mgr - gb,
    G.att.map and '' or '; its records not read, so it can\'t be checked') or ('NOT found - your weapon stays where the game sets it down (' .. tostring(G.att_note) .. ')'))
  if not G.isw then note('pick-up switch', 'NOT found - the pick-up is only kept off by hand (' .. tostring(G.isw_note) .. ')') end
  if G.audio and not G.audio.persp then note('weapon-switch sound mix', 'not found (' .. tostring(G.audio.persp_note) .. ')') end
  note('game code', string.format('found in %.2f s; %s%s', os.clock() - t0,
    #moved == 0 and 'same places as the September 2026 build' or ('moved: ' .. table.concat(moved, ', ')), G.setslot_note or ''))
  note('layout', string.format('owners index +%x rows +%x (%d); state map +%x records +%x stride %x; interactors list +%x insts +%x'
    .. ' stride %x player +%x request +%x count +%x; interactables size +%x buckets +%x',
    G.owner_index, G.owner_rows, G.owner_count, G.state_map, G.state_recs, G.state_stride, G.ilist, G.iinsts, G.istride, G.iplayer,
    G.ireq, G.icount, G.im_size, G.im_buckets))
end

-- ======================================================================================================
-- Reading the game
-- ======================================================================================================
local function mul32(a, b)
  local lo = a * (b % 65536)
  local hi = (a % 65536) * math.floor(b / 65536)
  return (lo + (hi % 65536) * 65536) % 4294967296
end
-- the game's open-addressing maps: { slots*, capacity, empty key, multiplier } (slots of { key, value })
local function map_get(addr, key, maxcap)
  if not fetch(addr, 20) then return nil end
  local slots, cap, empty, mult = bptr(0), b32(8), b32(12), b32(16)
  if not slots or cap == 0 or cap > maxcap or bit.band(cap, cap - 1) ~= 0 then return nil end
  local h, mask = mul32(key, mult), cap - 1
  for i = 0, math.min(cap, 256) - 1 do
    if not fetch(slots + 8 * bit.band(h + i, mask), 8) then return nil end
    local k, v = b32(0), b32(4)
    if k == key then return v ~= 0xFFFFFFFF and v or nil end
    if k == empty then return nil end
  end
  return nil
end
-- an entity's row: type hash (hex), its id (+8), unit id (+12), flags byte (+20); nil when it has none.
-- The entity map is NOT keyed by the id the rows hold (your helldiver: players block a4, row id fb), so
-- an id is found by its row: remembered per id, checked on every use, else all rows are read once (48 KB).
local row_of = {}
local function row_at(e)
  local ob = read_ptr(G.owners); if not ob or e >= G.owner_count then return nil end
  local s = read_string(ob + G.owner_rows + e * 24, 24)
  if not s then return nil end
  return { type = type_hex(s, 0), rid = su32(s, 8), unit = su32(s, 12), flags = s:byte(21), raw = s, row = e }
end
local function entity(id)
  if id == 0 or id == 0xFFFFFFFF then return nil end
  local e = row_of[id]
  if e then local r = row_at(e); if r and r.rid == id then return r end; row_of[id] = nil end
  local ob = read_ptr(G.owners); if not ob then return nil end
  local n = G.owner_count
  local all = read_string(ob + G.owner_rows, n * 24)
  if not all then return nil end
  local first, mine
  for k = 0, n - 1 do
    if su32(all, k * 24 + 8) == id then
      first = first or k
      if bit.band(all:byte(k * 24 + 21), 3) == 1 then mine = k; break end
    end
  end
  local k = mine or first
  if not k then return nil end
  row_of[id] = k
  return row_at(k)
end
-- your helldiver from the players block's handle: the entity map gives its row (the Railgun mod's way)
local function avatar_row(h)
  local ob = read_ptr(G.owners); if not ob then return nil end
  local e = map_get(ob + G.owner_index, h, 1048576)
  if not e then return nil end
  return row_at(e)
end
local function wname(t)
  local w = t and WEAPONS[t]
  if w then return w[1] end
  if t == AVATAR_TYPE then return 'helldiver' end
  return t and ('type ' .. t) or 'nothing'
end
local function describe(id)
  if id == 0 or id == 0xFFFFFFFF then return 'none' end
  local e = entity(id)
  if not e then return string.format('%x (no entity row)', id) end
  return string.format('%x %s (unit %x, flags %02x%s)', id, wname(e.type), e.unit, e.flags,
    bit.band(e.flags, 3) == 1 and ', ours' or '')
end
local function unit_position(unit)
  local reg = read_ptr(G.units); if not reg then return nil end
  local index, gen = bit.band(unit, 0x3FFFFF), bit.band(bit.rshift(unit, 22), 0xFF)
  local count = read_u32(reg + 0x98); if not count or index >= count then return nil end
  local gens = read_ptr(reg + 0xA0); if not gens or not fetch(gens + index, 1) or b8(0) ~= gen then return nil end
  local objs = read_ptr(reg + 0x88); local obj = objs and read_ptr(objs + 8 * index)
  if not obj or read_u32(obj + UNIT.id) ~= unit then return nil end
  local poses = read_ptr(obj + UNIT.poses)
  if not poses or not fetch(poses + UNIT.pos, 12) then return nil end
  local x, y, z = bf32(0), bf32(4), bf32(8)
  if not x or not y or not z or math.abs(x) > 1e5 or math.abs(y) > 1e5 or math.abs(z) > 1e5 then return nil end
  return x, y, z
end
local function avatar()
  local pl = read_ptr(G.players); if not pl then return nil end
  if not fetch(pl + 132, 8) then return nil end                 -- +132 players in the game, +136 local players
  if b32(0) == 0 or b32(4) == 0 or b32(0) > 4 then return nil end
  local a = read_u32(pl + 936)                                   -- +936 your helldiver's handle
  if a == 0 or a == 32767 or a == 0xFFFFFFFF then return nil end
  return a
end
local function equip_addr(av)
  local eq = read_ptr(G.equipment); if not eq then return nil end
  local q = map_get(eq + 40, av, 8192)
  if not q or q >= 4096 then return nil end
  local recs = read_ptr(eq + 80)
  return recs and recs + q * 48 or nil
end
local function state_addr(av)
  local sm = read_ptr(G.state); if not sm then return nil end
  local i = map_get(sm + G.state_map, av, 4096)
  if not i or i >= 64 then return nil end
  return sm + G.state_recs + i * G.state_stride
end
-- an interactable's slot (its index in the interactables' arrays), or nil
local function interactable(eid)
  local im = read_ptr(G.im); if not im then return nil end
  if not fetch(im + G.im_buckets, 20) then return nil end
  local buckets, size, empty, mult = bptr(0), b32(G.im_size - G.im_buckets), b32(G.im_empty - G.im_buckets), b32(G.im_mult - G.im_buckets)
  if not buckets or size == 0 or size > 0x100000 then return nil end
  local h, mask = mul32(eid, mult), size - 1
  for i = 0, math.min(size, 4096) - 1 do
    if not fetch(buckets + bit.band(h + i, mask) * 8, 8) then return nil end
    local k, v = b32(0), b32(4)
    if k == eid then return v ~= 0xFFFFFFFF and v or nil, im end
    if k == empty then return nil end
  end
  return nil
end
-- (research) an interactable's record (0x370 bytes in the September 2026 build) and its enabled-interactions word
local IREC = 0x370
local function interactable_record(eid)
  local idx, im = interactable(eid)
  if not idx then return nil end
  local recs, bits = read_ptr(im + G.im_buckets + 0x20), read_ptr(im + G.im_buckets + 0x28)
  local r = recs and read_string(recs + idx * IREC, IREC)
  local en = bits and fetch(bits + idx * 16, 16) and string.format('%08x %08x %08x %08x', b32(0), b32(4), b32(8), b32(12)) or '?'
  return r, idx, en
end

-- ======================================================================================================
-- Research: what happens around a pickup
-- ======================================================================================================
local R = { av = nil, eq = nil, last_eq = nil, watch = {}, snaps = {}, keys_ok = nil, lua_probe = nil,
            inter_last = nil, inter_req = nil, next_watch = 0, last_press = nil, last_press_t = 0, press_repeat = 0 }

-- differences between two equal-length strings, by 4-byte words ('+off: old -> new'); a word that keeps changing
-- (more than BUSY times under the same key) is left out of later lines and counted, so a timer can't flood the log
local BUSY = 12
local busy = {}
local function diff(a, b, max, key)
  local bk = key and busy[key]
  if key and not bk then bk = {}; busy[key] = bk end
  local out, quiet = {}, 0
  for o = 0, math.min(#a, #b) - 4, 4 do
    if a:sub(o + 1, o + 4) ~= b:sub(o + 1, o + 4) then
      local n = bk and (bk[o] or 0) + 1 or 0
      if bk then bk[o] = n end
      if n > BUSY then quiet = quiet + 1
      elseif #out < (max or 12) then
        out[#out + 1] = string.format('+%x: %s -> %s%s', o, hex(a:sub(o + 1, o + 4)), hex(b:sub(o + 1, o + 4)), n == BUSY and ' (busy: left out from now on)' or '')
      end
    end
  end
  if quiet > 0 then out[#out + 1] = quiet .. ' busy word(s)' end
  return table.concat(out, '; '), #out - (quiet > 0 and 1 or 0)
end

local function slots_text(s)
  local t = {}
  for k = 0, 5 do t[#t + 1] = SLOT_NAMES[k] .. ' ' .. describe(su32(s, 4 * k)) end
  return table.concat(t, ' | ')
end

-- a support weapon left our support slot: follow it (entity, interactable, position) for a while
local function start_watch(id, reason)
  local w0 = R.watch[id]
  if w0 then w0.since = os.clock(); rec(string.format('watch %x (%s): %s (watched again)', id, wname(w0.type), reason)); return end
  local e = entity(id)
  R.next_watch = 0
  R.watch[id] = { id = id, since = os.clock(), unit = e and e.unit, type = e and e.type, last = nil, irec = nil, ien = nil }
  rec(string.format('watch %x (%s): %s', id, wname(e and e.type), reason))
end
local function watch_step(now)
  if now < R.next_watch then return end
  local fast = false
  for _, w in pairs(R.watch) do if now - w.since < WATCH_FAST then fast = true end end
  R.next_watch = now + (fast and 0.25 or 2)
  local mx, my, mz
  if R.avunit then mx, my, mz = unit_position(R.avunit) end
  for id, w in pairs(R.watch) do
    if now - w.since > WATCH_SECONDS and R.support ~= id then R.watch[id] = nil; rec(string.format('watch %x: stopped after %d s', id, WATCH_SECONDS))
    else
      local e = entity(id)
      local x, y, z
      if e then x, y, z = unit_position(e.unit) end
      local dist = (x and mx) and math.sqrt((x - mx) ^ 2 + (y - my) ^ 2 + (z - mz) ^ 2) or nil
      local r, idx, en = interactable_record(id)
      local line = string.format('entity %s; interactable %s; at %s; %s from you',
        e and string.format('%s unit %x flags %02x', wname(e.type), e.unit, e.flags) or 'gone',
        idx and string.format('slot %d enabled %s', idx, en) or 'no',
        x and string.format('%.1f %.1f %.1f', x, y, z) or '?', dist and string.format('%.1f m', dist) or '?')
      -- a line when something other than the position changed, or the weapon moved more than 0.3 m
      local key = line:gsub('at [^;]+; [^;]+ from you', '')
      local moved = x and w.x and ((x - w.x) ^ 2 + (y - w.y) ^ 2 + (z - w.z) ^ 2) > 0.09
      if key ~= w.last or moved or (x and not w.x) then
        rec(string.format('watch %x: %s', id, line))
        w.last, w.x, w.y, w.z = key, x, y, z
      end
      if r then
        if not w.irec then rec(string.format('watch %x: interactable record (%d bytes) %s', id, #r, hex(r)))
        elseif r ~= w.irec then local d, n = diff(w.irec, r, 16, 'irec' .. id); if n > 0 then rec(string.format('watch %x: interactable record changed %s', id, d)) end end
        w.irec = r
      end
      if not e then R.watch[id] = nil; rec(string.format('watch %x: its entity is gone - stopped', id)) end
    end
  end
end

-- your interactor: its target (what you look at) and its pending request
local function interactor_step()
  local mgr = read_ptr(G.imgr); if not mgr then return end
  if not fetch(mgr, G.ihead) then return end
  local n, list, insts = b32(G.icount), bptr(G.ilist), bptr(G.iinsts)
  if not (list and insts) or n > 64 or n == 0 then return end
  if not fetch(list, n * 8) then return end
  local infos = {}
  for k = 0, n - 1 do infos[k] = bptr(k * 8) end
  for k = 0, n - 1 do
    local info = infos[k]
    if info and fetch(info, 0x18) and b8(0x14) % 2 == 1 then
      local player = b32(G.iplayer)
      local inst = insts + k * G.istride
      local head = read_string(inst, 0x40)
      local req = read_string(inst + G.ireq, 0x18)
      if head and head ~= R.inter_last then
        if R.inter_last then
          local d, nd = diff(R.inter_last, head, 8, 'interactor')
          if nd > 0 then rec(string.format('interactor %d (player %x): %s', k, player, d)) end
        end
        R.inter_last = head
      end
      if req and req ~= R.inter_req then
        rec(string.format('interactor %d (player %x): request %s (target %s, interaction %d)', k, player, hex(req),
          describe(su32(req, 8)), su32(req, 12)))
        R.inter_req = req
      end
      return
    end
  end
end

-- key presses: names of the buttons pressed this frame (keyboard, mouse, controller 1)
local function pressed_names(dev)
  if type(dev) ~= 'table' and type(dev) ~= 'userdata' then return nil end
  local ok, any = pcall(function() return dev.any_pressed() end)
  if not ok or not any then return nil end
  local names = {}
  local okn, n = pcall(function() return dev.num_buttons() end)
  if okn and type(n) == 'number' then
    for i = 0, math.min(n, 512) - 1 do
      local okp, p = pcall(dev.pressed, i)
      if okp and p and p ~= 0 then
        local okb, nm = pcall(dev.button_name, i)
        names[#names + 1] = (okb and nm) and tostring(nm) or ('#' .. i)
      end
    end
  else names[1] = '(a button; names not available)' end
  return names
end
local function input_step(now)
  local SR = rawget(_G, 'stingray') or _G
  local all = {}
  for _, d in ipairs({ { 'key', rawget(_G, 'Keyboard') or SR.Keyboard }, { 'mouse', rawget(_G, 'Mouse') or SR.Mouse },
                       { 'pad', rawget(_G, 'Pad1') or SR.Pad1 } }) do
    local ok, names = pcall(pressed_names, d[2])
    if ok and names and #names > 0 then all[#all + 1] = d[1] .. ' ' .. table.concat(names, '+') end
  end
  if R.press_repeat > 0 and now - R.last_press_t >= 0.6 then      -- a run of the same press has ended
    rec(string.format('pressed: (%s again %d more times)', R.last_press, R.press_repeat))
    R.press_repeat = 0
  end
  if #all == 0 then return end
  local txt = table.concat(all, ', ')
  if txt == R.last_press and now - R.last_press_t < 0.6 then
    R.press_repeat, R.last_press_t = R.press_repeat + 1, now
    return
  end
  if R.press_repeat > 0 then rec(string.format('pressed: (%s again %d more times)', R.last_press, R.press_repeat)) end
  R.last_press, R.last_press_t, R.press_repeat = txt, now, 0
  rec('pressed: ' .. txt)
end

-- the engine side (asked once, then once after each swap): which functions exist, what units look like
local function lua_probe(why, wanted)
  local SR = rawget(_G, 'stingray') or _G
  local W, U = SR.World or rawget(_G, 'World'), SR.Unit or rawget(_G, 'Unit')
  local A = SR.Application or rawget(_G, 'Application')
  if not R.api_noted then
    R.api_noted = true
    local have = {}
    for _, f in ipairs({ 'link_unit', 'unlink_unit', 'spawn_unit', 'destroy_unit', 'units', 'units_by_resource', 'update_unit',
                         'update_unit_and_children' }) do
      have[#have + 1] = 'World.' .. f .. (W and type(W[f]) == 'function' and ' yes' or ' no')
    end
    for _, f in ipairs({ 'set_unit_visibility', 'set_mesh_visibility', 'num_meshes', 'has_node', 'node', 'world_position',
                         'local_position', 'set_local_position', 'teleport_local_position', 'alive', 'is_a', 'id_string',
                         'num_scene_graph_items', 'scene_graph_parent', 'set_flow_variable', 'world_rotation',
                         'teleport_local_rotation', 'set_local_rotation', 'disable_physics', 'enable_physics',
                         'set_local_pose', 'teleport_local_pose', 'world_pose' }) do
      have[#have + 1] = 'Unit.' .. f .. (U and type(U[f]) == 'function' and ' yes' or ' no')
    end
    rec('engine: ' .. table.concat(have, ', '))
  end
  if not (W and U and A and type(A.main_world) == 'function' and type(W.units) == 'function') then return end
  local okw, world = pcall(A.main_world)
  if not okw or not world then rec('engine: no main world (' .. why .. ')'); return end
  local oku, list = pcall(W.units, world)
  if not oku or type(list) ~= 'table' then rec('engine: World.units failed (' .. why .. ')'); return end
  local t0 = os.clock()
  local found, samples = {}, 0
  for _, u in ipairs(list) do
    local oks, name = pcall(tostring, u)
    if oks and type(name) == 'string' then
      if not R.sampled and samples < 3 then samples = samples + 1; rec('engine: a unit looks like ' .. name) end
      for key, label in pairs(wanted) do
        if name:find(key, 1, true) then found[#found + 1] = { u = u, name = name, label = label } end
      end
    end
  end
  R.sampled = true
  rec(string.format('engine (%s): %d units in the world, %d of interest (%.1f ms)', why, #list, #found, (os.clock() - t0) * 1000))
  for k, f in ipairs(found) do
    if k > 12 then break end
    local u = f.u
    local parts = { f.label, f.name }
    local okA, alive = pcall(U.alive, u)
    parts[#parts + 1] = 'alive ' .. tostring(okA and alive)
    if okA and alive then
      for _, node in ipairs({ 'root', 'support', 'support_mg', 'backpack', 'attach_hand_r', 'StingrayEntityRoot' }) do
        local okh, has = pcall(U.has_node, u, node)
        if okh and has then parts[#parts + 1] = 'node ' .. node end
      end
      local okh, has = pcall(U.has_node, u, 'root')
      if okh and has then
        local okn, n = pcall(U.node, u, 'root')
        if okn and type(n) == 'number' then
          local okp, p = pcall(U.world_position, u, n)
          if okp and p then
            local okx, x, y, z = pcall(function() return p.x, p.y, p.z end)
            if okx and type(x) == 'number' then parts[#parts + 1] = string.format('at %.1f %.1f %.1f', x, y, z) end
          end
        end
      end
      if type(U.num_meshes) == 'function' then local okm, m = pcall(U.num_meshes, u); if okm then parts[#parts + 1] = 'meshes ' .. tostring(m) end end
    end
    rec('engine: ' .. table.concat(parts, ', '))
  end
end

-- your equipment record, every frame: a change is logged with what each slot holds; a support weapon that leaves
-- the support slot for an expendable is followed
local function equip_step(now)
  local h = avatar()
  if h ~= R.avh then
    R.avh, R.av, R.avunit, R.eq, R.last_eq = h, nil, nil, nil, nil
    if not h then rec('no helldiver of yours (ship, menus, or dead)'); return end
    local me = avatar_row(h)
    if not me then rec(string.format('your helldiver: handle %x has no entity row', h)); return end
    R.av, R.avunit = me.rid, me.unit
    rec(string.format('your helldiver: handle %x -> entity %s', h, describe(me.rid)))
    -- the engine side once per helldiver: its unit and nodes (and your weapons', added when the equipment is read)
    if VERBOSE then R.lua_probe, R.probe_keys = now + 3, { [AVATAR_TYPE] = 'your helldiver?' } end
    R.probe_why = 'your helldiver'
    if me.type ~= AVATAR_TYPE or bit.band(me.flags, 3) ~= 1 then
      rec(string.format('  (not a helldiver of yours: type %s flags %02x)', me.type, me.flags)); R.av = nil
    end
  end
  local av = R.av
  if not av then return end
  local ea = equip_addr(av)
  if not ea then if R.eq ~= false then rec('your equipment record: not found'); R.eq = false end; return end
  R.eq = ea
  local s = read_string(ea, 48)
  if not s then return end
  R.held = su32(s, 28)                            -- +0x1C: the slot in your hands (1 primary, 2 secondary, 3 support, 5 throwable)
  R.support = su32(s, 8)
  if s == R.last_eq then return end
  local old = R.last_eq
  R.last_eq = s
  if not old then
    rec('equipment: ' .. slots_text(s) .. ' | rest ' .. hex(s:sub(25)))
    if R.lua_probe and R.probe_keys then
      for k = 0, 3 do local e = entity(su32(s, 4 * k)); if e then R.probe_keys[e.type] = 'your ' .. SLOT_NAMES[k] .. ' (' .. wname(e.type) .. ')' end end
    end
    return
  end
  local was, now_id = su32(old, 8), su32(s, 8)
  if VERBOSE or was ~= now_id then rec('equipment changed (' .. diff(old, s, 8) .. '): ' .. slots_text(s)) end
  if was ~= now_id then
    local ew, en = entity(was), entity(now_id)
    local w_exp = ew and WEAPONS[ew.type] and WEAPONS[ew.type][2]
    local n_exp = en and WEAPONS[en.type] and WEAPONS[en.type][2]
    if VERBOSE and now_id ~= 0 and now_id ~= 0xFFFFFFFF and en and WEAPONS[en.type] then start_watch(now_id, 'now in your support slot') end
    if VERBOSE and was ~= 0 and was ~= 0xFFFFFFFF then
      start_watch(was, n_exp and 'set down for an expendable' or (now_id == 0 and 'left the support slot (dropped, used up or died)' or 'replaced'))
    end
    if n_exp and ew and not w_exp then
      stats.swaps = stats.swaps + 1
      R.carry_swap = { w = was, x = now_id, wt = ew.type, xt = en.type, at = now }   -- (the carry takes it from here)
      rec(string.format('you picked up the %s; the game set your %s down', wname(en.type), wname(ew.type)))
      if VERBOSE then
        local keys = R.lua_probe and R.probe_keys or {}     -- (a probe still waiting is merged into this one)
        keys[AVATAR_TYPE], keys[ew.type], keys[en.type] = 'your helldiver?', 'your ' .. wname(ew.type), 'the ' .. wname(en.type)
        R.lua_probe, R.probe_why, R.probe_keys = now + 1.0, 'after a swap', keys
      end
    elseif w_exp and (now_id == 0 or now_id == 0xFFFFFFFF) then
      rec(string.format('your %s left your hands (used up or dropped); support slot empty', wname(ew.type)))
    elseif w_exp and en then
      rec(string.format('your %s was swapped for the %s', wname(ew.type), wname(en.type)))
    end
  end
end

local carry_step
local write_log_now          -- (the log writer, defined below: flushed right before a call into the game)

-- ======================================================================================================
-- The carry: your support weapon on your back while the expendable is in your hands
-- ======================================================================================================
local JOINED_WINDOW = 3.0     -- seconds: a pickup that came with a request to a host is a joined game's (left alone)
local SWAP_HOLD = 0.3         -- seconds the expendable must be in your hands before the support key swaps back
local DRAW_DELAY = 0.4        -- seconds after picking an expendable up with another weapon in hand before it is drawn
local PICKUP_TYPE = 3         -- the interaction type of a support weapon pickup (PickupWeaponSupport)
local ENTRY, ENTRY_TYPE, ENTRY_ON = 0x68, 0x44, 0x60   -- an interaction in an interactable's record: size, type, 'on'
-- each weapon that can sit in the support slot, by entity type: its holster node and offsets (the weapon's own
-- Equipment data: position in m, then rotation in degrees on x, y, z). From the game's data (Oct 2026 build).
local HOLSTER = {
  ['bf4cfd2aeabfb5a4'] = { 'support_mg', 0.05, -0.1, -0.2, -90, 0, 0 },   -- CQC-9 Defoliation Tool
  ['b0f1b354ba1d38d8'] = { 'support_mg', -0.05, 0.05, 0, 60, 5, 60 },   -- CQC-1 One True Flag
  ['5f3ec9bda2bd8553'] = { 'support_mg', 0.02, -0.22, -0.25, -100, 0, 0 },   -- CQC-20 Breaching Hammer
  ['e85e623f93f96fb3'] = { 'support', -0.05, 0.03, -0.25, -90, 0, 180 },   -- CQC-72 Entrenchment Tool
  ['4f8a477e577aaba9'] = { 'support_mg' },   -- ?
  ['a6a735accb4a327f'] = { 'support_mg' },   -- M-105 Stalwart
  ['b43235dbd493750c'] = { 'support_mg' },   -- M-105 Stalwart
  ['b9606c5aab32c3c2'] = { 'support_mg' },   -- M-105 Stalwart
  ['d53ee03481ae73fd'] = { 'support_mg' },   -- M-105 Stalwart
  ['26e40437ea275296'] = { 'support' },   -- RL-77 Airburst Rocket Launcher
  ['96de9cd50f7306e6'] = { 'support_mg' },   -- ARC-3 Arc Thrower
  ['a8cffb316f0b5c5f'] = { 'support' },   -- AC-8 Autocannon
  ['88c2d09ad85a7c9f'] = { 'support_mg', -0.01, -0.1, 0.15, 15, 0, 0 },   -- GL-28 Belt-Fed Grenade Launcher
  ['88f61afff48ac8a4'] = { 'support_mg', 0, -0.4, 0.3, -10, 0, 0 },   -- TX-41 Sterilizer
  ['6cfcc7f8801a0266'] = { 'support_mg', 0.05, -0.075, 0.075, 15, 0, 0 },   -- 40-K Meltagun
  ['b16c9d490aa59b77'] = { 'support_mg', 0.02, 0, 0.02, 0, 0, 0 },   -- MGX-42 Bullet Storm
  ['7617642765ac38c7'] = { 'support' },   -- EAT-411 Leveller
  ['b2b5e0d185605f9e'] = { 'support' },   -- EAT-700 Expendable Napalm
  ['25aa2fd4643cf4ee'] = { 'support' },   -- FAF-14 Spear
  ['cc786f6491fe7e65'] = { 'support', 0.015, -0.2625, -0.125, -180, 0, 0 },   -- StA-X3 W.A.S.P. Launcher
  ['39ab99895147a3bf'] = { 'support_mg', 0, -0.35, 0.2, -5, 0, 0 },   -- FLAM-40 Flamethrower
  ['02eecd0b1fa49630'] = { 'support_mg' },   -- GL-21 Grenade Launcher
  ['1d5943301a29c940'] = { 'support_mg' },   -- E/GL-21 Grenadier Battlement
  ['fe3b29b2cfa63f9b'] = { 'support_mg' },   -- GL-52 De-Escalator
  ['3828e2051aa9e897'] = { 'support_mg' },   -- S-11 Speargun
  ['78a8185f63a70795'] = { 'support_mg', 0, -0.35, 0.2, -5, 0, 0 },   -- B/FLAM-80 Cremator
  ['2152d5147b0ac418'] = { 'support_mg' },   -- MG-206 Heavy Machine Gun
  ['d54b9505c0f72873'] = { 'support' },   -- LAS-98 Laser Cannon
  ['5990123d142b16cb'] = { 'support' },   -- MLS-4X Commando
  ['35a61296619cc47e'] = { 'support' },   -- LAS-99 Quasar Cannon
  ['5c54e81a4aaa31fc'] = { 'support' },   -- ?
  ['80932fa0ed6901d3'] = { 'support' },   -- EAT-17 Expendable Anti-Tank
  ['11c27d3babb38956'] = { 'support_mg' },   -- MG-43 Machine Gun
  ['43a58cb89cfa197c'] = { 'support_mg', -0.01, -0.1, 0.15, 15, 0, 0 },   -- M-1000 Maxigun
  ['e8d5f49ad7780e54'] = { 'support', 0, -0.1, -0.1, 0, 0, 0 },   -- PLAS-45 Epoch
  ['2e9d0bdc48b09e60'] = { 'support_mg' },   -- RS-422 Railgun
  ['9f80d67a12a7e40f'] = { 'support' },   -- GR-8 Recoilless Rifle
  ['89c5493e08ca4207'] = { 'support_mg' },   -- APW-1 Anti-Materiel Rifle
  ['085c1edb038ec24e'] = { 'support_mg' },   -- MG-206 Heavy Machine Gun
  ['cd00bdc1149c2928'] = { 'support_mg' },   -- MG-206 Heavy Machine Gun
  ['444880f62ca7eae8'] = { 'support_mg', 0, -0.35, 0.2, -5, 0, 0 },   -- B/FLAM-80 Cremator
  ['52071f49263415e4'] = { 'support_mg', 0.02, 0.12, 0.18, 0, 0, 0 },   -- SG-88 Break-Action Shotgun
  ['372481e910c05a76'] = { 'support' },   -- TACTICAL VIDEO CAMERA
  ['8e7968d7e7aa4eab'] = { 'support' },   -- (unnamed support-slot equipment)
  ['f2b4a99d1b0e40c8'] = { 'support' },   -- (unnamed support-slot equipment)
}
local function holster_of(t) return HOLSTER[t] end
-- each weapon's own weapon-switch (wield) sound: its Equipment data's weapon_switch_wield_audio_event (Oct 2026 build;
-- the TX-41 Sterilizer has none, so it is drawn silently, as in the game)
local WIELD_SOUND = {
  ['02eecd0b1fa49630'] = 0x78aa7817,
  ['085c1edb038ec24e'] = 0x2c9eda11,
  ['11c27d3babb38956'] = 0xba0b5c9e,
  ['1d5943301a29c940'] = 0x78aa7817,
  ['2152d5147b0ac418'] = 0x2c9eda11,
  ['25aa2fd4643cf4ee'] = 0x4654fbbb,
  ['26e40437ea275296'] = 0xc86f149f,
  ['2e9d0bdc48b09e60'] = 0x4d77d9df,
  ['35a61296619cc47e'] = 0xfb3feb70,
  ['372481e910c05a76'] = 0x425e2570,
  ['3828e2051aa9e897'] = 0x63f520e6,
  ['39ab99895147a3bf'] = 0xc1f5f5ee,
  ['43a58cb89cfa197c'] = 0x7b877f5f,
  ['444880f62ca7eae8'] = 0xc1f5f5ee,
  ['52071f49263415e4'] = 0x0079f5d9,
  ['5990123d142b16cb'] = 0xc7bfa622,
  ['5f3ec9bda2bd8553'] = 0x46672885,
  ['6cfcc7f8801a0266'] = 0x780b797f,
  ['7617642765ac38c7'] = 0x9231c925,
  ['78a8185f63a70795'] = 0xdabba291,
  ['80932fa0ed6901d3'] = 0x2c25aac2,
  ['88c2d09ad85a7c9f'] = 0xbd14b435,
  ['89c5493e08ca4207'] = 0xf4713b94,
  ['96de9cd50f7306e6'] = 0x285bc547,
  ['9f80d67a12a7e40f'] = 0x9de9946f,
  ['a6a735accb4a327f'] = 0xc10e40e3,
  ['a8cffb316f0b5c5f'] = 0xea3aff5a,
  ['b0f1b354ba1d38d8'] = 0xa47794fb,
  ['b16c9d490aa59b77'] = 0xba0b5c9e,
  ['b2b5e0d185605f9e'] = 0x2c25aac2,
  ['b43235dbd493750c'] = 0xc10e40e3,
  ['b9606c5aab32c3c2'] = 0xc10e40e3,
  ['bf4cfd2aeabfb5a4'] = 0x90e8e3b4,
  ['cc786f6491fe7e65'] = 0x7438440d,
  ['cd00bdc1149c2928'] = 0x2c9eda11,
  ['fc13460592ca79aa'] = 0x01172d4c,   -- Solo Silo Targeting Remote
  ['d53ee03481ae73fd'] = 0xc10e40e3,
  ['d54b9505c0f72873'] = 0x4a3bb277,
  ['e85e623f93f96fb3'] = 0x226f3059,
  ['e8d5f49ad7780e54'] = 0x8d4464e2,
  ['fe3b29b2cfa63f9b'] = 0xf79992df,
}

local REGION = ffi.new('EcRegion[1]')
local function writable(addr, n)
  if K32.EcVirtualQuery(ffi.cast('const void *', addr), REGION, ffi.sizeof('EcRegion')) == 0 then return false end
  local r = REGION[0]
  local base = tonumber(ffi.cast('uintptr_t', r.base))
  return r.state == 0x1000 and r.type == 0x20000 and r.protect == 0x04 and addr + n <= base + tonumber(r.size)
end
local HELD_AT = 28            -- equipment record +0x1C: the slot in your hands (1 primary, 2 secondary, 3 support, 5 throwable)
local function write_u32(addr, v)
  if not writable(addr, 4) then return false end
  local b = ffi.new('uint32_t[1]', v)
  if K32.EcWriteProcessMemory(PROCESS, ffi.cast('void *', addr), b, 4, DONE) == 0 or DONE[0] ~= 4 then return false end
  return fetch(addr, 4) and b32(0) == v
end
local function write_u8(addr, v)
  if not writable(addr, 1) then return false end
  local b = ffi.new('uint8_t[1]', v)
  if K32.EcWriteProcessMemory(PROCESS, ffi.cast('void *', addr), b, 1, DONE) == 0 or DONE[0] ~= 1 then return false end
  return fetch(addr, 1) and b8(0) == v
end

-- a weapon's support pickup: the address of its interaction entry and its index ('which'), or nil + why
local function pickup_entry(eid)
  local idx, im = interactable(eid)
  if not idx then return nil, 'not an interactable' end
  local recs = read_ptr(im + G.im_buckets + 0x20)
  if not recs then return nil, 'no interactable records' end
  local r = recs + idx * IREC
  local n = read_u32(r + 0x340)
  if not n or n == 0 or n > 8 then return nil, 'interaction count ' .. tostring(n) end
  for i = 0, n - 1 do
    if read_u32(r + i * ENTRY + ENTRY_TYPE) == PICKUP_TYPE then return r + i * ENTRY, i end
  end
  return nil, 'no support pickup among its ' .. n .. ' interactions'
end

-- the same entry again, by the index found at the swap (while locked its type reads 0, so it can't be searched for)
local function entry_of(st)
  local idx, im = interactable(st.w)
  if not idx then return nil end
  local recs = read_ptr(im + G.im_buckets + 0x20)
  if not recs then return nil end
  local e = recs + idx * IREC + st.which * ENTRY
  local t = read_u32(e + ENTRY_TYPE)
  if t ~= PICKUP_TYPE and t ~= 0 then return nil end
  return e, t
end

-- the pick-up switched off and kept off the game's own way, while your weapon is on your back (the game turns the
-- entry's 'on' byte back on every frame, so turning that byte off alone leaves a flickering prompt). The game's
-- switch turns that interaction off (its enabled bit; the change
-- goes to the other players' games too) and the interactable's 'blocked' byte keeps anything from turning it on again,
-- and the 'on' byte is still turned off every frame. Both are undone before the weapon is equipped or set down.
local ISWITCH = ffi.typeof('void (*)(void *, uint32_t, uint32_t, uint8_t)')
local function switch_rec(eid)
  local idx, im = interactable(eid)
  if not idx then return nil end
  local bits = read_ptr(im + G.im_buckets + 0x28)
  return bits and bits + idx * G.isw.stride, im
end
local function game_switch(im, eid, which, on)
  ffi.cast(ISWITCH, G.isw.fn)(ffi.cast('void *', im), eid, which, on and 1 or 0)
end
local function pickup_disable(st)
  if not G.isw then return 'not switched off (the switch was not found)' end
  local b, im = switch_rec(st.w)
  if not b then return 'not switched off (its switch record was not found)' end
  write_log_now()
  local ok, e = pcall(game_switch, im, st.w, st.which, false)
  if not ok then return 'switch error: ' .. tostring(e) end
  st.switched = true
  if fetch(b + G.isw.block, 1) and b8(0) == 0 and write_u8(b + G.isw.block, 1) then st.blocked = true end
  local en = read_u32(b)
  return string.format('switched off by the game (enabled bits now %s)%s', en and string.format('%x', en) or '?',
    st.blocked and ', blocked' or ', NOT blocked')
end
local function pickup_enable(st)
  if not st.switched then return nil end
  st.switched = false
  local b, im = switch_rec(st.w)
  if not b then return 'its switch record was not found' end
  if st.blocked then write_u8(b + G.isw.block, 0); st.blocked = false end
  write_log_now()
  local ok, e = pcall(game_switch, im, st.w, st.which, true)
  return ok and 'switched on by the game' or ('switch error: ' .. tostring(e))
end

local function engine()
  local SR = rawget(_G, 'stingray') or _G
  return SR.World or rawget(_G, 'World'), SR.Unit or rawget(_G, 'Unit'), SR.Application or rawget(_G, 'Application'),
    SR.Actor or rawget(_G, 'Actor'), SR.Vector3 or rawget(_G, 'Vector3'), SR.Quaternion or rawget(_G, 'Quaternion')
end
local function v3(v)
  local ok, x, y, z = pcall(function() return v.x, v.y, v.z end)
  if ok and type(x) == 'number' then return x, y, z end
  return nil
end
local C = { stash = nil, swaps = 0, back = 0, auto = 0, released = 0, joined = 0, failed = 0 }
-- the game's own routines (the same calls, in the same order, as its weapon pickup minus the pickup itself):
-- set the support slot (it drops what the slot held), tell the other players' games, then the wield request (the
-- weapon-switch animation and sound)
local SETSLOT = ffi.typeof('void (*)(void *, uint32_t, uint32_t, uint32_t, uint8_t)')
local NETSLOT = ffi.typeof('void (*)(int64_t, uint32_t, uint32_t, uint32_t)')
local WIELD = ffi.typeof('void (*)(void *, uint32_t, uint32_t)')
local WIELD2 = ffi.typeof('void (*)(void *)')
local function game_equip(eqm, player, w, wield_rec)
  ffi.cast(SETSLOT, G.setslot)(ffi.cast('void *', eqm), player, w, 3, 0)
  ffi.cast(NETSLOT, G.netslot)(-2, player, w, 3)
  if wield_rec then
    ffi.cast(WIELD, G.wield)(ffi.cast('void *', wield_rec), 3, 0)
    ffi.cast(WIELD2, G.wield2)(ffi.cast('void *', wield_rec))
  end
end
-- the weapon's own weapon-switch sound, the way the game's wield handler plays it: on the weapon's audio source, with
-- the first- or third-person mix set first. (The audio API's functions are not in game.dll or the exe - the audio
-- engine is its own module - so a function is checked to be in loaded code of any module, and named.)
local AUD_ARG = ffi.typeof('void *(*)(void *)')
local AUD_UNIT = ffi.typeof('void *(*)(uint32_t)')
local AUD_SRC = ffi.typeof('uint64_t (*)(void *, void *, uint64_t)')
local AUD_PLAY = ffi.typeof('void (*)(uint32_t, uint64_t, uint64_t)')
local AUD_PERSP = ffi.typeof('uint32_t (*)(void *, uint32_t)')
local AUD_PARAM = ffi.typeof('void (*)(uint64_t, const char *, float)')
local function code_at(p)
  if not p or p == 0 then return false end
  if K32.EcVirtualQuery(ffi.cast('const void *', p), REGION, ffi.sizeof('EcRegion')) == 0 then return false end
  local r = REGION[0]
  return r.state == 0x1000 and r.type == 0x1000000 and bit.band(r.protect, 0xF0) ~= 0
end
local MODNAME = ffi.new('char[260]')
local MODH = ffi.new('void *[1]')
local function module_of(p)
  if not p then return '?' end
  if K32.EcGetModuleHandleExA(6, ffi.cast('const void *', p), MODH) == 0 then return string.format('%x (no module)', p) end
  local n = K32.EcGetModuleFileNameA(MODH[0], MODNAME, 260)
  local name = n > 0 and ffi.string(MODNAME, n):match('[^\\/]+$') or '?'
  return string.format('%s+%x', name, p - tonumber(ffi.cast('uintptr_t', MODH[0])))
end
local UNIT_ALIVE = ffi.typeof('uint8_t (*)(uint32_t)')
-- is this unit alive, by the entity API's own check (safe for any number: the game calls it on ids it is not sure
-- of). The node lookup wants a unit, not an entity id, and reads whatever it is given, so every unit is checked with
-- this before it is handed to the API.
local function unit_alive(u)
  local A = G.att
  if not (A and u and u ~= 0) then return false end
  local ent = read_ptr(A.ent); local tbl = ent and read_ptr(ent + A.node_tbl)
  local f = tbl and read_ptr(tbl + A.alive_fn)
  if not code_at(f) then return false end
  return ffi.cast(UNIT_ALIVE, f)(u) ~= 0
end
local function game_sound(event, weapon_unit, wielder)
  local a = G.audio
  local api = read_ptr(a.api); local wb = read_ptr(a.wb); local ent = read_ptr(a.ent)
  if not (api and wb and ent) then return 'audio tables not readable' end
  local f_arg, f_src, f_play = read_ptr(api + a.arg_fn), read_ptr(api + a.src_fn), read_ptr(api + a.play_fn)
  local tbl = read_ptr(ent + a.ent_tbl); local f_unit = tbl and read_ptr(tbl + a.unit_fn)
  local pp = a.persp
  local f_param = pp and read_ptr(api + pp.param_fn)
  if not a.logged then
    a.logged = true
    rec(string.format('carry: sound functions: world %s, unit %s, source %s, play %s, mix %s', module_of(f_arg),
      module_of(f_unit), module_of(f_src), module_of(f_play), pp and module_of(f_param) or 'none'))
  end
  if not (code_at(f_arg) and code_at(f_src) and code_at(f_play) and code_at(f_unit)) then return 'an audio function is not in loaded code' end
  if not unit_alive(weapon_unit) then return 'the weapon\'s unit is not alive' end
  local arg = read_ptr(wb + a.wb_off)
  if not arg then return 'no audio world argument' end
  local none = read_u64(api)
  local aw = ffi.cast(AUD_ARG, f_arg)(ffi.cast('void *', arg))
  local unit = ffi.cast(AUD_UNIT, f_unit)(weapon_unit)
  if aw == nil or unit == nil then return 'no audio world or unit' end
  local src = ffi.cast(AUD_SRC, f_src)(aw, unit, 0)
  if src == 0 or (none and tonumber(src) == none) then return 'no audio source' end
  local mix = 'no mix'
  if pp and code_at(f_param) then
    local sm = read_ptr(G.state)
    if sm then
      local v = ffi.cast(AUD_PERSP, pp.fn)(ffi.cast('void *', sm), wielder)
      ffi.cast(AUD_PARAM, f_param)(src, ffi.cast('const char *', pp.name), tonumber(v))
      mix = 'mix ' .. tostring(tonumber(v))
    end
  end
  ffi.cast(AUD_PLAY, f_play)(event, src, 0)
  return nil, mix
end

-- the game's attachables. A copy spawned by a mod is drawn where it was spawned, whatever the engine says about its
-- position (the game draws its units from its own entities), so your real weapon is put on your back by the game itself, with the attach it uses for every holstered weapon (weapon, helldiver, node,
-- position offset, rotation, lerp time; it pauses the weapon's physics itself, and its detach turns them back on).
local ATTACH = ffi.typeof('void (*)(void *, uint32_t, uint32_t, uint32_t, const float *, const float *, float)')
local DETACH = ffi.typeof('void (*)(void *, uint32_t, uint8_t, uint64_t)')
local NODE_INDEX = ffi.typeof('uint32_t (*)(uint32_t, uint32_t)')
local NODE_HASH = { support = 0xe80d437b, support_mg = 0x07fa5ada }   -- the holster nodes' names (thin hashes)
-- the position and rotation handed to the attach (the rotation on a 16-byte boundary: the game reads it in one aligned
-- load). The buffer is used by game_attach itself, so it stays alive as long as the mod does (a buffer only pointed to
-- by a cast would be freed by the garbage collector).
local ATT_BUF = ffi.new('float[12]')
-- what an entity is attached to (its attachables record's first word), or nil when that can't be read
local function attached_to(id)
  local A = G.att
  if not (A and A.map) then return nil end
  local m = read_ptr(A.mgr); if not m then return nil end
  local i = map_get(m + A.map, id, 0x100000)
  if not i then return 0 end
  local recs = read_ptr(m + A.recs)
  return recs and read_u32(recs + i * A.stride) or nil
end
-- the holster rotation (degrees on x, y, z) as the game makes it: half angles, then the same products as its handler
local function holster_rotation(q, rx, ry, rz)
  local k = 0.017453292 * 0.5
  local cx, sx = math.cos(rx * k), math.sin(rx * k)
  local cy, sy = math.cos(ry * k), math.sin(ry * k)
  local cz, sz = math.cos(rz * k), math.sin(rz * k)
  q[0] = sz * sy * cx + cz * sx * cy
  q[1] = cz * sy * cx - sz * sx * cy
  q[2] = cz * sx * sy + sz * cx * cy
  q[3] = cz * cx * cy - sz * sx * sy
end
local function game_attach(w, parent, node, h)     -- (w: the weapon's entity id; parent: your helldiver's UNIT)
  local A = G.att
  if not unit_alive(parent) then return nil, 'your helldiver\'s unit is not alive for the game' end
  local ent = read_ptr(A.ent); local tbl = ent and read_ptr(ent + A.node_tbl)
  local f_node = tbl and read_ptr(tbl + A.node_fn)
  if not code_at(f_node) then return nil, 'the node lookup is not in loaded code' end
  local ni = ffi.cast(NODE_INDEX, f_node)(parent, NODE_HASH[node])
  ni = tonumber(ni)
  if ni == 0xFFFFFFFF or ni > 0x10000 then return nil, 'your helldiver has no ' .. node .. ' node' end
  local at = tonumber(ffi.cast('uintptr_t', ATT_BUF))
  local pos, rot = ATT_BUF, ATT_BUF + ((at + 31) - (at + 31) % 16 - at) / 4
  pos[0], pos[1], pos[2] = h[2] or 0, h[3] or 0, h[4] or 0
  holster_rotation(rot, h[5] or 0, h[6] or 0, h[7] or 0)
  local m = read_ptr(A.mgr); if not m then return nil, 'no attachables' end
  ffi.cast(ATTACH, A.attach)(ffi.cast('void *', m), w, parent, ni, pos, rot, 0)
  return ni
end
local function game_detach(w)
  local m = read_ptr(G.att.mgr); if not m then return false end
  ffi.cast(DETACH, G.att.detach)(ffi.cast('void *', m), w, 0, 0)
  return true
end
local function no_jit(fn)
  local j = rawget(_G, 'jit')
  if type(j) == 'table' and type(j.off) == 'function' then pcall(j.off, fn) end
end
no_jit(game_equip)
local function game_wield(wield_rec)
  ffi.cast(WIELD, G.wield)(ffi.cast('void *', wield_rec), 3, 0)
  ffi.cast(WIELD2, G.wield2)(ffi.cast('void *', wield_rec))
end
no_jit(game_wield)
no_jit(game_sound)
no_jit(game_attach)
no_jit(game_switch)
no_jit(game_detach)

-- off your back (the game's detach: its physics back on), unlocked, its pick-up on (when it was the mod that turned it off)
local function unstash(st, why)
  if st.remote then rec(string.format('carry (joined): your %s no longer carried (%s)', wname(st.wt), why)); return end
  local parts = {}
  if st.attached then
    write_log_now()
    local okd, e = pcall(game_detach, st.w)
    parts[#parts + 1] = okd and e and 'detached' or ('could NOT be detached (' .. tostring(e) .. ')')
    st.attached = false
  end
  local e2, t = entry_of(st)
  if e2 and st.locked and t == 0 then
    parts[#parts + 1] = write_u8(e2 + ENTRY_TYPE, PICKUP_TYPE) and 'unlocked' or 'could NOT be unlocked'
  end
  local sw = pickup_enable(st)
  if sw then parts[#parts + 1] = 'its pick-up ' .. sw end
  if e2 and st.off and fetch(e2 + ENTRY_ON, 1) and b8(0) == 0 then
    parts[#parts + 1] = write_u8(e2 + ENTRY_ON, 1) and 'pick-up on' or 'pick-up could NOT be turned back on'
  end
  if (st.relit or 0) > 0 then parts[#parts + 1] = string.format('(the game turned its prompt back on %d times in %.0f s)', st.relit, os.clock() - st.since) end
  rec(string.format('carry: your %s off your back (%s): %s', wname(st.wt), why, table.concat(parts, ', ')))
end

-- onto your back: the weapon's own holster node and offsets (the other holster node when the expendable's is the same,
-- so the two never sit in one spot when you holster the expendable)
local function put_on_back(st, why, quiet)
  local h, hx = holster_of(st.wt), holster_of(st.xt)
  if not h then return 'no holster spot known for it' end
  if not G.att then return 'the game\'s attach was not found' end
  if not (R.av and R.avunit) then return 'no helldiver' end
  -- always the weapon's own holster node and offsets, the way the game holsters it (another node's holster rotation
  -- is made for other weapons and turns yours the wrong way). The expendable is in your hands, so the node is free.
  local node = h[1]
  if not quiet then
    rec(string.format('carry: attaching your %s (entity %x) to your helldiver (unit %x) on %s', wname(st.wt), st.w, R.avunit, node))
    write_log_now()
  end
  local ok, ni, e = pcall(game_attach, st.w, R.avunit, node, h)
  if not ok then return 'attach error: ' .. tostring(ni) end
  if not ni then return tostring(e) end
  st.attached, st.node = true, node
  local to = attached_to(st.w)
  st.verified = to == R.avunit
  return string.format('attached on %s (node %d) by the game%s', node, ni,
    to == nil and ', not checked' or to == R.avunit and ', checked' or string.format(', but its record says %x', to)) .. (why or '')
end

-- your support weapon was just set down for an expendable: locked, its pick-up off, on your back
-- Joined games: the host's game runs your pickups and owns your weapon
-- once it is set down, so your game can't lock it, attach it to your back or equip it. What it can do is what your own
-- E press does: send the host a pickup request for it, through the game's interaction routine (the same call Solo
-- Buddy Bunkers makes in joined games). The host's game carries a request out with no range check, so your support
-- weapon key gets it back from anywhere, mod or no mod on the host. The weapon lies where it was set down for everyone
-- (a teammate could take it: the carry then ends), and it comes back with the game's pickup animation and sound.
local REQ = ffi.typeof('void *(*)(void *, void *, uint32_t, uint32_t, uint32_t)')
local REQ_OUT = ffi.new('uint8_t[64]')
local function ask_host(w, which)
  ffi.fill(REQ_OUT, 64)
  ffi.cast(REQ, G.interact)(nil, REQ_OUT, w, R.av, which)
end
no_jit(ask_host)
local function remote_stash(sw, now)
  local function skip(why) rec('carry (joined): left alone - ' .. why); event('joined game: left your ' .. wname(sw.wt) .. ' where the game set it down: ' .. why) end
  if not G.interact then return skip('the game\'s interaction routine was not found') end
  if not R.av then return skip('no helldiver') end
  local _, which = pickup_entry(sw.w)
  local st = { remote = true, w = sw.w, x = sw.x, wt = sw.wt, xt = sw.xt, since = now, next_check = 0,
               which = type(which) == 'number' and which or nil, tries = 0 }
  C.stash = st
  C.joined = C.joined + 1
  rec(string.format('carry (joined): your %s (entity %x) set down by the host\'s game; its support pick-up: %s', wname(sw.wt), sw.w,
    st.which and ('interaction ' .. st.which) or ('not found yet (' .. tostring(which) .. ')')))
  event(string.format('joined game: you picked up the %s; your %s lies where it was set down - your support weapon key asks the host for it back, from anywhere',
    wname(sw.xt), wname(sw.wt)))
end

local function stash(sw, now)
  local function skip(why) rec('carry: left alone - ' .. why); event('left your ' .. wname(sw.wt) .. ' where the game set it down: ' .. why) end
  if R.req_t and now - R.req_t < JOINED_WINDOW then return remote_stash(sw, now) end
  local ew, ex = entity(sw.w), entity(sw.x)
  if not ew or bit.band(ew.flags, 3) ~= 1 then return skip('the weapon is not your game\'s') end
  if not ex or bit.band(ex.flags, 3) ~= 1 then return skip('the expendable is not your game\'s') end
  local entry, which = pickup_entry(sw.w)
  if not entry then return skip('its pick-up was not found (' .. tostring(which) .. ')') end
  if C.pending and C.pending.w == sw.w then          -- (it came back and was set down again before the 2 s check)
    local p = C.pending; C.pending = nil
    if p.why:find('used up', 1, true) then C.auto = C.auto + 1 else C.back = C.back + 1 end
  end
  local st = { w = sw.w, wu = ew.unit, x = sw.x, wt = sw.wt, xt = sw.xt, since = now, next_check = 0, which = which, tries = 0 }
  C.stash = st                 -- (carried from here on, so anything done below is always undone the usual way)
  local parts = {}
  -- locked: its support pick-up's type set to 'none', so your game (the host) does nothing when anyone, a teammate
  -- without the mod included, asks to pick it up; set back before it is equipped again or set down
  st.locked = write_u8(entry + ENTRY_TYPE, 0)
  parts[#parts + 1] = st.locked and 'locked' or 'could NOT be locked'
  parts[#parts + 1] = 'its pick-up ' .. pickup_disable(st)
  st.entry = entry
  parts[#parts + 1] = put_on_back(st)
  C.swaps = C.swaps + 1
  if R.held ~= 3 then st.draw_at = now + DRAW_DELAY end         -- (picked up with another weapon in hand: drawn; solo and host only)
  rec('carry: your ' .. wname(sw.wt) .. ' onto your back: ' .. table.concat(parts, ', '))
  event(string.format('you picked up the %s; your %s is %s', wname(sw.xt), wname(sw.wt),
    st.attached and 'on your back' or 'locked where it was set down (it could not be put on your back)'))
end

-- while carried: its pick-up kept off (the game turns it on a moment after setting it down), and kept on your back
local function keep(st, now)
  if st.remote then
    if now < st.next_check then return end
    st.next_check = now + 0.25
    if not interactable(st.w) then return 'gone' end
    if not st.which then local _, wh = pickup_entry(st.w); if type(wh) == 'number' then st.which = wh end end
    return
  end
  if st.entry and fetch(st.entry + ENTRY_ON, 1) and b8(0) ~= 0 then      -- (every frame: one byte)
    if write_u8(st.entry + ENTRY_ON, 0) then st.relit, st.off = (st.relit or 0) + 1, true end
  end
  if now < st.next_check then return end
  st.next_check = now + 0.25
  local entry, t = entry_of(st)
  if not entry then st.entry = nil; return 'gone' end
  st.entry = entry
  -- (the blocked byte kept: anything of the game's clearing it would let the pick-up be switched back on)
  if st.blocked then local b = switch_rec(st.w); if b and fetch(b + G.isw.block, 1) and b8(0) == 0 then write_u8(b + G.isw.block, 1) end end
  if t ~= 0 and write_u8(entry + ENTRY_TYPE, 0) then
    if not st.locked then rec('carry: your ' .. wname(st.wt) .. ' locked') end
    st.locked = true
  end
  if fetch(entry + ENTRY_ON, 1) and b8(0) ~= 0 then
    if write_u8(entry + ENTRY_ON, 0) then
      if not st.off then rec('carry: your ' .. wname(st.wt) .. '\'s pick-up off') end
      st.off = true
    elseif not st.off_failed then st.off_failed = true; rec('carry: could NOT turn its pick-up off') end
  end
  -- (No range limit: wherever you go, the weapon goes with you and comes back with the key.) Something of the
  -- game's took it off your back, or it couldn't be put there at the swap: put back, at most once a second, for as
  -- long as you carry (the first 5 times in the log). The key never depends on it: the game's equip takes the weapon
  -- wherever it is.
  if G.att and R.avunit and now >= (st.retry_at or 0) then
    st.retry_at = now + 1
    local why
    if not st.attached then why = 'it was not on your back'
    elseif st.verified then
      local to = attached_to(st.w)
      if to and to ~= R.avunit then why = string.format('attached to %x', to) end
    end
    if why then
      st.tries = st.tries + 1
      local r = put_on_back(st, ' again', st.tries > 5)
      if st.tries <= 5 then rec(string.format('carry: your %s is not on your back (%s): %s', wname(st.wt), why, r)) end
    end
  end
end

-- a weapon's own weapon-switch sound on it, the way the game's wield handler plays it
local function play_switch(wt, w, wu)
  local ev = WIELD_SOUND[wt]
  if not G.audio then rec('carry: no weapon-switch sound (not found in the game code)'); return end
  if not ev then rec('carry: the game has no weapon-switch sound for the ' .. wname(wt)); return end
  rec(string.format('carry: playing the %s\'s weapon-switch sound %08x', wname(wt), ev)); write_log_now()
  local we = entity(w)
  local oks, why, mix = pcall(game_sound, ev, we and we.unit or wu, R.av)
  rec('carry: weapon-switch sound: ' .. (oks and (why or ('played, ' .. tostring(mix))) or ('error ' .. tostring(why))))
end

-- an expendable picked up while your primary or secondary is out goes into your hands: you picked it up to use it
-- (otherwise it would sit on your back with your weapon, and the support key would draw it first). The game's own
-- weapon switch to the support slot, a
-- moment after the pickup so the pickup itself is done, with the expendable's own weapon-switch sound.
local function draw_expendable(st)
  if R.held == 3 or R.support ~= st.x then return end            -- (already in hand, or no longer the expendable)
  if R.held == 5 then rec('carry: a grenade or beacon in hand: the ' .. wname(st.xt) .. ' stays on your back'); return end
  local sr = state_addr(R.av)
  local wr = sr and sr + G.wield_at
  if not wr or read_u32(wr) ~= R.av then rec('carry: could not draw the ' .. wname(st.xt) .. ': no wield record of yours'); return end
  rec(string.format('carry: drawing the %s (in hand: slot %s)', wname(st.xt), tostring(R.held)))
  write_log_now()
  local ok, e = pcall(game_wield, wr)
  if not ok then rec('carry: the game\'s weapon switch failed: ' .. tostring(e)); return end
  play_switch(st.xt, st.x)
end

-- back to your support weapon: the game's own equip (it drops the expendable at your feet) and weapon switch
local function swap_back(st, why, now)
  C.stash = nil
  unstash(st, why)
  if st.remote then
    if not st.which then C.failed = C.failed + 1; event('joined game: could not ask for your ' .. wname(st.wt) .. ': its pick-up was not found'); return end
    rec(string.format('carry (joined): asking the host for your %s (entity %x, interaction %d, you %x) - %s', wname(st.wt), st.w, st.which, R.av, why))
    write_log_now()
    local ok, e = pcall(ask_host, st.w, st.which)
    if not ok then C.failed = C.failed + 1; event('joined game: the request failed: ' .. tostring(e)); return end
    C.pending = { w = st.w, wt = st.wt, at = now, why = why .. '; asked the host', wield = st.wield == true }
    return
  end
  local eqm = read_ptr(G.equipment)
  local sr = state_addr(R.av)
  local wr = sr and sr + G.wield_at
  if not eqm or not R.eq then C.failed = C.failed + 1; event('could not give your ' .. wname(st.wt) .. ' back: equipment unreadable'); return end
  if wr and read_u32(wr) ~= R.av then wr = nil end               -- (the wield record must be yours)
  if R.held == 5 then wr = nil end                                -- (a grenade or beacon in hand: the game doesn't wield either)
  if not st.wield then wr = nil end                               -- (used up: it goes back on its sling; you draw it yourself)
  -- (The weapon is equipped straight into your hands, and its own weapon-switch sound is played the way the game's
  -- wield handler plays it.)
  rec(string.format('carry: equipping your %s through the game (%s%s)', wname(st.wt), why, wr and ', then switching to it' or ''))
  write_log_now()
  local ok, e = pcall(game_equip, eqm, R.av, st.w, wr)
  if not ok then C.failed = C.failed + 1; event('the game\'s equip failed: ' .. tostring(e)); return end
  if wr then play_switch(st.wt, st.w, st.wu) end
  C.pending = { w = st.w, wt = st.wt, at = now, why = why, wield = wr ~= nil, wr = wr }
end

-- your support weapon key, the one you set in the game: Helldivers 2 keeps the bindings you changed in its input settings file in Steam Cloud
-- (<Steam>\userdata\<your Steam account>\553850\remote\input_settings.config; the Steam folder and the signed-in
-- account come from Steam's own registry values). Its 'ChangeEquipmentSupport' entry lists your keyboard and mouse
-- keys for it; without one (you never changed it), or with no keyboard or mouse key in it, it is the game's default, 3.
-- Read again every 15 s while nothing is carried, so a key changed in the game's options counts from then on. A
-- controller has no support weapon button: its weapon switch button is used instead (below).
local KEYS = { list = nil, text = nil, next_read = 0 }
local support_key_pressed, pad_switch, keys_step
do
  local HKCU = ffi.cast('void *', 0x80000001)
  local REG_BUF, REG_SIZE, REG_DW = ffi.new('char[520]'), ffi.new('uint32_t[1]'), ffi.new('uint32_t[1]')
  local FIND = ffi.new('EcFind[1]')
  local function reg_string(sub, name)
    if not ADV then return nil end
    REG_SIZE[0] = 520
    local ok, r = pcall(ADV.EcRegGetValueA, HKCU, sub, name, 0x2, nil, REG_BUF, REG_SIZE)   -- RRF_RT_REG_SZ
    if not ok or r ~= 0 or REG_SIZE[0] < 2 then return nil end
    return ffi.string(REG_BUF, REG_SIZE[0] - 1)
  end
  local function reg_dword(sub, name)
    if not ADV then return nil end
    REG_SIZE[0] = 4
    local ok, r = pcall(ADV.EcRegGetValueA, HKCU, sub, name, 0x10, nil, REG_DW, REG_SIZE)    -- RRF_RT_REG_DWORD
    if not ok or r ~= 0 then return nil end
    return tonumber(REG_DW[0])
  end
  local function file_time(path)                    -- a file's last write time (larger is newer), or nil when it isn't there
    local ok, h = pcall(K32.EcFindFirstFileA, path, FIND)
    if not ok or h == nil or tonumber(ffi.cast('intptr_t', h)) == -1 then return nil end
    K32.EcFindClose(h)
    return FIND[0].times[5] * 4294967296 + FIND[0].times[4]
  end
  local INPUT_FILE = '\\553850\\remote\\input_settings.config'
  local function input_file()
    local steam = reg_string('Software\\Valve\\Steam', 'SteamPath')
    if not steam then return nil, 'Steam\'s folder not found' end
    steam = steam:gsub('/', '\\'):gsub('\\+$', '')
    local user = reg_dword('Software\\Valve\\Steam\\ActiveProcess', 'ActiveUser')
    if user and user ~= 0 then
      local path = steam .. '\\userdata\\' .. user .. INPUT_FILE
      local t = file_time(path)
      if t then return path, nil, t end
    end
    -- (no signed-in account in the registry: the newest input settings file of the accounts on this computer)
    local best, best_t
    local ok, h = pcall(K32.EcFindFirstFileA, steam .. '\\userdata\\*', FIND)
    if ok and h ~= nil and tonumber(ffi.cast('intptr_t', h)) ~= -1 then
      local names = {}
      repeat
        local n = ffi.string(FIND[0].name)
        if n:match('^%d+$') then names[#names + 1] = n end
      until K32.EcFindNextFileA(h, FIND) == 0 or #names > 64
      K32.EcFindClose(h)
      for _, n in ipairs(names) do
        local path = steam .. '\\userdata\\' .. n .. INPUT_FILE
        local t = file_time(path)
        if t and (not best_t or t > best_t) then best, best_t = path, t end
      end
    end
    if best then return best, nil, best_t end
    return nil, 'no input settings file (no keys changed in the game)'
  end
  -- an action's bindings from the file's text: { { device type, input } ... } for the device types asked for, or nil
  -- when the file has no entry for the action (the game's default)
  local function bindings(text, action, devs)
    local a = text:find(action .. '%s*=%s*%[')
    if not a then return nil end
    local b = text:find('%]', a) or #text
    local list = {}
    for e in text:sub(a, b):gmatch('{(.-)}') do
      local dev, inp = e:match('device_type%s*=%s*"([^"]*)"'), e:match('input%s*=%s*"([^"]*)"')
      if dev and devs[dev] and inp and inp ~= '' then list[#list + 1] = { dev, inp } end
    end
    return list
  end
  -- a controller has no support weapon button: its weapon switch (the game's ChangeEquipmentContextSensitiveShort: Y / Triangle, a press; held, the
  -- weapon wheel) brings your weapon back instead. The engine's pads (Pad1..Pad4) name the buttons a, b, x, y,
  -- left_shoulder ...; the file names them XboxY, XboxLeftShoulder ...
  local function pad_names(inp)
    local n = inp:gsub('^Xbox', '')
    local snake = n:gsub('(%l)(%u)', '%1_%2'):lower()
    local dir = n:match('^DPad(%a+)$') or n:match('^Dpad(%a+)$')
    return { snake, dir and ('d_' .. dir:lower()) or nil, n:lower() }
  end
  local function key_index(dev, name, K, M)
    if dev == 'Keyboard' then
      local ok, i = pcall(K.button_index, name)
      return ok and type(i) == 'number' and i or nil
    end
    local base = name:gsub('^MouseButton', ''):lower()       -- (the file: MouseButtonMiddle; the engine: middle)
    local cands = { base }
    local num = base:match('(%d)$')
    if num then cands[#cands + 1] = 'extra_' .. num end
    for _, c in ipairs(cands) do
      local ok, i = pcall(M.button_index, c)
      if ok and type(i) == 'number' then return i end
    end
    return nil
  end
  local function read_keys(now, K, M)
    KEYS.next_read = now + 15
    local path, why, ftime = input_file()
    -- the same file, unchanged since the last read: nothing to do
    local stamp = tostring(path) .. '|' .. tostring(ftime)
    if KEYS.list and #KEYS.list > 0 and stamp == KEYS.stamp then return end
    KEYS.stamp = stamp
    local binds, pbinds, cbinds
    if path then
      local f = io.open(path, 'r')
      if f then
        local t = f:read('*a') or ''; f:close()
        binds = bindings(t, 'ChangeEquipmentSupport', { Keyboard = true, Mouse = true })
        pbinds = bindings(t, 'ChangeEquipmentContextSensitiveShort', { PadXBOX = true })
        cbinds = bindings(t, 'OpenChat', { Keyboard = true })
        -- (1.0.1) an entry with none of these devices (e.g. only a controller button set for it) is the default
        if binds and #binds == 0 then binds = nil end
        if pbinds and #pbinds == 0 then pbinds = nil end
        if cbinds and #cbinds == 0 then cbinds = nil end
      end
    end
    local list, names, src = {}, {}, nil
    if binds then
      src = 'your binding'
      for _, b in ipairs(binds) do
        local dev = b[1] == 'Keyboard' and K or M
        local i = dev and key_index(b[1], b[2], K, M)
        if i then list[#list + 1] = { dev, i }; names[#names + 1] = (b[1] == 'Mouse' and 'mouse ' or '') .. b[2]
        else names[#names + 1] = b[2] .. ' (not readable by the mod)' end
      end
    else
      src = 'the game\'s default' .. (why and ('; ' .. why) or '')
      local i = K and key_index('Keyboard', '3', K, M)
      if i then list[1] = { K, i }; names[1] = '3' end
    end
    -- the controllers' weapon switch button(s)
    local pads, pnames = {}, {}
    local SR = rawget(_G, 'stingray') or _G
    for _, b in ipairs(pbinds or { { 'PadXBOX', 'XboxY' } }) do
      local found
      for k = 1, 4 do
        local P = rawget(_G, 'Pad' .. k) or SR['Pad' .. k]
        if P then
          for _, c in pairs(pad_names(b[2])) do
            local ok, i = pcall(P.button_index, c)
            if ok and type(i) == 'number' then pads[#pads + 1] = { P, i }; found = true; break end
          end
        end
      end
      pnames[#pnames + 1] = b[2]:gsub('^Xbox', '') .. (found and '' or ' (not readable by the mod)')
    end
    KEYS.pads = pads
    -- chat: opened with the game's OpenChat key (enter by default), closed with enter or escape;
    -- your support weapon key typed in a message doesn't swap
    local chat = {}
    for _, b in ipairs(cbinds or { { 'Keyboard', 'enter' } }) do
      local i = K and key_index('Keyboard', b[2], K, M); if i then chat[#chat + 1] = i end
    end
    local close = {}
    for _, n in ipairs({ 'enter', 'escape', 'esc', 'numpad enter' }) do
      local i = K and key_index('Keyboard', n, K, M); if i then close[#close + 1] = i end
    end
    KEYS.chat_open_keys, KEYS.chat_close_keys = chat, close
    local text = (#names > 0 and table.concat(names, ', ') or 'none') .. ' (' .. src .. '); controller: '
      .. (#pnames > 0 and table.concat(pnames, ', ') or 'none') .. ' (weapon switch' .. (pbinds and ', your binding' or '') .. ')'
    if text ~= KEYS.text then
      if KEYS.text then event('your support weapon key is now ' .. text) else rec('support weapon key: ' .. text) end
      KEYS.text = text
    end
    KEYS.list = list
  end
  local function any(dev, list)
    for _, i in ipairs(list or {}) do
      local ok, p = pcall(dev.pressed, i)
      if ok and p and p ~= 0 then return true end
    end
    return false
  end
  -- every frame: the bindings read again now and then, and whether the chat is open (a few key checks)
  keys_step = function(now)
    local SR = rawget(_G, 'stingray') or _G
    local K, M = rawget(_G, 'Keyboard') or SR.Keyboard, rawget(_G, 'Mouse') or SR.Mouse
    if now >= KEYS.next_read and not C.stash then
      local ok, e = pcall(read_keys, now, K, M)
      if not ok then KEYS.next_read = now + 15; rec('support weapon key: could not be read (' .. tostring(e) .. ')') end
    end
    if not K then return end
    if KEYS.chat_until then
      if any(K, KEYS.chat_close_keys) or now > KEYS.chat_until then KEYS.chat_until = nil      -- (sent, closed, or 20 s idle)
      else
        local ok, a = pcall(K.any_pressed); if ok and a then KEYS.chat_until = now + 20 end   -- (still typing)
      end
    elseif any(K, KEYS.chat_open_keys) then KEYS.chat_until = now + 20 end
  end
  -- your support weapon key pressed this frame (not while typing in the chat)
  support_key_pressed = function()
    if KEYS.chat_until then return false end
    for _, k in ipairs(KEYS.list or {}) do
      local ok, p = pcall(k[1].pressed, k[2])
      if ok and p and p ~= 0 then return true end
    end
    return false
  end
  -- a controller's weapon switch: pressed this frame, held
  pad_switch = function()
    local pressed, held = false, false
    for _, k in ipairs(KEYS.pads or {}) do
      local ok, p = pcall(k[1].pressed, k[2]); if ok and p and p ~= 0 then pressed = true end
      local okb, b = pcall(k[1].button, k[2]); if okb and type(b) == 'number' and b > 0.5 then held = true end
    end
    return pressed, held
  end
end

local PAD_WHEEL = 0.15        -- seconds: the weapon switch held this long is the game's weapon wheel (it opens at 0.2 s): no swap back
local PAD_DELAY = 0.4         -- seconds after a weapon switch press before your weapon is brought back (the game's own
                              -- switch goes first; the same wait as drawing an expendable after a pickup)
carry_step = function(now)
  keys_step(now)
  local pressed3, pad_pressed, pad_held = false, false, false
  if C.stash then                                -- (the keys only matter while your weapon is carried)
    pressed3 = support_key_pressed()
    pad_pressed, pad_held = pad_switch()
  end
  if R.carry_swap then
    local sw = R.carry_swap; R.carry_swap = nil
    local ok, e = pcall(stash, sw, now)
    if not ok then rec('carry: error while taking it onto your back: ' .. tostring(e)) end
  end
  if C.pending and now - C.pending.at > 2 then
    local p = C.pending; C.pending = nil
    if R.support == p.w then
      if p.why:find('used up', 1, true) then C.auto = C.auto + 1 else C.back = C.back + 1 end
      event(string.format(p.wield and 'your %s is back in your hands (%s; in hand now: slot %s)' or 'your %s is back in your support slot (%s; in hand now: slot %s)',
        wname(p.wt), p.why, tostring(R.held)))
    else C.failed = C.failed + 1; event(string.format('your %s did not come back (support slot %s)', wname(p.wt), describe(R.support or 0))) end
  end
  local st = C.stash
  if not st then return end
  if not R.av then C.stash = nil; C.released = C.released + 1; unstash(st, 'your helldiver is gone'); return end
  if keep(st, now) == 'gone' then
    C.stash = nil; C.released = C.released + 1
    unstash(st, 'it is no longer on the ground: taken or gone')
    event(string.format('your %s is gone from where it was set down (taken or removed by the game); nothing to give back', wname(st.wt)))
    return
  end
  local sup = R.support
  if st.draw_at and now >= st.draw_at then st.draw_at = nil; draw_expendable(st) end
  if sup == st.x then
    if R.held == 3 then st.in_hand = st.in_hand or now else st.in_hand = nil end
    if pressed3 and st.in_hand and now - st.in_hand >= SWAP_HOLD then st.wield = true; swap_back(st, 'support key', now); return end
    -- (controller) the weapon switch pressed with the expendable in your hands: your weapon back once the game's own
    -- switch is under way; held into the weapon wheel: left to the wheel
    if pad_pressed and st.in_hand and now - st.in_hand >= SWAP_HOLD and not st.pad_at then st.pad_at = now end
    if st.pad_at then
      if pad_held and now - st.pad_at > PAD_WHEEL then st.pad_at = nil
      elseif now - st.pad_at >= PAD_DELAY then st.pad_at = nil; st.wield = true; swap_back(st, 'weapon switch on the controller', now) end
    end
  elseif sup == 0 or sup == 0xFFFFFFFF then
    swap_back(st, 'the ' .. wname(st.xt) .. ' was used up; it stays on its sling', now)
  else
    local e = entity(sup)
    if e and WEAPONS[e.type] and WEAPONS[e.type][2] then         -- another expendable (the pod's second EAT): keep carrying
      rec(string.format('carry: the %s replaced the %s; your %s is still carried', wname(e.type), wname(st.xt), wname(st.wt)))
      st.x, st.xt, st.in_hand = sup, e.type, nil
    elseif sup == st.w then C.stash = nil; unstash(st, 'the game gave it back by itself')
    else C.stash = nil; C.released = C.released + 1; unstash(st, 'you picked up ' .. (e and wname(e.type) or 'another weapon'))
      event(string.format('you picked up %s: your %s was set down', e and wname(e.type) or 'another weapon', wname(st.wt))) end
  end
end

-- a joined game is told apart by your interactor's request to the host (the pickup you asked for is
-- carried out by the host's game). Your interactor's request is found once a second; every frame reads one word of it.
local function find_request()
  local mgr = read_ptr(G.imgr); if not mgr then return nil end
  if not fetch(mgr, G.ihead) then return nil end
  local n, list, insts = b32(G.icount), bptr(G.ilist), bptr(G.iinsts)
  if not (list and insts) or n > 64 or n == 0 then return nil end
  if not fetch(list, n * 8) then return nil end
  local infos = {}
  for k = 0, n - 1 do infos[k] = bptr(k * 8) end
  for k = 0, n - 1 do
    if infos[k] and fetch(infos[k], 0x18) and b8(0x14) % 2 == 1 then return insts + k * G.istride + G.ireq end
  end
  return nil
end
local function request_step(now)
  if now >= (R.req_find_t or 0) then R.req_find_t = now + 1; R.req_at = find_request() end
  if R.req_at and fetch(R.req_at + 8, 4) and b32(0) ~= 0 then R.req_t = now end   -- a request waits for a host: a joined game
end

local function frame(now)
  equip_step(now)
  request_step(now)
  if VERBOSE then interactor_step(); input_step(now) end
  carry_step(now)
  if VERBOSE then
    watch_step(now)
    if R.lua_probe and now >= R.lua_probe then
      R.lua_probe = nil
      pcall(lua_probe, R.probe_why or 'after a swap', R.probe_keys or {})
    end
  end
end

-- ======================================================================================================
-- Log writing, start-up, the game hooks
-- ======================================================================================================
local function write_log()
  if #rec_lines > 0 and RECFILE then
    local f = io.open(RECFILE, 'a')
    if f then f:write(table.concat(rec_lines, '\n'), '\n'); f:close() end
    rec_lines = {}
  end
  if not LOGFILE then return end
  local f = io.open(LOGFILE, 'w'); if not f then return end
  f:write('Expendable Carry ', VERSION, '\n')
  f:write('started ', session.started, ', running for ', string.format('%.0f', os.clock() - T0), ' s\n')
  f:write(V19 and 'Bingus Shared Loader: v19 or newer\n' or 'Bingus Shared Loader: older than v19 - please update to v19 or newer\n')
  for _, n in ipairs(session.notes) do f:write(n, '\n') end
  if KEYS.text then f:write('support weapon key: ', KEYS.text, '\n') end
  f:write('status: ', tostring(EC.status), '\n')
  f:write(string.format('carried on your back: %d; swapped back with the key: %d; after the expendable was used up: %d; set down (other weapon, death): %d; joined games (asked the host): %d; failed: %d\n',
    C.swaps, C.back, C.auto, C.released, C.joined, C.failed))
  f:write(string.format('expendable pickups seen: %d; cost %.4f ms a frame on average (slowest %.2f ms); memory reads %d (failed %d)\n',
    stats.swaps, stats.frames > 0 and stats.ms / stats.frames or 0, stats.worst_ms, stats.reads, stats.read_fails))
  f:write('details: ExpendableCarry.research.log\nrecent events:\n')
  for _, e in ipairs(session.events) do f:write('  ', e, '\n') end
  f:close()
end

write_log_now = function() pcall(write_log) end
local started, broken, next_log, last_error = false, false, 0, nil
local function start()
  if started then return end
  started = true
  local ok, e = pcall(resolve)
  if not ok then broken = true; EC.status = 'off: could not find what it needs in the game code (' .. tostring(e) .. ')'; write_log(); return end
  EC.status = 'on (solo and hosting: on your back; joined games: the key asks the host for your weapon)'
  if VERBOSE then pcall(lua_probe, 'start', { [AVATAR_TYPE] = 'helldiver' }) end
  write_log()
end
if V19 then
  local ok, queued = pcall(LOADER.after_startup, function() start() end)
  if not (ok and queued) then note('mod loader', 'after_startup refused the start-up; it runs on the first frame') end
end
local function tick()
  if broken then return end
  if not started then start(); if broken then return end end
  local now = os.clock()
  local t = now
  local ok, e = pcall(frame, now)
  if not ok and e ~= last_error then last_error = e; rec('read error: ' .. tostring(e)) end
  local ms = (os.clock() - t) * 1000
  stats.frames, stats.ms = stats.frames + 1, stats.ms + ms
  if ms > stats.worst_ms and stats.frames > 60 then stats.worst_ms = ms end
  if now >= next_log then next_log = now + 1; write_log() end
end

local game_update, game_shutdown = rawget(_G, 'update'), rawget(_G, 'shutdown')
if type(game_update) ~= 'function' then EC.status = 'off: game update function not found'; write_log(); return end
rawset(_G, 'update', function(...)
  local ok, e = pcall(tick)
  if not ok then broken = true; EC.status = 'off: ' .. tostring(e); pcall(write_log) end
  return game_update(...)
end)
rawset(_G, 'shutdown', function(...)
  if not broken then EC.status = 'closed' end
  pcall(write_log)
  if type(game_shutdown) == 'function' then return game_shutdown(...) end
end)
write_log()
