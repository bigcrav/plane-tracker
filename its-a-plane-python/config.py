ZONE_HOME = {
    "tl_y": 39.546412, # Top-Left Latitude (deg) https://www.latlong.net/ or google maps. The bigger the zone, the more planes you'll get. My zone is ~3.5 miles in each direction or 10mi corner to corner. 
    "tl_x": -81.753104, # Top-Left Longitude (deg)
    "br_y": 39.087436, # Bottom-Right Latitude (deg)
    "br_x":  -81.231670# Bottom-Right Longitude (deg)
}
LOCATION_HOME = [
    39.266743, # Latitude (deg)
    -81.561516 # Longitude (deg)
]
TEMPERATURE_LOCATION = "39.26673,-81.561516" #same as location home
TOMORROW_API_KEY = "qQD5odEQgqb3ws9gBuTzowpSwneV7V1y" # Get an API key from https://tomorrow.io they only allows 25 pulls an hour, if you reach the limit you'll need to wait until the next hour 
TEMPERATURE_UNITS = "imperial" #can use "metric" if you want, same for distance 
DISTANCE_UNITS = "imperial"
CLOCK_FORMAT = "12hr" #use 12hr or 24hr
MIN_ALTITUDE = 2000 #feet above sea level. If you live at 1000ft then you'd want to make yours ~3000 etc. I use 2000 to weed out some of the smaller general aviation traffic. 
BRIGHTNESS = 100
BRIGHTNESS_NIGHT = 50
NIGHT_BRIGHTNESS = False #True for on False for off
NIGHT_START = "22:00" #dims screen between these hours
NIGHT_END = "06:00"
GPIO_SLOWDOWN = 2 #depends what Pi you have I use 2 for Pi 3 and 1 for Pi Zero
JOURNEY_CODE_SELECTED = "PKB" #your home airport code
JOURNEY_BLANK_FILLER = " ? " #what to display if theres no airport code
HAT_PWM_ENABLED = False #only if you haven't soldered the PWM bridge use True if you did
FORECAST_DAYS = 3 #today plus the next two days
EMAIL = "colby@ccraven.dev" #insert your email address between the " ie "example@example.com" to recieve emails when there is a new closest flight on the tracker. Leave "" to recieve no emails. It will log/local webpage regardless
MAX_FARTHEST = 3 #the amount of furthest flights you want in your log
MAX_CLOSEST = 3 #the amount of closest flights to your house you want in your log
