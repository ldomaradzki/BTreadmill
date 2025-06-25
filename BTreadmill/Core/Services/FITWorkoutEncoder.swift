import Foundation
import FITSwiftSDK

class FITWorkoutEncoder {
    private var fitEncoder: Encoder
    private let workoutId: UUID
    private let startTime: Date
    private var isStarted = false
    private var isPaused = false
    private var totalPausedTime: TimeInterval = 0
    private var pauseStartTime: Date?
    
    init(workoutId: UUID, startTime: Date) {
        self.workoutId = workoutId
        self.startTime = startTime
        self.fitEncoder = Encoder()
        
        setupFileHeader()
    }
    
    private func setupFileHeader() {
        do {
            let fileIdMesg = FileIdMesg()
            try fileIdMesg.setType(.activity)
            try fileIdMesg.setManufacturer(.development)
            try fileIdMesg.setProduct(0)
            try fileIdMesg.setSerialNumber(UInt32(abs(workoutId.hashValue) % Int(UInt32.max)))
            try fileIdMesg.setTimeCreated(DateTime(date: startTime))
            
            fitEncoder.write(mesg: fileIdMesg)
        } catch {
            print("FIT header setup error: \(error)")
        }
    }
    
    func startWorkout() {
        guard !isStarted else { return }
        isStarted = true
    }
    
    func addRecord(speed: Double, distance: Double, steps: Int, timestamp: Date, gpsCoordinate: GPSCoordinate? = nil) {
        guard isStarted && !isPaused else { return }
        
        do {
            let recordMesg = RecordMesg()
            try recordMesg.setTimestamp(DateTime(date: timestamp))
            try recordMesg.setDistance(distance * 1000) // Convert km to meters
            try recordMesg.setSpeed(speed / 3.6) // Convert km/h to m/s
            
            // Add GPS coordinates if provided
            if let coordinate = gpsCoordinate {
                try recordMesg.setPositionLat(coordinate.latitude.semicircles)
                try recordMesg.setPositionLong(coordinate.longitude.semicircles)
                
                if let altitude = coordinate.altitude {
                    try recordMesg.setAltitude(altitude)
                }
            }
            
            fitEncoder.write(mesg: recordMesg)
        } catch {
            print("FIT add record error: \(error)")
        }
    }
    
    func pauseWorkout() {
        guard isStarted && !isPaused else { return }
        pauseStartTime = Date()
        isPaused = true
    }
    
    func resumeWorkout() {
        guard isStarted && isPaused, let pauseStart = pauseStartTime else { return }
        totalPausedTime += Date().timeIntervalSince(pauseStart)
        pauseStartTime = nil
        isPaused = false
    }
    
    func endWorkout(session: WorkoutSession) -> Data? {
        guard isStarted else { return nil }
        
        let endTime = session.endTime ?? Date()
        
        addSessionMessage(session: session, endTime: endTime)
        addActivityMessage(session: session, endTime: endTime)
        
        return fitEncoder.close()
    }
    
    private func addSessionMessage(session: WorkoutSession, endTime: Date) {
        do {
            let sessionMesg = SessionMesg()
            try sessionMesg.setMessageIndex(0)
            try sessionMesg.setTimestamp(DateTime(date: endTime))
            try sessionMesg.setStartTime(DateTime(date: startTime))
            try sessionMesg.setTotalElapsedTime(session.activeTime)
            try sessionMesg.setTotalTimerTime(session.activeTime)
            try sessionMesg.setTotalDistance(session.totalDistance * 1000) // Convert km to meters
            try sessionMesg.setSport(.running)
            try sessionMesg.setSubSport(.treadmill)
            try sessionMesg.setTotalStrides(UInt32(session.totalSteps))
            try sessionMesg.setTotalCalories(UInt16(session.estimatedCalories))
            try sessionMesg.setAvgSpeed(session.averageSpeed / 3.6) // Convert km/h to m/s
            try sessionMesg.setMaxSpeed(session.maxSpeed / 3.6)
            
            fitEncoder.write(mesg: sessionMesg)
        } catch {
            print("FIT session message error: \(error)")
        }
    }
    
    private func addActivityMessage(session: WorkoutSession, endTime: Date) {
        do {
            let activityMesg = ActivityMesg()
            try activityMesg.setTimestamp(DateTime(date: endTime))
            try activityMesg.setTotalTimerTime(session.activeTime)
            try activityMesg.setLocalTimestamp(UInt32(endTime.timeIntervalSince1970))
            try activityMesg.setNumSessions(1)
            
            fitEncoder.write(mesg: activityMesg)
        } catch {
            print("FIT activity message error: \(error)")
        }
    }
}