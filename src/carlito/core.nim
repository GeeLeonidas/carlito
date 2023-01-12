import dimscord
export dimscord

import std / [asyncdispatch, os, times, tables, random]

const
  DiscordEpoch* = 1_420_070_400_000
  DataDir* =
    when hostOS == "windows":
      os.getEnv("APPDATA") / "carlito"
    else:
      os.getEnv("HOME") / ".local/share/carlito"

converter toApi*(s: Shard): RestApi = s.client.api

proc mentionsUser*(m: Message, user: User): bool =
  for mentionUser in m.mentionUsers:
    if user.id == mentionUser.id:
      return true
  return false

proc toSnowflake*(time: Time; bit = false): int64 =
  let
    unixTime = time.toUnixFloat()
    discordMillis = int64(1000 * unixTime) - DiscordEpoch
    lowerBits = if bit: (1 shl 22) - 1 else: 0
  return (discordMillis shl 22) + lowerbits

proc pickPremiumContent*(): string =
  const PremiumContent = [
    "*This message was hidden from you. For more fun content, please acquire a Carlito Premium membership.*",
    "*Do you wish you could see more Carlito stuff? Unlock it now with a Carlito Season Pass\\™!*",
    "https://tenor.com/view/fire-writing-gif-24533171"
  ]
  return sample(PremiumContent)

proc pickContent*(s: Shard, channelId: string): Future[string] {.async.} =
  result = ""
  let
    timeAnchor = now().utc() - initTimeInterval(days = rand(95..360))
    sign = 2 * rand(1) - 1
  for i in 0..5:
    let
      selectedDateTime = timeAnchor + initTimeInterval(days = sign * i)
      selectedSnowflake = selectedDateTime.toTime().toSnowflake()
      messages = await s.client.api.getChannelMessages(
        channelId,
        limit = 4,
        around = $selectedSnowflake,
      )
    if len(messages) == 0: continue
    for j in 0..high(messages):
      let m = messages[j]
      if m.author.id == s.user.id: continue
      if m.mentionsUser(s.user): continue
      if m.content == "": continue
      return m.content