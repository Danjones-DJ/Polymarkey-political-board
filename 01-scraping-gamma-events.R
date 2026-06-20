# 00: Load packages -------------------------------------------------------
pacman::p_load(httr2, jsonlite, tidyverse, lubridate, purrr, glue)
options(scipen=999)


# 01: Set up API Endpoint for GAMMA ---------------------------------------

# First for Polymarket is "GAMMA"
gamma_base = "https://gamma-api.polymarket.com"


# 02: Make Initial Request ------------------------------------------------

# Make initial request
req = request(gamma_base) %>%
  req_url_path_append("events") %>%
  req_url_query(
    active = "true",
    closed = "false",
    limit = 500 # As many as possible pls 
  )

# Perform
resp = req_perform(req)
resp_status(resp) # 200 = OKAY


# 03: Turn response into an R Object --------------------------------------
# Data will be very messy and nested
events = resp_body_json(resp, simplifyVector = FALSE)

# Noticed that a lot of events were not accepting orders -> thus these should be filtered

# For each event in events, only keep it if it's currently accepting orders
events = map(events, function(event) {
  event$markets = keep(event$markets, ~ isTRUE(.x$acceptingOrders))
})

# 04: Explore data and choose features ------------------------------------

# Inspect key aspects
m <- events[[1]][[1]]
# m
# ...


# 05: Turn messy data into a nicely structured df -------------------------

events_dataframe = map_dfr(events, function(event)  {
  
  row = tibble(
    event_id = event[[1]]$id,
    start_date = as.Date(event[[1]]$startDate), 
    end_date = as.Date(event[[1]]$endDate),
    
    question = event[[1]]$question,
    description = event[[1]]$description,
    
    slug = event[[1]]$slug,
    
    outcomes = event[[1]]$outcomes, # Will be cleaned later
    outcome_prices = event[[1]]$outcomePrices, # Will be cleaned later
    last_traded_price = event[[1]]$lastTradePrice,
    
    liquidity = as.numeric(event[[1]]$liquidity),
    volume = as.numeric(event[[1]]$volume),
    volume_day = event[[1]]$volume24hr,
    volume_week = event[[1]]$volume1wk,
    volume_month = event[[1]]$volume1mo,
    price_change_day = event[[1]]$oneDayPriceChange,
    price_change_week = event[[1]]$oneWeekPriceChange,
    price_change_month = event[[1]]$oneMonthPriceChange
  )
})

# Inspect
events_dataframe %>% skimr::skim()

# All looks good! Few NA Values that will be handled later

# 06: Filter and refine data ----------------------------------------------

events_clean = events_dataframe %>% 
  filter(volume > 100000) %>% # Only give me markets with > $100,000 volume traded
  mutate(days_since = as.numeric(Sys.Date() - start_date)) %>% # How long has this been open?
  arrange(days_since) 

# skimr::skim(events_clean) # No important NAs following filtering

# Final cleaning - turn messy aspects into something useful
EVENTS = events_clean %>% 
  mutate(
    # Turn messy text into list
    outcome_list = map(outcomes, fromJSON),
    price_list = map(outcome_prices, fromJSON),
    
    # List outcomes
    outcome_1 = str_squish(map_chr(outcome_list, 1)),
    outcome_2 = str_squish(map_chr(outcome_list, 2)),
    
    # List prices
    price_1 = as.numeric(map_chr(price_list, 1)),
    price_2 = as.numeric(map_chr(price_list, 2)),
    
    # Summary var
    predicted_outcome = ifelse(
      price_1 > price_2, 
      outcome_1,
      outcome_2
    ),
    
    # State the outcome in context
    predicted_outcome_statement = ifelse(
      price_1 > price_2, 
      glue("{question}: {outcome_1} (~{price_1 * 100}%)"),
      glue("{question}: {outcome_2} (~{price_2 * 100}%)")
      ),
    
    # How far above 50% confidence?
    confidence_margin = ifelse(
      price_1 > price_2,
      price_1 - 0.5,
      price_2 - 0.5
    ),
    SCRAPING_DATE = Sys.Date()
    
    ) %>%
  select(-outcomes, -outcome_prices)


# 07: Save! ---------------------------------------------------------------
saveRDS(EVENTS, "data/EVENTS.rds")



