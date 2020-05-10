# tilt_glen.py
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

# when client is ready, message channel glen's losses
@client.event
async def on_ready():
    
    # status check, print when connected
    print(
        f'{client.user} is connected'
    )
    
    # set channel as main text channel
    channel = client.get_channel(185442367703220224)

    # use function to get loss_num
    loss_num = get_loss_counter()

    # message saying how many games glenn has lost today
    if loss_num == 1:
        msg_str = f'_ _ \n```Glen has lost {loss_num} game today.```'
    else:
        msg_str = f'_ _ \n```Glen has lost {loss_num} games today.```'
    await channel.send(msg_str)
    
    # close client and exit script
    client.close()
    sys.exit()

# get loss info from postgres
def create_leaderboard():
    import psycopg2

    # create connection
    pg_con = psycopg2.connect(host=pg_ip, database=pg_db, user=pg_user, password=pg_pw)

    # create cursor
    cur = pg_con.cursor()

    # query string to select glenn's row from daily_update
    query_string = f"SELECT * FROM daily_table;"

    # execute query, create summoner_data from response
    cur.execute(query_string)
    leaderboard = cur.fetchall()

    table = f"Summoner |Queue | Wins| Losses| LP Change|"
    table = f"{table}/n|-----|-----|-----:|-----:|-----:|"

    for summoner_data in leaderboard:
        table = f"{table}/n{summoner_data[0]} |{summoner_data[1]} | {summoner_data[2]}| {summoner_data[3]}| {summoner_data[4]}|"

    # close postgres connection
    pg_con.close()

    # return number of losses
    return(table)

# run client with token
client.run(TOKEN)

# close client and exit script
client.close()
sys.exit()