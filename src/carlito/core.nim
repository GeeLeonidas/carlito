import dimscord
export dimscord

import puppy

import std / [asyncdispatch, os, times, random, re]

const
  DiscordEpoch* = 1_420_070_400_000
  DataDir* =
    when hostOS == "windows":
      os.getEnv("APPDATA") / "carlito"
    else:
      os.getEnv("HOME") / ".local/share/carlito"
  DomainWhitelist* = [
    "youtube.com",
    "youtu.be",
    "twitch.tv",
    "tenor.com",
    "tenor.co",
    "reddit.com",
    "twitter.com",
    "fxtwitter.com",
    "vxtwitter.com"
  ]

proc hasUnsafeDomains(content: string): bool =
  let pattern = re"https:\/\/(?:.+\.|)(\w+\.\w+)(?:\s|\/|)"
  var domainMatches: array[9, string]
  if content.find(pattern, domainMatches) >= 0:
    if domainMatches[domainMatches.high] != "":
      return true
    for i in 0 ..< domainMatches.high:
      if domainMatches[i] == "":
        break
      if DomainWhitelist.contains(domainMatches[i]):
        continue
      return true

proc mentionsUser*(m: Message, user: User): bool =
  for mentionUser in m.mentionUsers:
    if user.id == mentionUser.id:
      return true
  return false

proc toSnowflake*(time: Time; lowerBitsState = false): int64 =
  let
    unixTime = time.toUnixFloat()
    discordMillis = int64(1000 * unixTime) - DiscordEpoch
    lowerBits = lowerBitsState.ord * ((1 shl 22) - 1)
  return (discordMillis shl 22) + lowerBits

proc pickStreamCode*(): string =
  result = "wDgQdr8ZkTw"
  let
    pattern = re"https:\/\/(?:www\.|)youtube\.com\/(?:[a-z]+)\/([^\?\/]+)"
    petit = fetch("https://petittube.com/")
  var youtubeMatches: array[8, string]
  if petit.find(pattern, youtubeMatches) >= 0:
    return youtubeMatches[0]

proc pickPremiumContent*(): string =
  const PremiumContent = [
    "*This message was hidden from you. For more fun content, please acquire a Carlito Premium membership.*",
    "*Do you wish you could see more Carlito stuff? Unlock it now with a Carlito Season Pass\\™!*",
    "https://web.archive.org/web/20130301115921/http://www.clubpenguin.com/",
    "https://tenor.com/view/fire-writing-gif-24533171",
    "https://tenor.com/view/troll-trolled-trollge-troll-success-gif-22597471",
    "https://tenor.com/view/atumalaca-gif-24891113"
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
    if len(messages) == 0:
      continue
    for j in 0..high(messages):
      let m = messages[j]
      if m.content == "" or
         m.mentionsUser(s.user) or
         m.author.id == s.user.id or
         m.content.hasUnsafeDomains() or
         m.content.match(re"(p|P)(e|E)(t|T)(i|I)(t|T)") or
         m.content.match(re"(c|C)(a|A)(r|R)(l|L)(i|I)(t|T)(o|O)") or
         (selectedDateTime + initTimeInterval(days = 1)).toTime() < timestamp(m.id):
        continue
      return m.content