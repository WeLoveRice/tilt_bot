# bot.py
import os
import discord
import sys
import psycopg2
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

# on message, check for command trigger !Ranked
# reply with summoner_data for today
@client.event
async def on_message(message):

    if message.author == client.user:
        return

    if message.content[:7] == '!Ranked':
        summoner = str(message.content).replace('!Ranked ', '')
        await message.channel.send(summoner_response(summoner))

# get summoner_data from postgres and format message
def summoner_response(summoner):

    # create connection
    pg_con = psycopg2.connect(host=pg_ip, database=pg_db, user=pg_user, password=pg_pw)

    # create cursor
    cur = pg_con.cursor()

    # SQL Query for summoner data
    query_string = f"SELECT * FROM daily_update WHERE summoner_name = '{summoner}'"

    # execute query, create summoner_data from response
    cur.execute(query_string)
    summoner_data = cur.fetchall()[0]

    # format LP_change as signed integer
    LP_change = ["", "+"][summoner_data[3] > 0] + str(summoner_data[3])

    # format summoner_data as message for discord
    msg_str = f'_ _\n {summoner_data[0]} | {summoner_data[4]} {summoner_data[5]} | {summoner_data[6]}LP\n```Wins:   {summoner_data[1]}\nLosses: {summoner_data[2]}\nLP:     {LP_change}```'

    # close postgres connection
    pg_con.close()

    # return message for discord
    return(msg_str)

# run client with token
client.run(TOKEN)
