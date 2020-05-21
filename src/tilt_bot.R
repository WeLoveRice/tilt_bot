# tilt_bot, manage API calls, update DB, create leaderboard image.

# install Packages
if (!require("pacman")) install.packages("pacman")
pacman::p_load(tictoc,RPostgres, jsonlite, curl, data.table, dplyr, lubridate,formattable,htmltools,webshot, textutils)

# source functions script
source("tilt_bot_functions.R")

# read variables from .env
read.env()

counter = 0

print("starting loop, update postgres if there are changes to the data")

# infinite loop, waits added throughout to comply with API rate limit
while (1==1){

	if(counter>0){print("restarting loop")}

	# read variables from .env in case new user added
	read.env()

    # loop through each summoner on EU list updating database with info
    for (summoner in eu_summoners){

        riot_api_call(summoner, riot_api_key, eu_url)
    }

    # loop through each summoner on NA list updating database with info
    for (summoner in na_summoners){

        riot_api_call(summoner, riot_api_key, na_url)
    }

    # if current_data variable exists, use rbind to combine with summoner_data
    if (exists("existing_data")){

        if(!isTRUE(all.equal(existing_data[,-18],current_data[,-18]))){

            update_data()

        }        
    }else{

    	update_data()
    }
   	
    if (counter%%5==0){
    	cat("\014")
    }


	counter = counter + 1
    print(paste0(counter, " updates from API."))

    existing_data <- current_data
    rm(current_data)
    
    Sys.sleep(90)

}