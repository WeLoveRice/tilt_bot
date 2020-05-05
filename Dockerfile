## get latest ver of R
FROM rocker/r-base:latest

## Copy files
COPY /ranked_update.R \
	 /.env

## Install R packages
RUN install2.r --error \
    RPostgres \
    jsonlite \
    curl \
    data.table \
    dplyr 

## Execute R Script
CMD Rscript ranked_update.R