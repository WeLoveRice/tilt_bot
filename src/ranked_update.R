# Install Packages
if (!require("pacman")) install.packages("pacman")
pacman::p_load(RPostgres, jsonlite, curl, data.table, dplyr)

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

# user-specified variables
riot_api_key <- dotenv_dt['riot_api']$Value
summoners_list <- as.list(strsplit(dotenv_dt['list_summoners']$Value, ",")[[1]])
rm(dotenv_df,dotenv_dt)


# create connection to postgres
pg_con <- dbConnect(Postgres(),
                 user = pg_user,
                 password = pg_pw,
                 host = pg_ip,
                 dbname = pg_db,
                 bigint = "numeric")

print('postgres connection created')

# function to update database given summoner_name and api_key
update_summoner_data <- function(summoner_name, api_key){
    
    # url address for api call to get summoner_id from summoner_name
    url_address <- paste0(
        "https://euw1.api.riotgames.com/lol/summoner/v4/summoners/by-name/",
        summoner_name,
        "?api_key=",
        api_key)

    # import api response as dataframe, creating summoner_id
    summoner_name_data <- fromJSON(url_address)
    summoner_id <- summoner_name_data$id
    rm(summoner_name_data)

    # url address for api call to get summoner_data using summoner_id
    url_address <- paste0(
        "https://euw1.api.riotgames.com/lol/league/v4/entries/by-summoner/",
        summoner_id,
        "?api_key=",
        api_key)
    
    # import api repsonse as dataframe summoner_data
    ranked_data <- fromJSON(url_address, simplifyVector = TRUE, simplifyDataFrame = TRUE)
    
    # url address for api call to get summoner_data using summoner_id
    url_address <- paste0(
        "https://euw1.api.riotgames.com/tft/league/v1/entries/by-summoner/",
        summoner_id,
        "?api_key=",
        api_key)
    
    # import api repsonse as dataframe summoner_data
    tft_data <- fromJSON(url_address, simplifyVector = TRUE, simplifyDataFrame = TRUE)
    
    summoner_data <- rbind(ranked_data, tft_data)

    # add date / time columns - had issues using POSIXct on postgres, update in future
    summoner_data$timestamp <- as.POSIXct(Sys.time())

    # append entry to ranked_data table on postgres
    dbWriteTable(pg_con, "raw_data", summoner_data, append = TRUE)
    
    # clean up
    rm(ranked_data, tft_data, summoner_data)
}# end of update_summoner_data() function

# loop through each summoner on list updating database with info
for (summoner in summoners_list){
    update_summoner_data(summoner, riot_api_key)
}

print('data pulled from Riot API and pushed to postgres db')

# disconnect postgres connection
dbDisconnect(pg_con)

print('completed update')
