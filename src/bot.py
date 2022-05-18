import discord
from random import randrange
import datetime as dt

def pick_datetime() -> dt.datetime:
    day_period = 365
    return dt.datetime.utcnow() + dt.timedelta(days=randrange(0,int(day_period/2))) - dt.timedelta(days=day_period)

class CarlitoBot(discord.Client):
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
        if not (self.user.mentioned_in(message) or randrange(0,75) == 7):
            return
        print('Searching `{0}` history...'.format(message.channel))
        async with message.channel.typing():
            old_message = None
            target_datetime = pick_datetime()
            repeat_count = 0
            datetime_offset = dt.timedelta(minutes=0)
            while old_message == None:
                hist_count = 0
                max_hist_count = randrange(0,5)+1
                async for hist_message in message.channel.history(limit=101, around=target_datetime+datetime_offset, oldest_first=True):
                    if hist_message.content != "" and hist_message.author.id != self.user.id:
                        hist_count += 1
                    if hist_count == max_hist_count:
                        old_message = hist_message
                        break
                repeat_count += 1
                if repeat_count > 15:
                    datetime_offset += dt.timedelta(minutes=30)
                    repeat_count = 0
            await message.channel.send(old_message.content)
        print('Done!')
        
if __name__ == "__main__":
    token = ''
    with open('res/token', 'r') as token_file:
        token = token_file.readlines()[0]
        token_file.close()
    client = CarlitoBot()
    client.run(token)
