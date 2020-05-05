## get latest ver of R
FROM rocker/r-base:latest

## Copy files
COPY C:/Users/joemc/Desktop/Local Repos/tilt_bot/* /tilt_bot/

## Install R packages
RUN install2.r --error \
    RPostgres \
    jsonlite \
    curl \
    data.table \
    dplyr 

## Execute R Script
CMD Rscript /tilt_bot/ranked_update.tilt_bot