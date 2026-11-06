-- Chat Filters 2.0.5 (AC:Unreal API 2 companion, client v146 or newer).
--
-- Three tabs:
--   Filters: checkboxes by category, based on UtilityBelt's ChatFilter. Ticked
--     boxes become the client's chat rules, which hide lines before they are
--     drawn (display only: plugins and the chat log still get them). Filters
--     match game lines only (no sender), so a player's chat is never hidden;
--     Spell words, NPC tells and Vendor tells match by message and sender type.
--     The ticked boxes of each message type are combined into a few pattern
--     rules, so every box fits. UtilityBelt's Debuffs, DebuffOnTarget and
--     OtherBuffs can't be told apart (chat doesn't say a spell's kind).
--   Alerts: text to watch for in players' chat (General, Tells, Allegiance,
--     Fellowship, Area chat and emotes) and in server messages (not NPCs,
--     vendors, Trade, LFG, Roleplay, Society or Olthoi), ignoring letter case.
--     Match: All words (each word of the entry anywhere in the line, in any
--     order, even inside a longer word; the default), Whole words (the entire
--     entry as written somewhere in the line, with no letter or digit right
--     before or after: "IG" matches "IG is up", not "big") or Exact line (the
--     entire entry is the entire line). A matching line also shows in the chat
--     window chosen in Settings ("Send alerts to"), even if that window doesn't
--     normally show that kind of message, in the Alert color (red by default);
--     the original line stays where it normally shows. The client does this
--     before the line is drawn. The plugin also plays a sound (sounds/alert.wav)
--     and adds the whole chat line to Alert list. An alert can
--     carry a quest flag: its status from your quest list is shown beside it
--     (green ready, red time left), and Chat shows the quest's hint in chat.
--     Each alert can be turned on or off; an alert whose quest is done and on
--     cooldown is paused until the quest can be done again. Starts with
--     Conquest's custom quests (Oracle of Dereth customquests.csv, consolation
--     flags left out), turned off.
--   Alert list: the last 20 alerts, newest first, with the quest flag.
--
-- The client allows 32 chat rules per plugin; filters and alerts share them
-- (shown as "Rules used"), and one is kept for hiding the Read quest list reply.
--
-- Quest list: /myquests replies are read (also the ones KT_Tracker sends and
-- hides) and saved to Profiles/chat_filters/Library/Quests/<server>_<character>.json.
-- "Read quest list" sends /myquests (the server answers one per minute); its
-- reply is hidden.
--
-- Lightweight: the client hands the plugin only quest-list rows and lines that
-- match an alert ("chat_subscriptions"), never other chat, and starts at the
-- newest line ("chat_history": false). Filtering, recoloring and moving lines
-- is done by the client. The window and the rules are sent only when they change.

local SIZE, SMALL = 15, 12      -- 20 px / 16 px, drawn sharp
local MAX_RULES = 32
local USER_RULES = 31           -- one rule is kept for the Read quest list reply
local PAT_MAX = 256             -- the client allows 256 characters per pattern
local TEXT_MAX = 100            -- alert text
local PAGE = 8                  -- alerts per page
local LIST_MAX = 20             -- Alert list entries
local NOTICE_PREFIX = "[Chat Filters]"
local SOUND = "alert.wav"

-- Filters --------------------------------------------------------------------
-- Message types (ACE ChatMessageType): Broadcast 0 (kill lines), Tell 3,
-- Magic 7, Spellcasting 17 (spell words), CombatEnemy 21 (attacks on you),
-- CombatSelf 22 (your attacks), Salvaging 25. Rules match server lines (no
-- sender) unless st says otherwise (st = false: any sender).
local DEATHS = {" apart!$", " in twain!$", "torn to ribbons", "killing blow nearly turns", " through!$", "fatally punctured",
  "perforated corpse", "sharp, stabbing pain", "lifeless pulp", " shattered by ", "force of .+ assault", "deafening silence",
  "fiery end!$", "to cinders", "incinerated by", "seared corpse", " cold!$", "icy death!$", "frozen fate", "liquified by",
  "strength dissolves", "oozing mass!$", "^Blistered by ", "^Electricity ", "coruscates over", "dessicated by", "strength withers",
  "twisted corpse!$", "obliterates? ", "smites? .+ mightily!$", "next Morningthaw!$", "utterly destroyed by",
  "with dire consequences!$", "death several times over!$", "ancestors feel it!$", "lifestone flinches!$", "^You killed ",
  " killed by ", " died!$"}
