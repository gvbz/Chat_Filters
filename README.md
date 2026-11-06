# Chat Filters

A chat filter and alerting plugin for the AC:Unreal client. Hides various chat lines by category and has custom alerting functionality that can trigger a sound or direct chat to a specific window. Tie alerts to quest flags and they can automatically enable/disable on cooldown/completion.

Chat Filters will automatically read the /myquests database dump from the KT_tracker plugin if it's installed, this provides cooldown and quest status on the alert rules with quest flags. It also cuts down on polling the server/client for data. You can manually read /myquests data through the plugin interface and also enable an on-login /myquests command. 

<img width="281" height="437" alt="Chat_Filters_2" src="https://github.com/user-attachments/assets/18b04e9f-3dbb-434a-95a1-b969af898630" />
<img width="283" height="439" alt="Chat_Filters_1" src="https://github.com/user-attachments/assets/5ad29954-efca-44bb-b8fa-75510d816406" />

## Requirements

- AC:Unreal client v146 or newer.

## Install

1. Unzip into `ACUnreal\Saved\ClientPlugins\Installed`. The path ends in `Installed\Chat_Filters\plugin.json`.
2. Open the plugin menu, press **Refresh**, then **Enable** Chat Filters.

## Update

Replace the files in `Installed\Chat_Filters` and press **Refresh**. Your filters, alerts and settings are kept.

## Filters

Checkboxes by category, based on UtilityBelt's ChatFilter: Attacks on you, Attacks on your target, Misc, You cast, Others cast, Recharge and Messages.

- An enabled rule hides those lines in every chat window. The chat log and other plugins still receive them.
- **Filters on** turns all filters off or on. 
- Not available: Debuffs, Debuff on target and Others' buffs. Chat lines can't identify whether a spell is a buff or a debuff right now.

## Alerts

Alerts check players' chat (General, Tells, Allegiance, Fellowship, Area chat) and server messages. Trade, LFG, Roleplay, Society, Olthoi, NPCs and vendors are not checked. Letter case doesn't matter.

**Match**:

- **All words** (default): each word in the entry appears anywhere in the line, in any order. "darsh down" matches "darsh is down" and "darshmaul is down". Avoid short words like IG or single numbers.
- **Whole words**: the entire entry must appear as written somewhere in the chat line. "IG" matches "IG is up" but not "big".
- **Exact line**: the entire entry must match the entire chat line.

A matching line:

- also shows in the window chosen in **Settings > Send alerts to**, in the **Alert color** (red by default);
- stays where it normally shows;
- if enabled, plays an icq.wav sound at most once per alert every 5 seconds;
- is added to the **Alert list** tab (the last 20).

**Quest flag** (optional): type part of a flag or quest name and click a match. The alert shows the quest's status (green ready, red time left) and is paused while the quest is on cooldown.

Each alert has three buttons:

- **C**: show the quest's hint in chat.
- **E**: edit the alert.
- **X**: remove the alert.

The plugin starts with some of Conquest's custom quests as alerts, turned off. These provide good examples.<img width="281" height="437" alt="Chat_Filters_2" src="https://github.com/user-attachments/assets/6b0a878b-bd00-41a5-ab1d-d224fe5814a8" />


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
