# bot.py
import os
import discord
from dotenv import load_dotenv

load_dotenv()
TOKEN = os.getenv('DISCORD_TOKEN')
GUILD = os.getenv('DISCORD_GUILD')

client = discord.Client()

@client.event
async def on_ready():
    print(
        f'{client.user} is connected'
    )

@client.event
async def on_message(message):

    if message.author == client.user:
        return

    if message.content[:7] == '!Ranked':
        summoner = str(message.content).replace('!Ranked ', '')
        await message.channel.send(summoner_response(summoner))

def summoner_response(summoner):
    import psycopg2
    # Create connection
    pg_user = "admin"
    pg_pw = "CunningPassword"
    pg_ip = "35.222.94.140"
    pg_db = "postgres"

    pg_con = psycopg2.connect(host=pg_ip, database=pg_db, user=pg_user, password=pg_pw)

    cur = pg_con.cursor()

    query_string = f"SELECT * FROM daily_update WHERE summoner_name = '{summoner}'"

    cur.execute(query_string)

    summoner_data = cur.fetchall()[0]

    LP_change = ["", "+"][summoner_data[3] > 0] + str(summoner_data[3])

    msg_str = f'_ _\n {summoner_data[0]} | {summoner_data[4]} {summoner_data[5]} | {summoner_data[6]}LP\n```Wins:   {summoner_data[1]}\nLosses: {summoner_data[2]}\nLP:     {LP_change}```'

    pg_con.close()

    return(msg_str)

client.run(TOKEN)