local CATS = {
  {id = "you", name = "Attacks on you", items = {
    {k = "spell_dmg_you", t = "Spell damage on you", r = {{chat_type = 7, contains = " you for "}}},
    {k = "melee_dmg_you", t = "Melee and missile damage on you", r = {{chat_type = 21, contains = " for "}}},
    {k = "you_evaded", t = "You evaded", r = {{chat_type = 21, prefix = "You evaded "}}},
    {k = "you_resist", t = "You resist a spell", r = {{prefix = "You resist the spell cast by "}}},
    {k = "fails_you", t = "Fails to affect you", r = {{contains = " fails to affect you"}}},
    {k = "periodic_dmg", t = "Periodic damage", r = {{prefix = "You receive ", contains = "damage."}, {prefix = "You receive ", contains = "periodic harm"}}}}},
  {id = "target", name = "Attacks on your target", items = {
    {k = "dmg_target", t = "Damage on your target", r = {{chat_type = 22, contains = " for "}}},
    {k = "resisted", t = "Your spell resisted", r = {{contains = " resists your spell"}}},
    {k = "evaded_you", t = "Your attack evaded", r = {{chat_type = 22, contains = " evaded your attack!"}}, tip = "Melee and missile"},
    {k = "deaths", t = "Death messages", r = {{chat_type = 0, p = DEATHS}}, tip = "Kill lines: yours, others' and your own death"}}},
  {id = "misc", name = "Misc", items = {
    {k = "all_casts", t = "All casts", r = {{chat_type = 7, contains = " cast"}}, tip = "Every \"cast\" line: yours and others', buffs and debuffs"},
    {k = "spell_words", t = "Spell words", r = {{chat_type = 17, st = false}}, tip = "Spoken spell words, such as Gvbz says, \"Malar Zhavik\". Also Aetheria surge lines."},
    {k = "comps", t = "Burned components", r = {{prefix = "The spell consumed the following components"}}},
    {k = "aetheria", t = "Aetheria surge", r = {{prefix = "Aetheria surges on "}}},
    {k = "cloak", t = "Cloak", r = {{prefix = "Your cloak "}, {prefix = "The cloak of "}}},
    {k = "dirty", t = "Dirty fighting", r = {{prefix = "Dirty Fighting! "}}},
    {k = "salvage", t = "Salvage", r = {{chat_type = 25, prefix = "You obtain "}}},
    {k = "expired", t = "Spell expired", r = {{contains = " has expired."}}}}},
  {id = "youcast", name = "You cast", items = {
    {k = "you_cast", t = "You cast", r = {{chat_type = 7, prefix = "You cast "}}},
    {k = "you_fail", t = "You fail to affect", r = {{prefix = "You fail to affect "}}},
    {k = "fizzle", t = "Spell fizzle", r = {{exact = "Your spell fizzled."}}},
    {k = "self_buffs", t = "Self buffs", r = {{prefix = "You cast ", contains = " on yourself"}}},
    {k = "heal_self", t = "Heal self", r = {{prefix = "You cast ", contains = " and restore "}}},
    {k = "you_dmg_spell", t = "Your damage spells", r = {{prefix = "You ", contains = " points with ", case_sensitive = true}, {prefix = "Critical hit! You ", contains = " points with "}}}}},
  {id = "others", name = "Others cast", items = {
    {k = "drain_you", t = "Drain spells on you", r = {{contains = " and drains "}}},
    {k = "regen", t = "Regen spells", r = {{contains = " and restores "}}},
    {k = "stam_regen", t = "Stamina regen spells", r = {{contains = " points of your Stamina"}}}}},
  {id = "recharge", name = "Recharge", items = {
    {k = "heal_kit", t = "Healing kits", r = {{prefix = "You ", contains = " heal ", case_sensitive = true}, {contains = " heals you for "}}},
    {k = "periodic_heal", t = "Periodic healing", r = {{prefix = "You receive ", contains = "periodic healing"}}},
    {k = "consumable", t = "Food and potions", r = {{prefix = "The ", contains = " points of your "}}}}},
  {id = "msg", name = "Messages", items = {
    {k = "npc_tells", t = "NPC tells", r = {{chat_type = 3, st = "npc"}}, tip = "Tells from NPCs near you"},
    {k = "vendor_tells", t = "Vendor tells", r = {{chat_type = 3, st = "vendor"}}, tip = "Tells from vendors near you"}}},
}
local ITEM = {}
for _, c in ipairs(CATS) do for _, it in ipairs(c.items) do ITEM[it.k] = it end end
local TIPS = {
  spell_dmg_you = "Hides spell damage on you, such as: Drudge Ravener blasts you for 50 points with Flame Bolt VII.",
  melee_dmg_you = "Hides melee and missile hits on you, such as: Drudge Ravener hits you for 30 points of damage!",
  you_evaded = "Hides attacks you evade, such as: You evaded Drudge Ravener!",
  you_resist = "Hides spells you resist, such as: You resist the spell cast by Drudge Ravener",
  fails_you = "Hides spells that fail on you, such as: Imperil fails to affect you!",
  periodic_dmg = "Hides damage over time on you, such as: You receive 40 points of periodic fire damage.",
  dmg_target = "Hides your melee and missile hits, such as: You hit Drudge Ravener for 50 points of damage!",
  resisted = "Hides spells your target resists, such as: Drudge Ravener resists your spell",
  evaded_you = "Hides your melee and missile misses, such as: Drudge Ravener evaded your attack!",
  deaths = "Hides kill lines (yours, other players' and your own death), such as: You obliterate Drudge Ravener!",
  all_casts = "Hides every spell-cast line, yours and other players', buffs and debuffs, such as: Gvbz cast Strength Other VIII on you.",
  spell_words = "Hides the spoken words of spells, such as: Gvbz says, \"Malar Zhavik\"",
  comps = "Hides the components used by a spell, such as: The spell consumed the following components: Lead Scarab",
  aetheria = "Hides aetheria surges, such as: Aetheria surges on Drudge Ravener with the power of Surge of Destruction!",
  cloak = "Hides cloak procs, such as: Your cloak reduced the damage!",
  dirty = "Hides dirty fighting lines, such as: Dirty Fighting! Gvbz delivers a Bleeding Assault!",
  salvage = "Hides salvaging results, such as: You obtain 10 Steel (ws 10.00) using your knowledge of Salvaging.",
  expired = "Hides spells running out, such as: Strength Self VIII has expired.",
  you_cast = "Hides your casts, such as: You cast Strength Other VIII on Gvbz",
  you_fail = "Hides your spells that fail, such as: You fail to affect Drudge Ravener!",
  fizzle = "Hides: Your spell fizzled.",
  self_buffs = "Hides buffs you cast on yourself, such as: You cast Strength Self VIII on yourself",
  heal_self = "Hides your heals on yourself, such as: You cast Heal Self VII and restore 80 points of your health.",
  you_dmg_spell = "Hides your damage spells, such as: You blast Drudge Ravener for 120 points with Flame Bolt VII.",
  drain_you = "Hides drain spells on you, such as: Gvbz casts Drain Health on you and drains 40 points of your health.",
  regen = "Hides restore spells cast on you, such as: Gvbz casts Heal Other and restores 80 points of your health.",
  stam_regen = "Hides stamina spells cast on you, such as: Gvbz casts Revitalize and gives you 50 points of your Stamina.",
  heal_kit = "Hides healing kit lines, such as: You heal yourself for 60 Health points.",
  periodic_heal = "Hides healing over time, such as: You receive 20 points of periodic healing.",
  consumable = "Hides food and potion lines, such as: The Mana Potion restores 80 points of your Mana.",
  npc_tells = "Hides tells from NPCs near you, such as: Ambassador Fehyin tells you, \"...\"",
  vendor_tells = "Hides tells from vendors, such as: Thomas the Squire tells you, \"Pleasure doing business!\""}
for k, tip in pairs(TIPS) do ITEM[k].tip = tip end

-- Conquest custom quests (Oracle of Dereth customquests.csv, by Advis).
local BASE = {
  {n = "Darshmaul the Brutal", f = "assaultonaimaru", h = "Shoushi - Portal to Fort 33.6S 74.9E - Kill Darshmaul the Brutal 34.3S 80.7E - Loot Finger - Shoushi - Give to Vovran 33.4S 72.8E"},
  {n = "Forgotten One", f = "ghostdencompleted", h = "Desolution Beach - Helsing 82.5N 43.5W - Den of Ghosts 82.4N 41.3W - Head North and hug left. Don't go downstairs - Defeat The Forgotten One and Loot Head - Back to Helsing"},
  {n = "Ice Giants Kill Task", f = "icegiantkilltask", h = "ENL 3+ Abandoned Mines - /tell Subway \"ice\" and take portal - Speak to Bjorn Sjostrom 95.0N 57.0W"},
  {n = "Tenebrous Subversion", f = "shadowqueensspike", h = "ENL 8+ 14 players max. Flag: Zhaikhal - Zahar 13.4N 0.5E - Tou-Tou 28.2S 96.0E - Kill Teneberous Shadows loot Tenebrous Synaptic Core Matrix - Give to Zahar. Repeat: Timaru - Astral Projection 51.2N 76.1W"},
  {n = "Thorsten's Tears", f = "cragstonetearspickup", h = "ENL 2+ 14 players max. Abandoned Mines - Bottom before big jump - Buy Cragstone Farms Portal Gem 20.1N 43.6E - Thomas the Squire 19.1N 46.3E - Cragstone - Alter to Cragstone 26.0N 48.4E - The Knight's Hold 34.6N 41.6E"},
  {n = "Uber Bellas", f = "bellasprimaryrewardclaimed", h = "ENL 2+ 6 players max. Hebian-To - Ambassador Fehyin 39.0S 83.0E - 1 player turn in Eaters jaw - Augmentation Realm - Lowest Level 39.0S 83.0E"},
  {n = "Uber Bobo", f = "uberpawlooted", h = "ENL 2+ 14 players max. Abandoned Mines - South passage - Legend of Tusker King - All Lefts - Throne of Tusker King - Talk to Jhango, The Second Prince - Take Uber Tusker Arena - Kill Bobo"},
  {n = "Uber Curator", f = "uberrtwreward", h = "ENL 2+ Rynthid Camp 61.6S 63.2W - 1 player kill 4 sanctum wardning crystals - Fargus 61.6S 63.2W"},
  {n = "Uber HMD", f = "uberhmdprimaryrewardclaimed", h = "ENL 4+ 6 players max. Hosh Tent 80.7N 43.0W - Kill 3 gatekeepers and combine key or do wall jump - Hosh Castle - Mysterious Hatch in first area"},
  {n = "Uber Metos 1", f = "ubermetossiralfricprimary", h = "ENL 5+ 9 players max. Dungeon: Graveyard - 61.3S 46.6W Rewards NPC: Graveyard - 64.4S 45.8W"},
  {n = "Uber Metos 2", f = "ubermetossrandprimary", h = "ENL 5+ 9 players max. Dungeon: Graveyard - 61.3S 46.6W Rewards NPC: Graveyard - 64.4S 45.8W"},
  {n = "Uber Slave Master", f = "uberslavemasterprimaryrewardclaimed", h = "ENL 4+ 6 players max. Neftet - Katsat 20.6S 7.9E - 1 player turn in Engraved A'nekshay Bracers - Temple Rear Entrance 20.6S 7.9E"},
  {n = "World Boss: Leafcull", f = "lceventcompleted", h = "Qalabar - Villalabar 74.9S 17.8E - Old Lugian Fortification 57.8S 18.0E. Reward: Khayyaban - Brigand Sands Cottage Portal 49.3S 26.0E - Highguard Wa Shi 63.7S 26.2E"},
  {n = "World Boss: Wintersebb", f = "weeventcompleted", h = "Crater Village - Mountain Retreat Cottages 66.1N 14.1E - Up mountain 56.5N 4.1W - Wintersebb 55.1N 3.5W. Reward: Mountain Retreat 59.8N 4.2W"},
}
local HINT = {}   -- flag -> hint
local BASE_BY_FLAG = {}
for _, b in ipairs(BASE) do HINT[b.f] = b.h; BASE_BY_FLAG[b.f] = string.lower(b.n) end

