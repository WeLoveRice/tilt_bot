# Read .env file
read.env <- function(){

    # import variables from .env
    dotenv_df <- read.table(file=paste0(".env"),
                            header=FALSE,
                            sep='=',
                            col.names=c('Key','Value'),
                            stringsAsFactors = FALSE,
                            encoding="UTF-8")

    dotenv_dt <- data.table(dotenv_df, key="Key")

    # set postgres details from .env variables
    pg_user <<- dotenv_dt['pg_user']$Value
    pg_pw <<- dotenv_dt['pg_pw']$Value
    pg_ip <<- dotenv_dt['pg_ip']$Value
    pg_db <<- dotenv_dt['pg_db']$Value

    # user-specified variables
    riot_api_key <<- dotenv_dt['riot_api']$Value
    eu_summoners <<- as.list(strsplit(dotenv_dt['eu_summoners']$Value, ",")[[1]])
    na_summoners <<- as.list(strsplit(dotenv_dt['na_summoners']$Value, ",")[[1]])

    # regional urls
    eu_url <<- dotenv_dt['eu_url']$Value
    na_url <<- dotenv_dt['na_url']$Value

    # create pg_con
    pg_connection()
}

pg_connection <- function(){
    # create connection to postgres
    pg_con <<- dbConnect(
        Postgres(),
        user = pg_user,
        password = pg_pw,
        host = pg_ip,
        dbname = pg_db,
        bigint = "numeric")
}

# API Call, adds current summoner info to aggregated dataframe
riot_api_call <- function(summoner_name, api_key, region_url){
    
    # url address for api call to get summoner_id from summoner_name
    url_address <- paste0(
        region_url,
        "/lol/summoner/v4/summoners/by-name/",
        summoner_name,
        "?api_key=",
        api_key)

    Sys.sleep(5)  

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

    Sys.sleep(5)   

    # import api repsonse as dataframe summoner_data
    ranked_data <- fromJSON(url_address, simplifyVector = TRUE, simplifyDataFrame = TRUE)

    # url address for api call to get summoner_data using summoner_id
    url_address <- paste0(
        region_url,
        "/tft/league/v1/entries/by-summoner/",
        summoner_id,
        "?api_key=",
        api_key)

    Sys.sleep(5)     
    
    # import api repsonse as dataframe summoner_data
    tft_data <- fromJSON(url_address, simplifyVector = TRUE, simplifyDataFrame = TRUE)
    
    if(length(ranked_data)+length(tft_data) > 0){

        if(length(ranked_data)==14){
            ranked_data <- flatten(ranked_data)
        }

        if(length(ranked_data)==13){
            ranked_data$miniSeries.target <- NA
            ranked_data$miniSeries.wins <- NA
            ranked_data$miniSeries.losses <- NA
            ranked_data$miniSeries.progress <- NA
        }

        if(length(tft_data)==13){
            tft_data$miniSeries.target <- NA
            tft_data$miniSeries.wins <- NA
            tft_data$miniSeries.losses <- NA
            tft_data$miniSeries.progress <- NA
        }
        
        summoner_data <- rbind(ranked_data, tft_data)
    
        # add date / time columns - had issues using POSIXct on postgres, update in future
        summoner_data$timestamp <- as.POSIXct(Sys.time())

        # if current_data variable exists, use rbind to combine with summoner_data
        if (exists("current_data")){
            current_data <<- rbind(current_data, summoner_data)
        # else create daily_update from update_data
        } else{ current_data <<- summoner_data }

    }
    
    # clean up
    suppressWarnings(rm(ranked_data, tft_data, summoner_data))
}# end of update_summoner_data() function

pg_append_raw <- function(dataframe){

    # append entry to raw_data table
    dbWriteTable(pg_con, "raw_data", dataframe, append = TRUE)

    # remove duplicate entries from table
    query_string <- '
    DELETE
    FROM
        raw_data a
        USING 
            raw_data b
    WHERE
        a.timestamp < b.timestamp 
        AND a."queueType" = b."queueType"
        AND a.tier = b.tier
        AND a.rank = b.rank
        AND a."summonerName" = b."summonerName"
        AND a.wins = b.wins
        AND a.losses = b.losses
        AND a.timestamp >= CURRENT_DATE
        AND b.timestamp >= CURRENT_DATE;'

    dbSendQuery(pg_con, query_string)

}

create_daily_table <- function(){

    if(exists("daily_table")){rm(daily_table, envir=globalenv())}

    lp_table <- data.frame(
        row.names = c("I","II","III","IV"),
        "IRON"= seq(-100,-400, -100),
        "BRONZE" = seq(300,0,-100),
        "SILVER" = seq(700,400,-100),
        "GOLD" = seq(1100,800,-100),
        "PLATINUM" = seq(1500,1200,-100),
        "DIAMOND" = seq(1900,1600,-100)
    )

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

    daily_table <<- filter(daily_table, wins + losses > 0)
}

tilt_glen <- function(){

    loss_count <- sum(filter(daily_table, summoner_name=='Phoenix MT' | summoner_name=='Kawaii Hentai')$losses)
    loss_count_df <- as.data.frame(loss_count)   
    colnames(loss_count_df) <- "glen_daily_losses"

    query_string <- 'SELECT * FROM daily_loss_counter;'

    old_loss_count <- dbGetQuery(pg_con, query_string)[1,1]

    if(loss_count > old_loss_count){

        system("python tilt_glen.py")

    }

    dbWriteTable(pg_con, "daily_loss_counter", loss_count_df, overwrite = TRUE)
}

pg_overwrite_daily <- function(){

    # update daily table
    dbWriteTable(pg_con, "daily_table", daily_table, overwrite = TRUE)

}

create_leaderboard.png <- function(){
    output_table = data.frame(
    'Summoner' = HTMLencode(daily_table$summoner_name),
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
                                 x ~ icontext(ifelse(x < 0,"arrow-down",ifelse(x > 0,"arrow-up",""))))
        )
    )
    if(length(output_table$Summoner) == 0){
        if(file.exists("leaderboard.png")){
            file.remove("leaderboard.png")
        }
    } else {
        export_formattable(output_table, "leaderboard.png") 
    }    
}

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

update_data <- function(){
    # add new data to db, remove duplicates
    pg_append_raw(current_data)

    # create daily_table
    create_daily_table()

    # tilt glen
    tilt_glen()

    # overwrite daily_table on db with new info
    pg_overwrite_daily()

    # create leaderboard.png
    create_leaderboard.png()
}