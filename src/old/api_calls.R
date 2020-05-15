# Install Packages
if (!require("pacman")) install.packages("pacman")
pacman::p_load(RPostgres, jsonlite, curl, data.table, dplyr)

# LOOP START - grab data from API verify against previous info



# import variables from .env
dotenv_df <- read.table(file=paste0(".env"),
                        header=FALSE,
                        sep='=',
                        col.names=c('Key','Value'),
                        stringsAsFactors = FALSE,
                        encoding="UTF-8")

dotenv_dt <- data.table(dotenv_df, key="Key")

print('credentials read from .env file')

# user-specified variables
riot_api_key <- dotenv_dt['riot_api']$Value
eu_summoners <- as.list(strsplit(dotenv_dt['eu_summoners']$Value, ",")[[1]])
na_summoners <- as.list(strsplit(dotenv_dt['na_summoners']$Value, ",")[[1]])
rm(dotenv_df,dotenv_dt)

eu_url <- "https://euw1.api.riotgames.com"
na_url <- "https://na1.api.riotgames.com"

# function to update database given summoner_name and api_key
update_summoner_data <- function(summoner_name, api_key, region_url){
    
    # url address for api call to get summoner_id from summoner_name
    url_address <- paste0(
        region_url,
        "/lol/summoner/v4/summoners/by-name/",
        summoner_name,
        "?api_key=",
        api_key)

    # import api response as dataframe, creating summoner_id
    summoner_name_data <- fromJSON(url_address)
    summoner_id <- summoner_name_data$id
    rm(summoner_name_data)

    # url address for api call to get summoner_data using summoner_id
    url_address <- paste0(
        region_url,
        "/lol/league/v4/entries/by-summoner/",
        summoner_id,
        "?api_key=",
        api_key)
    
    # import api repsonse as dataframe summoner_data
    ranked_data <- fromJSON(url_address, simplifyVector = TRUE, simplifyDataFrame = TRUE)
    
    # url address for api call to get summoner_data using summoner_id
    url_address <- paste0(
        region_url,
        "/tft/league/v1/entries/by-summoner/",
        summoner_id,
        "?api_key=",
        api_key)
    
    # import api repsonse as dataframe summoner_data
    tft_data <- fromJSON(url_address, simplifyVector = TRUE, simplifyDataFrame = TRUE)
    
    if(length(ranked_data)+length(tft_data) > 0){
        
        summoner_data <- rbind(ranked_data, tft_data)
    
        # add date / time columns - had issues using POSIXct on postgres, update in future
        summoner_data$timestamp <- as.POSIXct(Sys.time())
    
        # if current_data variable exists, use rbind to combine with summoner_data
        if (exists("current_data")){
            current_data <- rbind(current_data, summoner_data)
        # else create daily_update from update_data
        } else{ current_data <- summoner_data }

    }
    
    Sys.sleep(2)
    
    # clean up
    suppressWarnings(rm(ranked_data, tft_data, summoner_data))
}# end of update_summoner_data() function

print("infinite loop for API calls")

while (1 == 1){
    # loop through each summoner on EU list updating database with info
    for (summoner in eu_summoners){
        update_summoner_data(summoner, riot_api_key, eu_url)
    }

    # loop through each summoner on NA list updating database with info
    for (summoner in na_summoners){
        update_summoner_data(summoner, riot_api_key, na_url)
    }

    # if current_data variable exists, use rbind to combine with summoner_data
    if (exists("existing_data")){
        if(!all.equal(existing_data,current_data)){
            print("running ranked_update, data has changed")
            source("ranked_update.R")
        }
        
        existing_data <- current_data

        stop()
    }

    Sys.sleep(30)

}