local WINDOWS = {"Main chat", "Window 1", "Window 2", "Window 3", "Window 4"}
-- Alert channels (client message types): General 27, Tells 3, Allegiance 18 and
-- patron/vassal/co-vassal chat 10, Fellowship 19, Area chat 2, and server lines
-- (no sender). Tells and Area chat also come from NPCs, so they are limited to
-- players ("unknown" is a player the client can't see, such as a tell from afar).
-- Trade, LFG, Roleplay and Society are left out.
-- Alerts check players' chat (any player, near or far) and server messages: one rule
-- per sender type. NPCs and vendors have their own sender types, so they are left out;
-- Trade, LFG, Roleplay, Society and Olthoi lines start with their tag and are left out
-- by the pattern (see HEAD).
local CHANNELS = {{sender_type = "player"}, {sender_type = "unknown"}, {sender_type = "server"}}
local ALERT_WHO = {player = true, unknown = true, server = true}
local SKIP_TAG = {}
for _, t in ipairs({"chat filters", "trade", "lfg", "roleplay", "society", "olthoi"}) do SKIP_TAG["[" .. t .. "]"] = true end
local function alert_channel(who, l)   -- l: the lower-case line
  if not ALERT_WHO[who or ""] then return false end
  if string.sub(l, 1, 1) ~= "[" then return true end
  for i = 3, 14 do
    if string.sub(l, i, i) == "]" then return not (SKIP_TAG[string.sub(l, 1, i)] and string.sub(l, i + 1, i + 1) == " ") end
  end
  return true
end
local WIN_N = {["Main chat"] = 0, ["Window 1"] = 1, ["Window 2"] = 2, ["Window 3"] = 3, ["Window 4"] = 4}
local MATCHES = {"All words", "Whole words", "Exact line"}
local MATCH_CODE = {["All words"] = "l", ["Whole words"] = "w", ["Exact line"] = "x"}
local MATCH_NAME = {l = "All words", w = "Whole words", x = "Exact line"}
local MATCH_TIP = {
  l = "All words: each word in the entry appears anywhere in the line",
  w = "Whole words: the entire entry must appear as written somewhere in the chat line",
  x = "Exact line: the entire entry must match the entire chat line"}
local COLORS = {"Red", "Orange", "Yellow", "Green", "Blue", "Purple", "White"}
local COLOR = {Red = "red", Orange = "#FF8800", Yellow = "yellow", Green = "green", Blue = "blue", Purple = "#CC4DFF", White = "white"}
local UI_COLOR = {Red = "#FF3B30", Orange = "#FF8800", Yellow = "#FFD60A", Green = "#34C759", Blue = "#3B9BFF", Purple = "#CC4DFF", White = "#FFFFFF"}

-- State ------------------------------------------------------------------------
local st                       -- {filters = {key = true}, alerts = {{t, m, f, w, off}}, opt = {...}} per character
local dirty = false
local changes = 0              -- bumped whenever saved data changes (window key)
local page = 1
local form = {t = "", m = "l", fq = "", edit = nil}
local hint_for = nil           -- alert index whose hint is shown in the window
local last_error, note = "", ""
local alert_log = {}           -- {at = unix, text = alert, f = flag, line = chat line}
local last_fire = {}           -- alert text -> unix time of the last alert
local last_sound = -1e9
local ui_key, rule_sig, sub_sig = nil, nil, nil
local rule_check, sub_check = nil, nil   -- when to look at the rules and subscriptions again
local reqs, req_serial = {}, 0
local myq_sent_at, myq_hide_until = -1e9, -1e9
local qpend, qhead = {}, 1     -- quest rows waiting to be read

-- Quest list (from /myquests replies in chat)
local QL = {}                  -- flag -> {s, t, m, d, desc}
local ql = {file = nil, loaded = false, last_line_at = nil, changed = false, ver = 0}
local MYQ = '^(\\S+) - (-?\\d+) solves \\((\\d*)\\)\\s*(?:"(.*)"\\s*(-?\\d+)\\s+(-?\\d+))?.*$'

local contains = string.contains
local function lower(s) return string.lower(s or "") end
local function trim(s)
  s = s or ""
  local a, b = 1, #s
  while a <= b and string.byte(s, a) <= 32 do a = a + 1 end
  while b >= a and string.byte(s, b) <= 32 do b = b - 1 end
  return string.sub(s, a, b)
end
local function opt(k) return st.opt[k] end
local function dur(sec)
  sec = math.max(0, math.floor(sec))
  local d, h, m = sec // 86400, (sec % 86400) // 3600, (sec % 3600) // 60
  if d > 0 then return d .. "d " .. h .. "h" end
  if h > 0 then return h .. "h " .. m .. "m" end
  return math.max(1, m) .. "m"
end
local function safe(s)
  local out = {}
  for i = 1, math.min(#(s or ""), 30) do
    local c = string.sub(s, i, i); local b = string.byte(c)
    if (b >= 65 and b <= 90) or (b >= 97 and b <= 122) or (b >= 48 and b <= 57) or c == "-" or c == "_" then out[#out + 1] = c
    elseif c == " " or c == "'" then out[#out + 1] = "_" end
  end
  return table.concat(out)
end
local function request(r) req_serial = req_serial + 1; r.id = r.id or ("r" .. req_serial); reqs[#reqs + 1] = r end
local function color_name() return COLOR[opt("color") or ""] and opt("color") or "Red" end
local function target_name() return WIN_N[opt("win") or ""] and opt("win") or "Main chat" end

-- Patterns -------------------------------------------------------------------------
local SPECIAL = {}
for _, c in ipairs({"\\", "^", "$", ".", "|", "?", "*", "+", "(", ")", "[", "]", "{", "}"}) do SPECIAL[c] = true end
local ESC = {}                 -- text -> escaped text (cache)
local function esc(t)
  local e = ESC[t]
  if e then return e end
  local out = {}
  for i = 1, #t do local c = string.sub(t, i, i); out[#out + 1] = SPECIAL[c] and ("\\" .. c) or c end
  e = table.concat(out); ESC[t] = e
  return e
end
-- Joins alternatives into patterns of at most PAT_MAX characters.
local function chunks(list, left, right, out)
  local cur, n = {}, #left + #right
  for _, f in ipairs(list) do
    if #cur > 0 and n + 1 + #f > PAT_MAX then out[#out + 1] = left .. table.concat(cur, "|") .. right; cur, n = {}, #left + #right end
    cur[#cur + 1] = f; n = n + #f + (#cur > 1 and 1 or 0)
  end
  if #cur > 0 then out[#out + 1] = left .. table.concat(cur, "|") .. right end
  return out
end
-- Alert patterns: all match kinds share patterns, each kind as one part:
--   ^(?!\[chat filters\] )(?:<whole words>|<exact line>|<all words>|...)
-- Whole words: no letter or digit right before or after.
local WORD_L, WORD_R = ".*?(?:^|\\W)(?:", ")(?:$|\\W)"
-- Exact line: the whole message. Channel lines ([General] Gvbz says, "...") and patron or
-- vassal lines (... says to you, "...") are matched on the part inside the quotes.
local EXACT_L, EXACT_R = "^(?:[^\"]*? says(?: to you)?, \")?\\s*(?:", ")\\s*\"?$"
local QUOTED = "^[^\"]*? says(?: to you)?, \"(.*)$"
-- The plugin's own lines (the Chat hint) are never recolored or moved.
local HEAD, TAIL = "^(?!\\[(?:chat filters|trade|lfg|roleplay|society|olthoi)\\] )(?:", ")"
local WRAP = {w = {WORD_L, WORD_R}, x = {EXACT_L, EXACT_R}, l = {"", ""}}
local ALT_MAX = PAT_MAX - #HEAD - #TAIL - #EXACT_L - #EXACT_R   -- the longest alternative that fits a pattern
-- All words: one look-ahead per word, so the words may come in any order.
local WORDS = {}                -- lower text -> its distinct words
local EDGE = {}                 -- punctuation dropped from the ends of a word ("boss:" -> "boss")
for _, c in ipairs({".", ",", ":", ";", "!", "?", "'", "\"", "(", ")", "[", "]"}) do EDGE[c] = true end
local function words_of(t)
  local w = WORDS[t]
  if w then return w end
  w = {}
  local seen, cur = {}, {}
  local function flush()
    if #cur > 0 then
      local a, b = 1, #cur
      while a <= b and EDGE[cur[a]] do a = a + 1 end
      while b >= a and EDGE[cur[b]] do b = b - 1 end
      local x = table.concat(cur, "", a, b)
      if x == "" then x = table.concat(cur) end
      if not seen[x] then seen[x] = true; w[#w + 1] = x end
      cur = {}
    end
  end
  for i = 1, #t do local c = string.sub(t, i, i); if c == " " or c == "\t" then flush() else cur[#cur + 1] = c end end
  flush()
  WORDS[t] = w
  return w
end
local function aheads(w, from)
  local p = {}
  for i = from, #w do p[#p + 1] = "(?=.*" .. esc(w[i]) .. ")" end
  return table.concat(p)
end
local function all_words_alt(t) return aheads(words_of(t), 1) end
-- All words alerts that start with the same word share it:
-- "(?=.*uber)(?:(?=.*bobo)|(?=.*hmd))".
local function all_words_parts(lists)
  local groups, order, out = {}, {}, {}
  for _, w in ipairs(lists) do
    local k = w[1]
    if not groups[k] then groups[k] = {}; order[#order + 1] = k end
    local g = groups[k]; g[#g + 1] = w
  end
  local room = PAT_MAX - #HEAD - #TAIL
  for _, k in ipairs(order) do
    local g = groups[k]
    if #g == 1 then out[#out + 1] = aheads(g[1], 1)
    else
      local head, rest, len = "(?=.*" .. esc(k) .. ")(?:", {}, 0
      for _, w in ipairs(g) do
        local r = aheads(w, 2)
        if #rest > 0 and #head + len + #r + 2 > room then out[#out + 1] = head .. table.concat(rest, "|") .. ")"; rest, len = {}, 0 end
        rest[#rest + 1] = r; len = len + #r + 1
      end
      out[#out + 1] = head .. table.concat(rest, "|") .. ")"
    end
  end
  return out
end
-- Whether an alert's text fits one pattern.
local function fits(text, m)
  local t = lower(text)
  if m == "l" then return #HEAD + #all_words_alt(t) + #TAIL <= PAT_MAX end
  return #esc(t) <= ALT_MAX
end
-- Alternatives that start with the same word share it: "uber (?:bellas|bobo)".
local function first_word(t)
  for i = 2, #t - 1 do if string.sub(t, i, i) == " " then return string.sub(t, 1, i) end end
end
local function shared(texts)
  local groups, order, out = {}, {}, {}
  for _, t in ipairs(texts) do
    local k = first_word(t) or t
    if not groups[k] then groups[k] = {}; order[#order + 1] = k end
    local g = groups[k]; g[#g + 1] = t
  end
  for _, k in ipairs(order) do
    local g = groups[k]
    if #g == 1 then out[#out + 1] = esc(g[1])
    else
      -- the longest start they all share, at least the first word
      local n = #k
      while true do
        local c = string.sub(g[1], n + 1, n + 1)
        if c == "" then break end
        local same = true
        for i = 2, #g do if string.sub(g[i], n + 1, n + 1) ~= c or #g[i] <= n + 1 then same = false break end end
        if not same or #g[1] <= n + 1 then break end
        n = n + 1
      end
      -- split so that each shared group stays within one pattern
      local head, rest, len = esc(string.sub(g[1], 1, n)), {}, 0
      for _, t in ipairs(g) do
        local r = esc(string.sub(t, n + 1))
        if #rest > 0 and #head + 4 + len + 1 + #r > ALT_MAX then
          out[#out + 1] = head .. "(?:" .. table.concat(rest, "|") .. ")"; rest, len = {}, 0
        end
        rest[#rest + 1] = r; len = len + #r + (#rest > 1 and 1 or 0)
      end
      out[#out + 1] = head .. "(?:" .. table.concat(rest, "|") .. ")"
    end
  end
  return out
end
-- Patterns for a set of alerts: whole words, exact lines and all words.
local function alert_patterns(list)
  local items, seen = {w = {}, x = {}, l = {}}, {}
  for _, al in ipairs(list) do
    local t = lower(al.t)
    local key = al.m .. t
    if not seen[key] and items[al.m] then
      seen[key] = true
      local k = items[al.m]
      k[#k + 1] = al.m == "l" and words_of(t) or t
    end
  end
  items.w, items.x, items.l = shared(items.w), shared(items.x), all_words_parts(items.l)
  -- Fill each pattern as far as it goes, Whole words first, then Exact line, then All words.
  local head, out = HEAD, {}
  local parts, cur, n, kind = {}, nil, 0, nil
  local function close()
    if cur then parts[#parts + 1] = WRAP[kind][1] .. table.concat(cur, "|") .. WRAP[kind][2]; cur = nil end
  end
  local function flush()
    close()
    if #parts > 0 then out[#out + 1] = head .. table.concat(parts, "|") .. TAIL end
    parts, n = {}, #head + #TAIL
  end
  flush()
  for _, k in ipairs({"w", "x", "l"}) do
    for _, it in ipairs(items[k]) do
      local add = #it + 1
      if not (cur and kind == k and k ~= "l") then add = add + #WRAP[k][1] + #WRAP[k][2] end
      if n + add > PAT_MAX then flush(); add = #it + 1 + #WRAP[k][1] + #WRAP[k][2] end
      if k == "l" then close(); parts[#parts + 1] = it
      elseif cur and kind == k then cur[#cur + 1] = it
      else close(); cur, kind = {it}, k end
      n = n + add
    end
    close()
  end
  flush()
  return out
end

-- Quest status: done and on cooldown pauses an alert ------------------------------------
local function quest_status(flag, unix)
  local q = flag and QL[flag] or nil
  if not q then return nil, nil end
  local left = (q.t or 0) + (q.d or 0) - (unix or 0)
  if (q.d or 0) > 0 and left > 0 then return dur(left), "red" end
  return "ready", "green"
end
local function usable(a) return a and not a.off and trim(a.t or "") ~= "" end
local function live(a, unix)
  if opt("alerts_off") or not usable(a) then return false end
  local _, c = quest_status(a.f, unix)
  return c ~= "red"
end

-- Rules ------------------------------------------------------------------------------------
-- Filter rules: the ticked boxes' tests, combined per message and sender type.
local function filter_rules(out)
  local groups, order = {}, {}
  for _, c in ipairs(CATS) do for _, it in ipairs(c.items) do
    if st.filters[it.k] then
      for _, r in ipairs(it.r) do
        local stype = r.st == nil and "server" or r.st
        local key = tostring(r.chat_type) .. "|" .. tostring(stype)
        local g = groups[key]
        if not g then g = {chat_type = r.chat_type, st = stype, f = {}}; groups[key] = g; order[#order + 1] = key end
        local f
        if r.p then for _, p in ipairs(r.p) do g.f[#g.f + 1] = p end
        elseif r.exact then f = "^" .. esc(r.exact) .. "$"
        elseif r.prefix and r.contains then f = "^(?=" .. esc(r.prefix) .. ").*" .. esc(r.contains)   -- the two may overlap
        elseif r.prefix then f = "^" .. esc(r.prefix)
        elseif r.contains then f = esc(r.contains)
        else g.all = true end
        if f then g.f[#g.f + 1] = r.case_sensitive and ("(?-i:" .. f .. ")") or f end
      end
    end
  end end
  for _, key in ipairs(order) do
    local g = groups[key]
    local base = {chat_type = g.chat_type, sender_type = g.st or nil}
    if g.all then
      out[#out + 1] = {id = "f" .. (#out + 1), chat_type = base.chat_type, sender_type = base.sender_type}
    else
      for _, p in ipairs(chunks(g.f, "", "", {})) do
        out[#out + 1] = {id = "f" .. (#out + 1), pattern = p, chat_type = base.chat_type, sender_type = base.sender_type}
      end
    end
  end
  return out
end
-- Alert rules: show the line (recolored) in the alert window, one rule per alert
-- channel. The original line stays where it normally shows.
local function alert_rules(out, list)
  if #list == 0 then return out end
  local col, w = COLOR[color_name()], WIN_N[target_name()]
  for _, p in ipairs(alert_patterns(list)) do
    for _, c in ipairs(CHANNELS) do
      local n = #out + 1
      out[n] = {id = "a" .. n, pattern = p, chat_type = c.chat_type, sender_type = c.sender_type, action = "show", window = w, color = col}
    end
  end
  return out
end
-- Rules for every ticked box and every alert turned on (paused ones too), so
-- that turning things back on always fits.
local function rules_used(alerts)
  local list = {}
  for _, a in ipairs(alerts or st.alerts) do if usable(a) then list[#list + 1] = a end end
  return #alert_rules(filter_rules({}), list)
end

-- Window -----------------------------------------------------------------------------
local function flag_matches(q)
  q = lower(trim(q))
  if q == "" then return {} end
  local hits, seen = {}, {}
  for k, v in pairs(QL) do
    if contains(k, q) or (v.desc and contains(lower(v.desc), q)) then hits[#hits + 1] = k; seen[k] = true end
  end
  for _, b in ipairs(BASE) do if not seen[b.f] and contains(b.f, q) then hits[#hits + 1] = b.f end end
  table.sort(hits)
  local out = {}
  for i = 1, math.min(5, #hits) do out[i] = hits[i] end
  return out, #hits
end

local function build(unix, used)
  local pin = true   -- hide_when_pinned
  local full = used > USER_RULES
  local used_text = "Rules used: " .. used .. " / " .. MAX_RULES
  local used_tip = "The client allows 32 chat rules per plugin. Filters and alerts share them, and one is kept for hiding the Read quest list reply."

  -- Filters tab
  local ftab = {
    {id = "opt|filters", type = "checkbox", size = SIZE, text = "Filters on", value = not opt("filters_off"), wrap = false,
      tooltip = "Off: no lines are hidden. Your ticked boxes are kept."},
    {id = "f_used", type = "text", size = SMALL, text = used_text, color = full and "red" or nil, wrap = false, tooltip = used_tip}}
  for _, c in ipairs(CATS) do
    local kids, on = {}, 0
    for _, it in ipairs(c.items) do
      local v = st.filters[it.k] == true
      if v then on = on + 1 end
      kids[#kids + 1] = {id = "flt|" .. it.k, type = "checkbox", size = SIZE, text = it.t, value = v, wrap = false, tooltip = it.tip}
    end
    ftab[#ftab + 1] = {id = "cat|" .. c.id, type = "section", size = SIZE, text = c.name .. (on > 0 and (" (" .. on .. ")") or ""),
      expanded = false, children = kids}
  end

  -- Alerts tab: on/off, the add/edit form (hidden while pinned), settings, then the alerts.
  local atab = {{id = "opt|alerts", type = "checkbox", size = SIZE, text = "Alerts on", value = not opt("alerts_off"), wrap = false,
    tooltip = "Off: no alert recolors or copies a line, plays a sound or is listed. Your alerts are kept."}}
  local fkids = {
    {id = "a_text", type = "input", size = SIZE, placeholder = "Text to watch for", value = form.t,
      tooltip = "The words or line to watch for in chat. Upper and lower case don't matter."},
    {id = "a_match", type = "select", size = SIZE, text = "Match", value = MATCH_NAME[form.m] or "All words", options = MATCHES,
      tooltip = MATCH_TIP.l .. "\n" .. MATCH_TIP.w .. "\n" .. MATCH_TIP.x},
    {id = "a_flag", type = "input", size = SIZE, placeholder = "Quest flag (optional)", value = form.fq, live = true,
      tooltip = "Optional. The alert pauses while this quest is done and on cooldown. Type part of a quest flag or quest name, then click a match."}}
  if form.fq ~= "" and form.fq ~= form.picked then
    local hits, total = flag_matches(form.fq)
    for i, k in ipairs(hits) do
      local q = QL[k]
      local label = k .. ((q and q.desc and q.desc ~= "") and ("  " .. q.desc) or "")
      fkids[#fkids + 1] = {id = "qf|" .. k, type = "button", size = SMALL, text = label, wrap = false, tooltip = "Use this quest flag: " .. label}
    end
    if total == 0 then
      fkids[#fkids + 1] = {id = "qf_none", type = "text", size = SMALL, wrap = false,
        text = next(QL) and "No matching quest flag (it is used as typed)" or "No quest list read yet (the flag is used as typed)"}
    elseif total > 5 then
      fkids[#fkids + 1] = {id = "qf_more", type = "text", size = SMALL, text = (total - 5) .. " more: type more of the flag", wrap = false}
    end
  end
  fkids[#fkids + 1] = {id = "a_btns", type = "row", children = {
    {id = "a_add", type = "button", size = SIZE, text = form.edit and "Save" or "Add", auto_width = true,
      tooltip = form.edit and "Save the changes to this alert" or "Add this alert to the list"},
    {id = "a_cancel", type = "button", size = SIZE, text = "Cancel", auto_width = true, enabled = form.edit ~= nil or form.t ~= "" or form.fq ~= "",
      tooltip = "Clear the form without saving"},
    {id = "a_myq", type = "button", size = SIZE, text = "Read quest list", auto_width = true, enabled = unix - myq_sent_at >= 60,
      tooltip = "Sends /myquests (the server answers one per minute). KT_Tracker's reads are used too."}}}
  atab[#atab + 1] = {id = "a_form", type = "column", hide_when_pinned = pin, children = fkids}
  if note ~= "" then atab[#atab + 1] = {id = "a_note", type = "text", size = SMALL, text = note, color = "yellow", wrap = false, tooltip = note} end
  if last_error ~= "" then atab[#atab + 1] = {id = "a_err", type = "text", size = SMALL, text = last_error, color = "red", wrap = false, tooltip = last_error} end
  local h = hint_for and st.alerts[hint_for]
  if h and h.f and HINT[h.f] then
    atab[#atab + 1] = {id = "a_hint", type = "text", size = SMALL, text = h.t .. ": " .. HINT[h.f], wrap = true}
  end
  atab[#atab + 1] = {id = "a_set", type = "section", size = SIZE, text = "Settings", expanded = false, hide_when_pinned = pin, children = {
    {id = "a_target", type = "select", size = SIZE, text = "Send alerts to", value = target_name(), options = WINDOWS,
      tooltip = "Matching lines also show in this window, even if it doesn't normally show that kind of message"},
    {id = "a_color", type = "select", size = SIZE, text = "Alert color", value = color_name(), options = COLORS,
      tooltip = "The color of matching lines in the alert window"},
    {id = "opt|sound", type = "checkbox", size = SIZE, text = "Play a sound", value = not opt("sound_off"), wrap = false,
      tooltip = "Plays the alert sound when a line matches, at most once per alert every 5 seconds"},
    {id = "a_vol", type = "slider", size = SIZE, text = "Volume", min = 10, max = 100, step = 10, value = tonumber(opt("vol")) or 100,
      tooltip = "Volume of the alert sound"},
    {id = "a_used", type = "text", size = SMALL, text = used_text, color = full and "red" or nil, wrap = false, tooltip = used_tip}}}

  local pages = math.max(1, math.ceil(#st.alerts / PAGE))
  if page > pages then page = pages end
  for i = (page - 1) * PAGE + 1, math.min(#st.alerts, page * PAGE) do
    local a = st.alerts[i]
    local status, color = quest_status(a.f, unix)
    local label = a.t
    local shown = status and not a.off
    -- The same controls in every row, so the columns line up. Only the text column
    -- stretches (the client shares a row's width between controls without auto_width).
    atab[#atab + 1] = {id = "al|" .. i, type = "row", children = {
      {id = "al_o|" .. i, type = "checkbox", size = SIZE, value = not a.off, auto_width = true, tooltip = "Turn this alert on or off"},
      {id = "al_t|" .. i, type = "text", size = SIZE, text = label, wrap = false, tooltip = a.t .. " - " .. (MATCH_TIP[a.m] or MATCH_TIP.l)},
      {id = "al_s|" .. i, type = "text", size = SIZE, text = shown and status or "", color = color, wrap = false, auto_width = true,
        tooltip = shown and (color == "red" and "Quest done: paused until it can be done again" or "Quest can be done: alert active") or nil},
      {id = "al_c|" .. i, type = "button", size = SIZE, text = "C", auto_width = true, enabled = a.f ~= nil and HINT[a.f] ~= nil,
        tooltip = "Chat"},
      {id = "al_e|" .. i, type = "button", size = SIZE, text = "E", auto_width = true, hide_when_pinned = pin, tooltip = "Edit"},
      {id = "al_r|" .. i, type = "button", size = SIZE, text = "X", auto_width = true, hide_when_pinned = pin, tooltip = "Remove"}}}
  end
  if #st.alerts == 0 then atab[#atab + 1] = {id = "al_none", type = "text", size = SMALL, text = "No alerts. Add text above."} end
  if pages > 1 then
    atab[#atab + 1] = {id = "pg", type = "row", children = {
      {id = "pg_prev", type = "button", size = SIZE, text = "<", auto_width = true, enabled = page > 1},
      {id = "pg_n", type = "text", size = SIZE, text = page .. " / " .. pages, wrap = false},
      {id = "pg_next", type = "button", size = SIZE, text = ">", auto_width = true, enabled = page < pages}}}
  end

  -- Alert list tab: newest first, small, in the alert color.
  local ltab, col = {}, UI_COLOR[color_name()]
  for i, e in ipairs(alert_log) do
    local age = unix - e.at
    local line = (age < 60 and "now" or dur(age)) .. "  " .. e.text .. (e.f and (" (" .. e.f .. ")") or "") .. ": " .. e.line
    ltab[#ltab + 1] = {id = "lg|" .. i, type = "text", size = SMALL, text = line, color = col, wrap = false, tooltip = line}
  end
  if #alert_log == 0 then ltab[1] = {id = "lg_none", type = "text", size = SMALL, text = "No alerts yet"}
  else ltab[#ltab + 1] = {id = "lg_clear", type = "button", size = SMALL, text = "Clear", auto_width = true, hide_when_pinned = pin, tooltip = "Clear the alert list"} end

  return {{id = "tabs", type = "tabs", children = {
    {id = "Filters", type = "column", text = "Filters", children = ftab},
    {id = "Alerts", type = "column", text = "Alerts", children = atab},
    {id = "Alert list", type = "column", text = "Alert list" .. (#alert_log > 0 and (" (" .. #alert_log .. ")") or ""), children = ltab}}}}
end

-- Events ---------------------------------------------------------------------------------
local FULL = "Not enough chat rules left (32 per plugin)"
local function form_reset() form = {t = "", m = "l", fq = "", edit = nil} end
local function handle(e, unix)
  local id = type(e.id) == "string" and e.id or ""
  if e.type == "change" then
    if string.sub(id, 1, 4) == "flt|" then
      local k = string.sub(id, 5)
      if ITEM[k] then
        local was = st.filters[k]
        st.filters[k] = e.value == true or nil
        if st.filters[k] and rules_used() > USER_RULES then st.filters[k] = was; note = FULL end
        dirty = true
      end
    elseif id == "opt|filters" then st.opt.filters_off = e.value ~= true or nil; dirty = true
    elseif id == "opt|alerts" then st.opt.alerts_off = e.value ~= true or nil; dirty = true
    elseif id == "opt|sound" then st.opt.sound_off = e.value ~= true or nil; dirty = true
    elseif id == "a_color" then st.opt.color = COLOR[tostring(e.value or "")] and tostring(e.value) or nil; dirty = true
    elseif id == "a_target" then st.opt.win = WIN_N[tostring(e.value or "")] and tostring(e.value) or nil; dirty = true
    elseif id == "a_vol" then st.opt.vol = math.max(10, math.min(100, math.floor((tonumber(e.value) or 100) + 0.5))); dirty = true
    elseif string.sub(id, 1, 5) == "al_o|" then
      local a = st.alerts[tonumber(string.sub(id, 6)) or 0]
      if a then
        local was = a.off
        a.off = e.value ~= true or nil
        if not a.off and rules_used() > USER_RULES then a.off = was; note = FULL end
        dirty = true
      end
    elseif id == "a_text" then form.t = string.sub(tostring(e.value or ""), 1, TEXT_MAX)
    elseif id == "a_match" then form.m = MATCH_CODE[tostring(e.value or "")] or "l"
    elseif id == "a_flag" then form.fq = string.sub(tostring(e.value or ""), 1, 64)
    end
  elseif e.type == "click" then
    if string.sub(id, 1, 3) == "qf|" then
      local k = string.sub(id, 4)
      form.fq, form.picked = k, k
      -- No text yet: start from the quest's description.
      if trim(form.t) == "" then
        local q = QL[k]
        form.t = string.sub((q and q.desc and q.desc ~= "") and q.desc or k, 1, TEXT_MAX)
      end
    elseif id == "a_add" then
      local text = trim(form.t)
      if text == "" then note = "Enter the text to watch for"; return end
      if not fits(text, MATCH_NAME[form.m] and form.m or "l") then note = "Text is too long"; return end
      local flag = lower(trim(form.fq))
      local a = {t = text, m = MATCH_NAME[form.m] and form.m or "l", f = flag ~= "" and flag or nil}
      local old = form.edit and st.alerts[form.edit]
      if old and old.off then a.off = true end
      local trial = {}
      for i, x in ipairs(st.alerts) do trial[i] = x end
      if old then trial[form.edit] = a else trial[#trial + 1] = a end
      if not a.off and rules_used(trial) > USER_RULES then note = FULL; return end
      st.alerts = trial; last_fire = {}
      if old then note = "Saved " .. text else page = math.ceil(#st.alerts / PAGE); note = "Added " .. text end
      dirty = true; form_reset()
    elseif id == "a_cancel" then form_reset(); note = ""
    elseif id == "a_myq" then
      if unix - myq_sent_at >= 60 then
        myq_sent_at, myq_hide_until = unix, unix + 60
        request({service = "chat", operation = "send", text = "@myquests"}); note = "Reading your quest list..."
      end
    elseif id == "pg_prev" then page = math.max(1, page - 1)
    elseif id == "pg_next" then page = page + 1
    elseif id == "lg_clear" then alert_log = {}
    elseif string.sub(id, 1, 3) == "al_" and string.sub(id, 5, 5) == "|" then
      local kind, n = string.sub(id, 4, 4), tonumber(string.sub(id, 6))
      local a = n and st.alerts[n]
      if a then
        if kind == "r" then
          table.remove(st.alerts, n); hint_for = nil; dirty = true; note = "Removed " .. a.t
          if form.edit == n then form_reset() elseif form.edit and form.edit > n then form.edit = form.edit - 1 end
        elseif kind == "e" then
          form = {t = a.t, m = a.m, fq = a.f or "", picked = a.f, edit = n}; note = "Editing " .. a.t
        elseif kind == "c" then
          local hint = a.f and HINT[a.f]
          if hint then
            if hint_for == n then hint_for = nil
            else hint_for = n; request({service = "notice", operation = "show", text = string.sub(a.t .. ": " .. hint, 1, 480)}) end
          end
        end
      end
    end
  end
end

-- Chat ---------------------------------------------------------------------------------------
local function quest_line(text, unix)
  local m = regexmatch(text, MYQ)
  if not (m and m["1"]) then return end
  local d = m["4"]
  QL[lower(m["1"])] = {s = tonumber(m["2"]) or 0, t = tonumber(m["3"]) or 0, m = tonumber(m["5"]), d = tonumber(m["6"]),
    desc = (d and d ~= "") and string.sub(d, 1, 120) or nil}
  ql.last_line_at, ql.changed, ql.ver = unix, true, ql.ver + 1
end
-- The alerts a line matches (the client only delivers lines that match one).
local WORD = {}                -- lower text -> whole-word pattern
local function whole(l, t)
  if not contains(l, t) then return false end
  local p = WORD[t]
  if not p then p = "(?:^|\\W)" .. esc(t) .. "(?:$|\\W)"; WORD[t] = p end
  return regexmatch(l, p) ~= nil
end
local function unquote(s) s = trim(s) if string.sub(s, -1) == "\"" then s = trim(string.sub(s, 1, -2)) end return s end
local LT = {}                    -- alert text -> lower-case, trimmed
local function lt_of(t) local x = LT[t] if not x then x = lower(trim(t)); LT[t] = x end return x end
-- line: {l = lower-case line, msg = the line or the message inside a channel line's quotes}
local function message_of(line)
  if line.msg == nil then
    line.msg = unquote(line.l)
    if contains(line.l, " says") then
      local q = regexmatch(line.l, QUOTED)
      if q and q["1"] then line.msg2 = unquote(q["1"]) end
    end
  end
  return line.msg, line.msg2
end
local function matches(a, line)
  local t, l = lt_of(a.t), line.l
  if a.m == "x" then local m1, m2 = message_of(line); return m1 == t or m2 == t end
  if a.m == "w" then return whole(l, t) end
  for _, x in ipairs(words_of(t)) do if not contains(l, x) then return false end end
  return true
end
local function check_alerts(raw, who, unix, shown)
  local line = {l = lower(raw)}
  if not alert_channel(who, line.l) then return end
  for _, a in ipairs(st.alerts) do
    if live(a, unix) and matches(a, line) and unix - (last_fire[a.t] or -1e9) >= 5 then
      last_fire[a.t] = unix
      table.insert(alert_log, 1, {at = unix, text = a.t, f = a.f, line = string.sub(shown ~= "" and shown or raw, 1, 300)})
      if #alert_log > LIST_MAX then table.remove(alert_log) end
      if not opt("sound_off") and unix - last_sound >= 1 then
        last_sound = unix
        table.insert(reqs, 1, {id = "snd" .. req_serial, service = "sound", operation = "play", asset = SOUND, volume = (tonumber(opt("vol")) or 100) / 100})
        req_serial = req_serial + 1
      end
    end
  end
end

-- Callback --------------------------------------------------------------------------------------
return function(s, p)
  local out = {}
  local now = tonumber(s.time) or 0
  local unix = tonumber(s.unix_time) or now

  if not st then
    local saved = type(s.state) == "table" and s.state or {}
    st = {filters = {}, alerts = {}, opt = {}}
    local o = type(saved.opt) == "table" and saved.opt or {}
    for _, k in ipairs({"filters_off", "alerts_off", "sound_off"}) do if o[k] == true then st.opt[k] = true end end
    if COLOR[o.color or ""] then st.opt.color = o.color end
    if WIN_N[o.win or ""] then st.opt.win = o.win end
    if tonumber(o.vol) then st.opt.vol = math.max(10, math.min(100, math.floor(tonumber(o.vol)))) end
    for k, v in pairs(type(saved.filters) == "table" and saved.filters or {}) do if ITEM[k] and v == true then st.filters[k] = true end end
    if type(saved.alerts) == "table" then
      for _, a in ipairs(saved.alerts) do
        if type(a) == "table" and type(a.t) == "string" and trim(a.t) ~= "" then
          -- Before 2.0.1 (v 2) an alert without a match type was Whole words and Any part
          -- existed (now Whole words); 1.0.0/1.0.1 had x = true for exact.
          local m
          if (tonumber(saved.v) or 0) >= 2 then m = MATCH_NAME[a.m or ""] and a.m or "l"
          else m = (a.x == true or a.m == "x") and "x" or "w" end
          local f = type(a.f) == "string" and trim(lower(a.f)) or ""
          -- 2.0.2: the starting quest alerts use All words.
          if (tonumber(saved.v) or 0) < 3 and m == "w" and BASE_BY_FLAG[f] == lower(trim(a.t)) then m = "l" end
          st.alerts[#st.alerts + 1] = {t = string.sub(trim(a.t), 1, TEXT_MAX), m = m, f = f ~= "" and f or nil, off = a.off == true or nil}
          -- 1.0.x "Show only in" a window: that window becomes the alert window.
          if WIN_N[a.w or ""] and not st.opt.win and not a.off then st.opt.win = a.w end
        end
      end
      if (saved.opt and saved.opt.aw) or saved.v ~= 3 then dirty = true end
    else
      -- The starting quest alerts: All words, off until you turn them on.
      for _, b in ipairs(BASE) do st.alerts[#st.alerts + 1] = {t = b.n, f = b.f, m = "l", off = true} end
      dirty = true
    end
  end

  -- Quest list file for this character and server.
  local name = type(s.character_name) == "string" and s.character_name or ""
  if not ql.file and name ~= "" and type(s.server) == "string" and s.server ~= "" then
    ql.file = safe(s.server) .. "_" .. safe(name)
    request({id = "ql_read", service = "profiles", operation = "read", group = "Quests", name = ql.file})
  end

  for _, e in ipairs(s.events or {}) do
    if e.type == "result" then
      if e.id == "ql_read" then
        ql.loaded = true
        local d = e.ok and type(e.data) == "table" and e.data or nil
        if d and type(d.q) == "table" then
          for k, q in pairs(d.q) do if type(q) == "table" and not QL[k] then QL[k] = q end end
          ql.ver = ql.ver + 1
        end
      elseif e.ok == false then
        local err = type(e.error) == "string" and e.error or "failed"
        if not contains(err, "rate limit") then
          last_error = (string.sub(tostring(e.id), 1, 3) == "snd" and "Sound not played: " or "Not done: ") .. string.sub(err, 1, 120)
        end
      end
    else
      handle(e, unix)
    end
  end

  -- Chat: only quest-list rows and lines that match an alert arrive.
  for _, e in ipairs(s.chat_events or {}) do
    local raw = type(e.raw_text) == "string" and e.raw_text or nil
    if raw and #raw <= 4096 then
      if (e.sender_type == "server" or (e.sender or "") == "") and contains(raw, " solves (") then qpend[#qpend + 1] = raw
      elseif string.sub(raw, 1, #NOTICE_PREFIX) ~= NOTICE_PREFIX and string.sub(e.text or "", 1, #NOTICE_PREFIX) ~= NOTICE_PREFIX then
        check_alerts(raw, e.sender_type, unix, type(e.text) == "string" and e.text or "")
      end
    end
  end
  -- Quest rows within the client's work limit; the rest wait for the next update.
  while qhead <= #qpend and workavailable() do quest_line(qpend[qhead], unix); qpend[qhead] = nil; qhead = qhead + 1 end
  if qhead > #qpend then qpend, qhead = {}, 1 end

  -- Save the quest list once a read has finished (no new row for 5 s).
  if ql.changed and ql.file and ql.loaded and ql.last_line_at and unix - ql.last_line_at >= 5 then
    ql.changed = false
    local n = 0; for _ in pairs(QL) do n = n + 1 end
    request({service = "profiles", operation = "save", group = "Quests", name = ql.file,
      data = {chat_filters_quests = true, server = s.server, character = name, saved = math.floor(unix), count = n, q = QL}})
    if note == "Reading your quest list..." then note = "Quest list read: " .. n .. " flags" end
  end

  if dirty then changes = changes + 1; dirty = false; out.state = {v = 3, filters = st.filters, alerts = st.alerts, opt = st.opt} end

  -- Subscriptions: quest rows and every alert (on, off or paused), so they only
  -- change when the list is edited.
  if sub_check ~= changes then
  sub_check = changes
  local sp = {}
  for _, a in ipairs(st.alerts) do if trim(a.t) ~= "" then sp[#sp + 1] = a.m .. lower(a.t) end end
  local ss = table.concat(sp, "\n")
  if ss ~= sub_sig then
    local subs = {{id = "q", contains = " solves (", sender_type = "server"}}
    local list = {}
    for _, a in ipairs(st.alerts) do if trim(a.t) ~= "" then list[#list + 1] = a end end
    for _, pat in ipairs(alert_patterns(list)) do if #subs < 32 then subs[#subs + 1] = {id = "s" .. #subs, pattern = pat} end end
    out.chat_subscriptions = subs; sub_sig = ss
  end
  end

  -- Rules: only when they change (a /myquests send installs its rule in the same
  -- output). Looked at again on edits, quest-list reads, every 30 s (cooldowns)
  -- and when the /myquests hiding starts or ends.
  local myq = unix < myq_hide_until
  local rc = changes .. "#" .. ql.ver .. "#" .. math.floor(unix / 30) .. "#" .. tostring(myq)
  if rc ~= rule_check then
  rule_check = rc
  local live_list, sig = {}, {}
  if not opt("filters_off") then for _, c in ipairs(CATS) do for _, it in ipairs(c.items) do if st.filters[it.k] then sig[#sig + 1] = it.k end end end end
  sig[#sig + 1] = "#" .. color_name() .. "#" .. target_name()
  for _, a in ipairs(st.alerts) do
    if live(a, unix) then live_list[#live_list + 1] = a; sig[#sig + 1] = a.m .. "|" .. a.t end
  end
  sig[#sig + 1] = tostring(myq)
  local rs = table.concat(sig, "\n")
  if rs ~= rule_sig then
    local saved_filters = st.filters
    if opt("filters_off") then st.filters = {} end
    local rules = alert_rules(filter_rules({}), live_list)
    st.filters = saved_filters
    while #rules > USER_RULES do table.remove(rules) end
    if myq then rules[#rules + 1] = {id = "myq", contains = " solves (", sender_type = "server", seconds = math.max(1, math.ceil(myq_hide_until - unix))} end
    out.chat_filters = rules; rule_sig = rs
  end
  end

  -- Requests: at most 4 per callback.
  if #reqs > 0 then
    local batch = {}
    while #reqs > 0 and #batch < 4 do batch[#batch + 1] = table.remove(reqs, 1) end
    out.requests = batch
  end

  -- Window: only when it changes.
  local err = type(s.error) == "string" and s.error or ""
  if err ~= "" then last_error = string.sub(err, 1, 160) end
  local key = table.concat({page, form.t, form.m, form.fq, tostring(form.picked), tostring(form.edit), note, last_error, tostring(hint_for),
    #alert_log, alert_log[1] and alert_log[1].at or 0, math.floor(unix / 60), tostring(unix - myq_sent_at >= 60), ql.ver, changes}, "#")
  if key ~= ui_key then
    if not ui_key then out.status = "" end
    out.ui = build(unix, rules_used()); ui_key = key
  end

  return out
end
