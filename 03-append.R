pacman::p_load(googlesheets4, tidyverse, lubridate, glue)

writeLines(
  Sys.getenv("GSHEET_AUTH_JSON"),
  "service-account.json"
)

gs4_auth(path = "service-account.json")

# Sheet
SHEET_URL <- "https://docs.google.com/spreadsheets/d/18dYy80i2ddaB5KhU6Qgog8fh6nStsRvhf9qK6KKqWCg/edit?gid=2061874730#gid=2061874730"

# Load new and old data to work with
new_data = read_rds("data/EVENTS.rds")
old_data = read_sheet(ss = SHEET_URL, sheet = "eventdata") 

# Update dataset with new data appending, update dates
updated_data = bind_rows(old_data, new_data)

# Write sheet
sheet_write(data = updated_data, ss = SHEET_URL, sheet="eventdata")

