//
//  PWTimeKeys.h
//  PebbleWorldTime
//
//  Created by Don Krause on 6/3/13.
//  Copyright (c) 2013 Don Krause. All rights reserved.
//

#ifndef PebbleWorldTime_PWTimeKeys_h
#define PebbleWorldTime_PWTimeKeys_h

// Factors, the keys are actually grouped by 16, depending on the watch to update
// Add these to the KEYs to get the actual value
#define LOCAL_WATCH_OFFSET                  0x00
#define WATCH_1_OFFSET                      0x10
#define WATCH_2_OFFSET                      0x20

// Keys for local time data, maximum of 16, including 0x00
#define PBCOMM_WATCH_ENABLED_KEY            0x01    // boolean
#define PBCOMM_GMT_SEC_OFFSET_KEY           0x02    // number of seconds before or after GMT
#define PBCOMM_CITY_KEY                     0x03    // string with city name and GMT offset
#define PBCOMM_BACKGROUND_KEY               0x04    // light, dark or AM/PM background
#define PBCOMM_12_24_DISPLAY_KEY            0x05    // display in watch configured-, 12- or 24-hour time
#define PBCOMM_WEATHER_KEY                  0x06    // weather conditions

// Values for PBCOMM_WATCH_ENABLED_KEY
#define WATCH_DISABLED						0x00
#define WATCH_ENABLED						0x01

// Values for PBCOMMM_BACKGROUND_KEY
#define BACKGROUND_DARK                     0x00    // Dark background
#define BACKGROUND_LIGHT                    0x01    // Light background
#define BACKGROUND_AM_PM                    0x02    // Light for AM, dark for PM

// Values for PBCOMM_12_24_DISPLAY_KEY
#define DISPLAY_WATCH_CONFIG_TIME           0x00    // Show 12- or 24-hour time as configured on watch
#define DISPLAY_12_HOUR_TIME                0x01    // Show 12-hour time
#define DISPLAY_24_HOUR_TIME                0x02    // Show 24-hour time

// Values for PBCOMM_WEATHER_KEY
#define WEATHER_UNKNOWN                     0x00    // Weather unknown
#define WEATHER_SUNNY                       0x01    // Weather sunny
#define WEATHER_CLOUDY                      0x02    // Weather cloudy
#define WEATHER_RAINY                       0x03    // Weather rainy
#define MAX_WEATHER_CONDITIONS              0x04    // Number of weather conditions

#endif
