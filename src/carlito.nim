import dotenv
import carlito / core
import std / [asyncdispatch, os, re, options, tables, random, strformat]

if os.fileExists(".env"):
  dotenv.load()
assert os.existsEnv("CARLITO_TOKEN"), "Env variable `CARLITO_TOKEN` is missing!"
let discord = newDiscordClient(os.getEnv("CARLITO_TOKEN"))
var
  currentMemberTable: Table[string, Member]
  sessionReadyTable: Table[string, bool]

proc voiceServerUpdate(s: Shard, g: Guild, token: string,
    endpoint: Option[string], initial: bool) {.event(discord).} =
  let vc = s.voiceConnections[g.id]

  vc.voiceEvents.onReady = proc (v: VoiceClient) {.async.} =
    sessionReadyTable[g.id] = true

  vc.voiceEvents.onSpeaking = proc (v: VoiceClient, state: bool) {.async.} =
    if not state and v.sent == 0:
      await s.voiceStateUpdate(g.id)

  await vc.startSession()

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
    member = currentMemberTable[guildId]
    permsGuild = guild.computePerms(member)
    permsChannel = guild.computePerms(member, channel)

  if permSendMessages in (permsGuild.denied + permsChannel.denied) or
     permReadMessageHistory in (permsGuild.denied + permsChannel.denied):
    return

  let wasMentioned = m.mentionsUser(s.user)
  if m.author.id in guild.voiceStates and m.content.contains(re"(p|P)(e|E)(t|T)(i|I)(t|T)"):
    if sessionReadyTable.getOrDefault(guildId):
      return
    let voiceChannelId = guild.voiceStates[m.author.id].channelId
    await s.voiceStateUpdate(
      guildId = guildId,
      channelId = voiceChannelId,
      selfDeaf = true
    )
    sessionReadyTable[guildId] = false
    for tries in 1..5:
      let streamCode = pickStreamCode()
      try:
        let voiceChannel = s.cache.guildChannels[voiceChannelId.get()]
        echo fmt"Playing https://youtu.be/{streamCode} at {voiceChannel.name} ({guild.name})"
        while not sessionReadyTable[guildId]:
          await sleepAsync 200
        let
          vc = s.voiceConnections[guildId]
          streamUrl = fmt"https://youtube.com/embed/{streamCode}"
        var
          elapsedMillis: int
          stream = vc.playYTDL(streamUrl, command="yt-dlp")
        while elapsedMillis < 10_000 and not stream.finished:
          await sleepAsync 200
          elapsedMillis += 200
        vc.stopped = true
        await stream
        return
      except IOError:
          echo fmt"Couldn't play https://youtu.be/{streamCode} (IOError), retrying..."
          continue
  elif wasMentioned or rand(50) == 0: # 2% chance
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
waitFor discord.startSession(
  gatewayIntents = {
    giGuilds, giGuildMessages, giDirectMessages,
    giGuildVoiceStates, giMessageContent, giGuildMembers
  }
)