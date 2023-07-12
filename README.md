# BTreadmill
Treadmill MacOS application to control ACGAM treadmills (via bluetooth). Tested only on ACGAM T02P, but I think it would also work ACGAM B1-402. 
Application is fully written in Swift, SwiftUI and backed by SQlite (GRDB).
BTreadmill can read values (distance, speed etc) from ACGAM treadmill via bluetooth and send commands to start/stop and change speed.
Every workout can be shared to Strava - on first upload it will ask to log in via built-in browser and using it's API will upload the run as Virtual Run.

# Screenshots
![Screenshot of BTreadmill app 1](/Screenshots/BTreadmill01.png?raw=true)
![Screenshot of BTreadmill app 2](/Screenshots/BTreadmill02.png?raw=true)

# Troubleshooting
1. If app cannot find Treadmill, turn bluetooth off and on in MacOS. If you have been using iOS app to control this treadmill recently, you have to disable bluetooth on your iPhone to "disconnect" treadmill with your iPhone
2. If app tells you that treadmill is hibernated, you have to click on your physical controller that came with your treadmill and wake it up.