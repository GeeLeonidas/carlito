import dotenv
import carlito / core
import std / [asyncdispatch, os, re, options, tables, random, strformat]

if os.fileExists(".env"):
  dotenv.load()
assert os.existsEnv("CARLITO_TOKEN"), "Env variable `CARLITO_TOKEN` is missing!"
let discord* = newDiscordClient(os.getEnv("CARLITO_TOKEN"))
var currentMemberTable*: Table[string, Member]

proc onReady(s: Shard, r: Ready) {.event(discord).} =
  if fileExists(DataDir / "guild_ids"):
    let
      api = s.client.api
      guildIds = readFile(DataDir / "guild_ids").split(re"\n")

    for guildId in guildIds:
      if guildId == "": continue
      try:
        currentMemberTable[guildId] = await api.getGuildMember(guildId, s.user.id)
      except:
        continue
  echo r.user, " is ready!"

proc messageCreate(s: Shard, m: Message) {.event(discord).} =
  if m.author.bot:
    return

  let
    api = s.client.api
    guildId =
      try:
        m.guildId.get()
      except UnpackDefect:
        return
    channel = s.cache.guildChannels[m.channelId]
  
  if channel.rate_limit_per_user.get() > 0 or
     channel.nsfw or channel.name.match(re"(n|N)(s|S)(f|F)(w|W)"):
    return

  if not currentMemberTable.hasKey(guildId):
    currentMemberTable[guildId] = await api.getGuildMember(guildId, s.user.id)
    var guildIds: string
    for guildId in s.cache.guilds.keys:
      guildIds.add(guildId & '\n')
    writeFile(DataDir / "guild_ids", guildIds)

  let
    guild = s.cache.guilds[guildId]
    member = currentMemberTable[guildId]
    permsGuild = guild.computePerms(member)
    permsChannel = guild.computePerms(member, channel)

  if permSendMessages in (permsGuild.denied + permsChannel.denied) or
     permReadMessageHistory in (permsGuild.denied + permsChannel.denied):
    return

  let wasMentioned = m.mentionsUser(s.user)
  if rand(50) == 0 or wasMentioned: # 2% chance
    await api.triggerTypingIndicator(m.channelId)
    let
      pick = await s.pickContent(m.channelId)
      content =
        if pick == "":
          pickPremiumContent()
        else:
          pick
      messageBegin =
        if wasMentioned:
          "Response"
        else:
          "Message"
    discard await api.sendMessage(m.channelId, content)
    echo fmt"{messageBegin} sent to #{channel.name} ({guild.name})"

randomize()
os.createDir(DataDir)
waitFor discord.startSession()