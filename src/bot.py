from genericpath import exists
import discord
from random import randrange, shuffle
import datetime as dt
from time import monotonic
from os import environ, makedirs


carlito_folder = environ['HOME'] + '/.local/share/carlito'
def res(file: str) -> str:
    return carlito_folder + '/res/' + file

picked_messages = {}
def flush_picked_messages():
    with open(res('picked'), 'w') as picked_file:
        for key in picked_messages.keys():
            picked_file.write(f'{key}\n')
        picked_file.close()
        

def pick_datetime() -> dt.datetime:
    day_period = 365
    return dt.datetime.utcnow() + dt.timedelta(days=randrange(0,int(day_period*0.75))) - dt.timedelta(days=day_period)


async def pick_message(channel: discord.TextChannel, ignored_id: int, add_to_picked_messages=False) -> discord.Message:
    repeat_count = 0
    datetime_offset = dt.timedelta(minutes=0)
    target_datetime = pick_datetime()
    while True:
        hist_count = 0
        max_hist_count = randrange(0,5)+1
        async for hist_message in channel.history(limit=101, around=target_datetime+datetime_offset):
            message_hash = hash(hist_message.content)
            prohibited = hist_message.content == "" or \
                hist_message.author.id == ignored_id or \
                message_hash in picked_messages
            if not prohibited:
                hist_count += 1
            if hist_count == max_hist_count:
                if add_to_picked_messages:
                    picked_messages[message_hash] = True
                    flush_picked_messages()
                return hist_message
        repeat_count += 1
        if repeat_count > 15:
            datetime_offset += dt.timedelta(minutes=30)
            repeat_count = 0


class CarlitoBot(discord.Client):
    def __init__(self, *, loop=None, **options):
        super().__init__(loop=loop, **options)


    async def on_ready(self):
        print('Logged on as {0}!'.format(self.user))
        if exists('res/sent.txt'):
            with open(res('picked'), 'r') as picked_file:
                for hash_txt in picked_file.readlines():
                    picked_messages[int(hash_txt)] = True
                picked_file.close()


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
                await message.channel.send(old_message.content)
                print(f'Sent a response message on #{message.channel} ({message.guild})')


if __name__ == "__main__":
    makedirs(carlito_folder + '/res', exist_ok=True)
    client = CarlitoBot()
    client.run(environ['CARLITO_TOKEN'])
