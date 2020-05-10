# Install Packages
if (!require("pacman")) install.packages("pacman")
pacman::p_load(RPostgres, jsonlite, curl, data.table, dplyr, lubridate,formattable,htmltools,webshot)

# import variables from .env
dotenv_df <- read.table(file=paste0(".env"),
                        header=FALSE,
                        sep='=',
                        col.names=c('Key','Value'),
                        stringsAsFactors = FALSE,
                        encoding="UTF-8")

dotenv_dt <- data.table(dotenv_df, key="Key")

print('credentials read from .env file')

lp_table <- data.frame(
    row.names = c("I","II","III","IV"),
    "BRONZE" = seq(300,0,-100),
    "SILVER" = seq(700,400,-100),
    "GOLD" = seq(1100,800,-100),
    "PLATINUM" = seq(1500,1200,-100),
    "DIAMOND" = seq(1900,1600,-100)
)

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
        
        max_queue_data <- filter(queue_data, timestamp == max(timestamp))
        min_queue_data <- filter(queue_data, timestamp == min(timestamp))

        # create dataframe for daily_update table
        update_data <- data.frame(
            summoner_name = summoner,
            queue = queue,
            wins = max_queue_data$wins - min_queue_data$wins,
            losses = max_queue_data$losses - min_queue_data$losses,          
            LP_change = lp_table[max_queue_data$rank,max_queue_data$tier] + 
                max_queue_data$leaguePoints -
                lp_table[min_queue_data$rank,min_queue_data$tier] -
                min_queue_data$leaguePoints,
            tier = max_queue_data$tier,
            rank = max_queue_data$rank,
            current_LP = max_queue_data$leaguePoints
        )
        
        # if daily_update variable exists, use rbind to combine with update_data
        if (exists("daily_table")){
            daily_table <- rbind(daily_table, update_data)
        # else create daily_update from update_data
        } else{ daily_table <- update_data }
        
    }# end of for loop
}# end of for loop 

rm(aggregate_data,summoner_data,queue_data,lp_table,summoner,queue,max_queue_data,min_queue_data,update_data)

raw_daily <- daily_table

daily_table <- filter(daily_table, wins + losses > 0)

print('daily table created')

# update daily table on postgres
dbWriteTable(pg_con, "daily_table", daily_table, overwrite = TRUE)
print('updated daily table on postgres')
dbDisconnect(pg_con)

output_table = data.frame(
    'Summoner' = daily_table$summoner_name,
    'Queue' = gsub("RANKED_", "", daily_table$queue),
    'Wins' = daily_table$wins,
    'Losses' = daily_table$losses,
    'LP' = daily_table$LP_change,
    'Change' = daily_table$LP_change
)

output_table <- output_table %>% arrange(desc(LP))

output_table <- formattable(
    output_table,
    align = c("l","l","r","r","r","l"),
    list(
        LP.Change = formatter("span", 
                              style = x ~ style(color = ifelse(x > 0, "green", "red"))),
        'Change' = formatter("span", 
                             style = x ~ style(color = ifelse(x > 0, "green", "red")),                                    
                             x ~ icontext(ifelse(x < 0,"arrow-down","arrow-up")))
    )
)

export_formattable <- function(f, file, width = "100%", height = NULL, 
                               background = "white", delay = 0.2)
{
    w <- as.htmlwidget(f, width = "50%", height = height)
    path <- html_print(w, background = background, viewer = NULL)
    url <- paste0("file:///", gsub("\\\\", "/", normalizePath(path)))
    webshot(url,
            file = file,
            selector = ".formattable_widget",
            delay = delay)
}

if(length(output_table$Summoner) == 0){
    if(file.exists("leaderboard.png")){
        file.remove("leaderboard.png")
    }
} else {
    export_formattable(output_table, "leaderboard.png") 
}

rm(pg_con,output_table,daily_table,raw_daily,query_string)