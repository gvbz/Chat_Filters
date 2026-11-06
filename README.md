# Chat Filters

A plugin for the AC:Unreal client. It hides chat lines by category and alerts you when chat contains text you choose.

## Requirements

- AC:Unreal client v146 or newer.

## Install

1. Unzip into `ACUnreal\Saved\ClientPlugins\Installed`. The path ends in `Installed\Chat_Filters\plugin.json`.
2. Open the plugin menu, press **Refresh**, then **Enable** Chat Filters.

## Update

Replace the files in `Installed\Chat_Filters` and press **Refresh**. Your filters, alerts and settings are kept.

## Filters

Checkboxes by category, based on UtilityBelt's ChatFilter: Attacks on you, Attacks on your target, Misc, You cast, Others cast, Recharge and Messages.

- A ticked box hides those lines in every chat window. The chat log and other plugins still get them.
- Only game lines are hidden, never a player's chat.
- **Filters on** turns all filters off or on. Your ticked boxes are kept.
- Not available: Debuffs, Debuff on target and Others' buffs. Chat lines don't say whether a spell is a buff or a debuff.

## Alerts

Alerts check players' chat (General, Tells, Allegiance, Fellowship, Area chat and emotes) and server messages. Trade, LFG, Roleplay, Society, Olthoi, NPCs and vendors are not checked. Letter case doesn't matter.

**Match**:

- **All words** (default): each word in the entry appears anywhere in the line, in any order. "darsh down" matches "darsh is down" and "darshmaul is down". Avoid short words like IG or single numbers.
- **Whole words**: the entire entry must appear as written somewhere in the chat line. "IG" matches "IG is up" but not "big".
- **Exact line**: the entire entry must match the entire chat line.

A matching line:

- also shows in the window chosen in **Settings > Send alerts to**, in the **Alert color** (red by default);
- stays where it normally shows;
- plays a sound, at most once per alert every 5 seconds;
- is added to the **Alert list** tab (the last 20).

**Quest flag** (optional): type part of a flag or quest name and click a match. The alert shows the quest's status (green ready, red time left) and is paused while the quest is on cooldown.

Each alert has three buttons:

- **C**: show the quest's hint in chat.
- **E**: edit the alert.
- **X**: remove the alert.

The plugin starts with Conquest's custom quests as alerts, turned off. Tick the ones you want.

While the window is pinned, the add form, Settings, E, X and Clear are hidden.

## Quest list

The plugin reads `/myquests` replies, including the ones KT_Tracker sends. **Read quest list** sends `/myquests` and hides the reply. The server answers once per minute.

## Chat rules

The client allows 32 chat rules per plugin. Filters and alerts share them (**Rules used**). A change that doesn't fit is refused with a note.

## Permissions

| Permission | Used for |
|---|---|
| chat | quest-list lines and lines that match an alert |
| chat_filter | hiding and recoloring lines |
| say | sending `/myquests` |
| ui | the window and quest hints |
| state | saving filters, alerts and settings |
| profiles | saving your quest list |
| sound | the alert sound |

## Credits

- Conquest custom quests from the Oracle of Dereth `customquests.csv` (by Advis).
- AC:Unreal client and plugin framework by Thwargle.
