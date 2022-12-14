from genericpath import exists
import discord
from random import randrange, shuffle
import datetime as dt
from os import environ, makedirs
import pickle as pk


carlito_folder = environ['HOME'] + '/.local/share/carlito'
def res(file: str) -> str:
    return carlito_folder + '/res/' + file

picked_messages = {}
def flush_picked_messages():
    with open(res('picked'), 'wb') as picked_file:
        pk.dump(obj=picked_messages, file=picked_file)
        

def pick_datetime() -> dt.datetime:
    day_period = 365
    return dt.datetime.utcnow() + dt.timedelta(days=randrange(0,int(day_period*0.75))) - dt.timedelta(days=day_period)


async def pick_message(channel: discord.TextChannel, ignored_id: int, add_to_picked_messages=False) -> discord.Message:
    datetime_offset = dt.timedelta(minutes=0)
    target_datetime = pick_datetime()
    while True:
        hist_count = 0
        max_hist_count = randrange(0,2)+1
        async for hist_message in channel.history(limit=3, around=target_datetime+datetime_offset):
            message_hash = hash(hist_message.content)
            prohibited = hist_message.content == "" or \
                hist_message.author.id == ignored_id or \
                message_hash in picked_messages
            hist_count += 1
            if not prohibited and hist_count >= max_hist_count:
                if add_to_picked_messages:
                    picked_messages[message_hash] = True
                    flush_picked_messages()
                limit = (dt.datetime.utcnow() - dt.timedelta(days=85))
                if hist_message.created_at.timestamp() < limit.timestamp():
                    return hist_message
                else:
                    return None # Message is too new
        datetime_offset += dt.timedelta(days=1)


class CarlitoBot(discord.Client):
    def __init__(self, *, loop=None, **options):
        intents = discord.Intents().default()
        super().__init__(loop=loop, intents=intents, **options)


    async def on_ready(self):
        print('Logged on as {0}!'.format(self.user))
        if exists('res/sent.txt'):
            with open(res('picked'), 'rb') as picked_file:
                picked_messages = pk.load(file=picked_file)


    async def ask_premium(self, channel):
        channel.send('*This message was hidden from you. For more fun content, please acquire a Carlito Premium membership.*')
        print(f'Sent a premium message on #{channel} ({channel.guild})')


    async def on_message(self, message):
        bot_member = message.guild.get_member(self.user.id)
        if not message.channel.permissions_for(bot_member).send_messages:
            return
        if message.author.bot:
            return
        if message.channel is discord.DMChannel or message.channel is discord.GroupChannel:
            return
        if message.channel.slowmode_delay > 0:
            return
        if message.channel.is_nsfw() or 'nsfw' in message.channel.name:
            return
        
        if randrange(0, 66) == 0:
            if randrange(0, 4) == 0:
                return
            async with message.channel.typing():
                main = await pick_message(message.channel, ignored_id=self.user.id)
                other = await pick_message(message.channel, ignored_id=self.user.id)
                
                if main is None or other is None:
                    await self.ask_premium(message.channel)

                main_words = main.content.split(' ')
                other_words = other.content.split(' ')
                shuffle(other_words)
                
                word_ratio = len(other_words) / len(main_words)
                for i in range(len(other_words)):
                    main_words.insert(1 + int(i / word_ratio), other_words[i])
                await message.channel.send(' '.join(main_words))
                print(f'Sent a mashup message on #{message.channel} ({message.guild})')
        elif self.user.mentioned_in(message):
            async with message.channel.typing():
                old_message = await pick_message(message.channel, ignored_id=self.user.id, add_to_picked_messages=True)

                if old_message is None:
                    await self.ask_premium(message.channel)

                await message.channel.send(old_message.content)
                print(f'Sent a response message on #{message.channel} ({message.guild})')


if __name__ == "__main__":
    makedirs(carlito_folder + '/res', exist_ok=True)
    client = CarlitoBot()
    client.run(environ['CARLITO_TOKEN'])
