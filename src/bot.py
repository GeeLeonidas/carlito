from genericpath import exists
import discord
from random import randrange, shuffle
import datetime as dt
from time import monotonic


picked_messages = {}
def flush_picked_messages():
    with open('res/picked', 'w') as picked_file:
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


    async def handle_command(self, message):
        if not message.content.startswith('g.'):
            return
        if message.author.id != 163379389164290049:
            return
        
        cmd_args = message.content.split(' ')
        cmd = cmd_args.pop(0)
        
        if cmd == 'g.ee':
            photo_gif = 'https://tenor.com/view/camera-taking-pictures-gif-9980532'
            creation_time = dt.datetime.fromisoformat('2022-05-18 01:00:25.939000')
            
            async for hist_message in message.channel.history(limit=None, after=creation_time):
                if hist_message.content == photo_gif and hist_message.author.id == self.user.id:
                    await hist_message.delete()
            
            await message.channel.send(photo_gif)
            
            start = monotonic()
            print("Taking a snapshot...")
            
            with open('res/{0}.txt'.format(message.channel), 'w') as message_log:
                history = message.channel.history(
                    limit=None,
                    before=creation_time,
                    oldest_first=True
                )
                async for hist_message in history:
                    if hist_message.content == "":
                        continue
                    if hist_message.author.id == self.user.id:
                        continue
                    
                    log_message = '{0}\n{1}\n\n'.format(
                        hist_message.author.id,
                        hist_message.content. \
                            replace('\\', '\\\\'). \
                            replace('\n', '\\n')
                    )
                    message_log.write(log_message)
                message_log.close()
            
            print("Snapshot done in {0:.2f}s!".format(monotonic() - start))


    async def on_ready(self):
        print('Logged on as {0}!'.format(self.user))
        if exists('res/sent.txt'):
            with open('res/picked', 'r') as picked_file:
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

        await self.handle_command(message)
        
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
    token = ''
    with open('res/token', 'r') as token_file:
        token = token_file.readlines()[0]
        token_file.close()
    
    client = CarlitoBot()
    client.run(token)
