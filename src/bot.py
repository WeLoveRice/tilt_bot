# bot.py
import os
import discord
import sys
import psycopg2
import os.path
from dotenv import load_dotenv

load_dotenv()

# discord token
TOKEN = os.getenv('DISCORD_TOKEN')

# postgres credentials
pg_user = os.getenv('pg_user')
pg_pw = os.getenv('pg_pw')
pg_ip = os.getenv('pg_ip')
pg_db = os.getenv('pg_db')

# create discord client
client = discord.Client()

# when client is ready, print status message
@client.event
async def on_ready():
    print(
        f'{client.user} is connected'
    )

# get summoner_data from postgres and format message
def summoner_response(summoner):

    # create connection
    pg_con = psycopg2.connect(host=pg_ip, database=pg_db, user=pg_user, password=pg_pw)

    # create cursor
    cur = pg_con.cursor()

    # SQL Query for summoner data
    query_string = f'SELECT "summonerName","queueType","tier","rank","leaguePoints","wins","losses" FROM raw_data WHERE LOWER("summonerName") = \'{summoner}\' AND "timestamp" = (SELECT MAX("timestamp") FROM raw_data WHERE LOWER("summonerName") = \'{summoner}\');'

    # execute query, create summoner_data from response
    cur.execute(query_string)
    summoner_data = cur.fetchall()

    msg_str = f'{summoner_data[0][0]}:'

    for queue in summoner_data:
        msg_str = f'{msg_str}\n{queue[1]} | {queue[2]} {queue[3]} {queue[4]}LP\n```Wins:   {queue[5]}\nLosses: {queue[6]}```'

    # close postgres connection
    pg_con.close()

    # return message for discord
    return(msg_str)

leaderboard_msg_id = 1
@client.event
async def on_message(message):
    if message.author == client.user:
        return

    global leaderboard_msg_id

    temp_string = message.content

    if '!leaderboard' in temp_string.lower():
        if not leaderboard_msg_id == 1:
            await client.http.delete_message("185442367703220224", leaderboard_msg_id)
        if os.path.exists('leaderboard.png'):
            msg = await message.channel.send(file=discord.File('leaderboard.png'))
        else:
            msg = await message.channel.send("```No bois sweating LoL today```")
        leaderboard_msg_id = msg.id

    temp_string = message.content[:7]

    if temp_string.lower() == '!ranked':
        print('if statement worked')
        temp_string = message.content
        temp_string = temp_string.lower()
        summoner = temp_string.replace('!ranked ', '')
        await message.channel.send(summoner_response(summoner))



# run client with token
client.run(TOKEN)
