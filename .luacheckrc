std = "lua51"
self = false
max_line_length = 140
exclude_files = { "tests/", "tools/", ".luarocks/", "lua_modules/" }

-- What Battleplan writes to the global environment: saved settings, slash
-- commands, and the probe's handle for the offline test.
globals = {
  "BattleplanDB", "BattleplanProbeDB", "BattleplanProbe", "SlashCmdList",
  "SLASH_BATTLEPLAN1", "SLASH_BATTLEPLAN2", "SLASH_BATTLEPLANPROBE1",
}

-- The WoW API Battleplan reads (Forever beta 1.60.1, Mainline-style).
read_globals = {
  "C_AddOns", "C_AddOnProfiler", "C_ClassTalents", "C_Item", "C_Spell", "C_SpellBook", "C_Timer",
  "C_TooltipInfo", "C_QuestLog", "C_Traits", "C_UnitAuras", "Enum", "WOW_PROJECT_ID",
  "CreateFrame", "UIParent", "UISpecialFrames", "GameTooltip", "ChatFontNormal",
  "GetAddOnMetadata", "GetBuildInfo", "GetLocale", "GetRealZoneText", "IsInInstance",
  "GetInventoryItemLink", "GetItemSpell", "GetItemCount", "GetWeaponEnchantInfo",
  "GetNumSpellTabs", "GetSpellTabInfo", "GetSpellBookItemName", "GetSpellBookItemInfo", "GetSpellInfo",
  "GetSpellPowerCost", "GetNumTalentTabs", "GetNumTalents", "GetTalentInfo",
  "UnitClass", "UnitFactionGroup", "UnitRace", "UnitLevel", "UnitFullName", "UnitName", "UnitExists", "UnitBuff",
  "GetCombatRating", "GetCombatRatingBonus",
  "InCombatLockdown", "IsModifiedClick", "ChatEdit_InsertLink", "issecretvalue", "geterrorhandler", "debugprofilestop", "date", "tinsert",
}
