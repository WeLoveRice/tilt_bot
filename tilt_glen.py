# bot.py
import os
import discord
import sys
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
    channel = client.get_channel(185442367703220224)
    #test_channel
    #channel = client.get_channel(706608226442936482)
    
    loss_num = get_loss_counter()

    if loss_num == 1:
        msg_str = f'_ _ \n```Phoenix MT has lost {loss_num} game today.```'
    else:
        msg_str = f'_ _ \n```Phoenix MT has lost {loss_num} games today.```'
    await channel.send(msg_str)
    sys.exit()

def get_loss_counter():
    import psycopg2
    # Create connection
    pg_user = "admin"
    pg_pw = "CunningPassword"
    pg_ip = "35.222.94.140"
    pg_db = "postgres"

    pg_con = psycopg2.connect(host=pg_ip, database=pg_db, user=pg_user, password=pg_pw)

    cur = pg_con.cursor()

    query_string = f"SELECT * FROM daily_update WHERE summoner_name = 'Phoenix MT'"

    cur.execute(query_string)

    summoner_data = cur.fetchall()[0]

    pg_con.close()

    return(summoner_data[2])

client.run(TOKEN)
client.close()
sys.exit()
