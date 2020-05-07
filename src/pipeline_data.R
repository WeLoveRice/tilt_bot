# Install Packages
if (!require("pacman")) install.packages("pacman")
pacman::p_load(RPostgres, jsonlite, curl, data.table, dplyr, lubridate)

# import variables from .env
dotenv_df <- read.table(file=paste0(".env"),
                        header=FALSE,
                        sep='=',
                        col.names=c('Key','Value'),
                        stringsAsFactors = FALSE,
                        encoding="UTF-8")

dotenv_dt <- data.table(dotenv_df, key="Key")

print('credentials read from .env file')

# set postgres details from .env variables
pg_user <- dotenv_dt['pg_user']$Value
pg_pw <- dotenv_dt['pg_pw']$Value
pg_ip <- dotenv_dt['pg_ip']$Value
pg_db <- dotenv_dt['pg_db']$Value
rm(dotenv_df,dotenv_dt)


# create connection to postgres
pg_con <- dbConnect(Postgres(),
                 user = pg_user,
                 password = pg_pw,
                 host = pg_ip,
                 dbname = pg_db,
                 bigint = "numeric")

print('postgres connection created')

# SQL Query to get data for today
query_string <- '
SELECT 
    "summonerName",
    "queueType",
    "tier",
    "rank",
    "leaguePoints",
    "wins",
    "losses",
    "timestamp"
FROM 
    raw_data
WHERE 
    "timestamp" >= current_date;'

# import SQL query as aggregate data, data shown for every summoner for today
aggregate_data <- dbGetQuery(pg_con, query_string)

print('data for today pulled from postgres db')

# loop through each unique summoner_name in aggregate_data
for (summoner in unique(aggregate_data$summonerName)){
    
    # filter data for current summoner_name
    summoner_data <- filter(aggregate_data, summonerName == summoner)
    
    for (queue in unique(summoner_data$queueType)){
        
        queue_data <- filter(summoner_data, queueType == queue)
        
        # create dataframe for daily_update table
        update_data <- data.frame(
            summoner_name = summoner,
            queue = queue,
            wins = filter(queue_data, timestamp == max(timestamp))$wins - filter(queue_data, timestamp == min(timestamp))$wins,
            losses = filter(queue_data, timestamp == max(timestamp))$losses - filter(queue_data, timestamp == min(timestamp))$losses,
            LP_change = filter(queue_data, timestamp == max(timestamp))$leaguePoints - filter(queue_data, timestamp == min(timestamp))$leaguePoints,
            tier = unique(queue_data$tier),
            rank = unique(queue_data$rank),
            current_LP = filter(queue_data, timestamp == max(timestamp))$leaguePoints
        )
        
        # if daily_update variable exists, use rbind to combine with update_data
        if (exists("daily_table")){
            daily_table <- rbind(daily_table, update_data)
        # else create daily_update from update_data
        } else{ daily_table <- update_data }
        
    }# end of for loop
}# end of for loop 

print('daily table created')

stop()

# remove aggregate_data
rm(aggregate_data)

# tilt glen?

# SQL Query to get current loss_counter
query_string <-'
    SELECT 
        * 
    FROM 
        daily_loss_counter;'

# return single value dataframe
counter <- dbGetQuery(pg_con, query_string)

print('retrieve loss counter from postgres db')

# glen daily losses
losses_today <- filter(daily_update, summoner_name == 'Phoenix MT')$losses

# if losses from daily_update greater than counter from postgres
# run tilt_glen python script to message discord 
# if (losses_today > counter$losses){
#     shell.exec("C:\\Users\\joemc\\Desktop\\Local Repos\\tilt_bot\\tilt_glen.bat")
# }

# update loss counter on postgres
loss_counter = as.data.frame(filter(daily_update, summoner_name == 'Phoenix MT')$losses)
colnames(loss_counter) = "losses"
dbWriteTable(pg_con, "daily_loss_counter", loss_counter, overwrite = TRUE)

print('updated loss counter on postgres db')

# update daily table on postgres
dbWriteTable(pg_con, "daily_update", daily_update, overwrite = TRUE)
print('updated daily table on postgres')

readline(prompt="Press [enter] to continue")
