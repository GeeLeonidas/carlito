import dotenv
import carlito / core
import std / [asyncdispatch, os, re, options, tables, random, strformat, sugar]

if os.fileExists(".env"):
  dotenv.load()
assert os.existsEnv("CARLITO_TOKEN"), "Env variable `CARLITO_TOKEN` is missing!"
let discord = newDiscordClient(os.getEnv("CARLITO_TOKEN"))
var
  currentMemberTable: Table[string, Member]
  userCooldown: Table[string, int]

proc onReady(s: Shard, r: Ready) {.event(discord).} =
  if fileExists(DataDir / "guild_ids"):
    let
      api = s.client.api
      guildIds = readFile(DataDir / "guild_ids").split(re"\n")

    for guildId in guildIds:
      if guildId == "": continue
      try:
        currentMemberTable[guildId] = await api.getGuildMember(guildId, s.user.id)
        await s.voiceStateUpdate(guildId)
      except:
        continue
  echo r.user, " is ready!"
  while true:
    let keys = collect:
      for key in userCooldown.keys: key
    for key in keys:
      dec userCooldown[key]
      if userCooldown[key] <= 0:
        userCooldown.del(key)
    await sleepAsync 1000

proc messageCreate(s: Shard, m: Message) {.event(discord).} =
  if m.author.bot:
    return

  let
    api = s.client.api
    guildId = try: m.guildId.get() except UnpackDefect: return
    channel =
      if s.cache.guildChannels.hasKey(m.channelId):
        s.cache.guildChannels[m.channelId]
      else:
        (await api.getChannel(m.channelId))[0].get()
  
  if channel.rate_limit_per_user.get() > 0 or
     channel.nsfw or channel.name.contains(re"(n|N)(s|S)(f|F)(w|W)"):
    return

  if not currentMemberTable.hasKey(guildId):
    currentMemberTable[guildId] = await api.getGuildMember(guildId, s.user.id)
    var guildIds: string
    for guildId in s.cache.guilds.keys:
      guildIds.add(guildId & '\n')
    writeFile(DataDir / "guild_ids", guildIds)

  let
    guild = s.cache.guilds[guildId]
  #[ TODO: Figure out why perm checking doesn't work  
    member = currentMemberTable[guildId]
    permsGuild = guild.computePerms(member)
    permsChannel = guild.computePerms(member, channel)

  if permSendMessages.violates(permsGuild, permsChannel):
    return
  if permReadMessageHistory.violates(permsGuild, permsChannel):
    return
  ]#

  let wasMentioned = m.mentionsUser(s.user)
  if wasMentioned or rand(50) == 0: # 2% chance
    if not wasMentioned:
      if userCooldown.getOrDefault(m.author.id) > 0:
        return
      else:
        userCooldown[m.author.id] = 300
    let messageBegin =
      if wasMentioned:
        "Response"
      else:
        "Message"
    try:
      await api.triggerTypingIndicator(m.channelId)
    except RestError:
      return
    let
      pick = await s.pickContent(m.channelId)
      content =
        if pick == "":
          pickPremiumContent()
        else:
          pick
    discard await api.sendMessage(m.channelId, content)
    echo fmt"{messageBegin} sent to #{channel.name} ({guild.name})"

randomize()
os.createDir(DataDir)
waitFor discord.startSession(
  gatewayIntents = {
    giGuilds, giGuildMessages, giDirectMessages,
    giGuildVoiceStates, giMessageContent, giGuildMembers
  }
)