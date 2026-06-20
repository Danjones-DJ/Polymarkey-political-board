pacman::p_load(googlesheets4, googledrive, tidyverse)

df = read_rds("data/EVENTS.rds")

gs4_auth()

spreadsheet = gs4_create(
  name = "polymarket-data",
  sheets = list(eventdata = df)
)

spreadsheet