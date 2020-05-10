## get latest ver of R
FROM rocker/r-ver:3.6.3

## Copy files
COPY install_packages.R ./ \
	 ranked_update.R ./ \
	 .env ./

## Install dependencies for RPostgres / curl
RUN apt-get update && apt-get install -y \
	python3.6 \
	libpq-dev \
	zlib1g-dev \
	libcurl4-openssl-dev

## Install R packages
RUN Rscript install_packages.R \
	&& python -m pip install psycopg2 \
	discord.py \
	dotenv

## Execute R Script
CMD Rscript ranked_update.R \
	&& Rscript pipeline_data.R