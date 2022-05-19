import discord
from random import randrange, shuffle
import datetime as dt


def pick_datetime() -> dt.datetime:
    day_period = 365
    return dt.datetime.utcnow() + dt.timedelta(days=randrange(0,int(day_period/2))) - dt.timedelta(days=day_period)


async def pick_message(channel: discord.TextChannel, ignored_id: int) -> discord.Message:
    repeat_count = 0
    datetime_offset = dt.timedelta(minutes=0)
    target_datetime = pick_datetime()
    while True:
        hist_count = 0
        max_hist_count = randrange(0,5)+1
        async for hist_message in channel.history(limit=101, around=target_datetime+datetime_offset):
            if hist_message.content != "" and hist_message.author.id != ignored_id:
                hist_count += 1
            if hist_count == max_hist_count:
                return hist_message
        repeat_count += 1
        if repeat_count > 15:
            datetime_offset += dt.timedelta(minutes=30)
            repeat_count = 0


class CarlitoBot(discord.Client):
    async def handle_command(self, message):
        if not message.content.startswith('g.'):
            return
        
        cmd_args = message.content.split(' ')
        cmd = cmd_args.pop(0)
        
        if cmd == 'g.ee':
            pass # Debug command


    async def on_ready(self):
        print('Logged on as {0}!'.format(self.user))


    async def on_message(self, message):
        if message.author.id == self.user.id:
            return
        if message.author.bot:
            return
        if message.channel is discord.DMChannel or message.channel is discord.GroupChannel:
            return
        if message.channel.slowmode_delay > 0:
            return
        if message.channel.is_nsfw():
            return

        await self.handle_command(message)
        
        if randrange(0, 75) == 0:
            async with message.channel.typing():
                main = await pick_message(message.channel, ignored_id=self.user.id)
                other = await pick_message(message.channel, ignored_id=self.user.id)
                
                main_words = main.content.split(' ')
                other_words = other.content.split(' ')
                shuffle(other_words)
                
                word_ratio = len(other_words) / len(main_words)
                for i in range(len(other_words)):
                    main_words.insert(1 + int(i / word_ratio), other_words[i])
                await message.channel.send(' '.join(main_words))
                print('Sent a mashup message on #{0}'.format(message.channel))
        elif self.user.mentioned_in(message):
            async with message.channel.typing():
                old_message = await pick_message(message.channel, ignored_id=self.user.id)
                await message.channel.send(old_message.content)
                print('Sent a response message on #{0}`'.format(message.channel))


if __name__ == "__main__":
    token = ''
    with open('res/token', 'r') as token_file:
        token = token_file.readlines()[0]
        token_file.close()
    
    client = CarlitoBot()
    client.run(token)
