# BTreadmill Workout Plan JSON Specification

This document describes the JSON format for creating custom workout plans for BTreadmill.

## File Location

Workout plans can be placed in two locations:

1. **Bundled Plans** (app defaults): `BTreadmill/Sample Workout Plans/` - included with the app
2. **User Plans** (custom): `~/Documents/BTreadmillData/plans/` - your custom plans

The app automatically loads plans from both locations on startup.

## Basic Structure

```json
{
  "id": "unique-plan-identifier",
  "name": "Plan Display Name",
  "description": "Optional description of the workout plan",
  "segments": [
    // Array of workout segments (see below)
  ],
  "globalSettings": {
    // Plan-wide settings (see below)  
  },
  "tags": ["tag1", "tag2", "tag3"]
}
```

## Plan Properties

### Required Fields

- **`id`** (string): Unique identifier for the plan. Use lowercase with hyphens.
- **`name`** (string): Display name shown in the app interface.
- **`segments`** (array): Array of workout segments that make up the plan.
- **`globalSettings`** (object): Plan-wide configuration settings.

### Optional Fields

- **`description`** (string): Description of the workout plan.
- **`tags`** (array of strings): Tags for categorization (e.g., "beginner", "hiit", "endurance").

## Segment Types

### Fixed Speed Segment

Maintains a constant speed for a specified duration.

```json
{
  "type": "fixed",
  "data": {
    "id": "segment-id",
    "name": "Segment Name",
    "speed": 3.5,
    "duration": 300,
    "transitionType": "gradual"
  }
}
```

**Properties:**
- **`id`** (string): Unique identifier for this segment
- **`name`** (string, optional): Display name for the segment
- **`speed`** (number): Target speed in km/h (1.0 - 6.0)
- **`duration`** (number): Duration in seconds
- **`transitionType`** (string): How to transition to this speed
  - `"immediate"`: Instant speed change
  - `"gradual"`: Smooth transition over 5-10 seconds

### Ramp Segment

Gradually changes speed from start to end over the duration.

```json
{
  "type": "ramp",
  "data": {
    "id": "ramp-segment",
    "name": "Hill Climb",
    "startSpeed": 2.0,
    "endSpeed": 5.0,
    "duration": 360,
    "rampType": "linear"
  }
}
```

**Properties:**
- **`id`** (string): Unique identifier for this segment
- **`name`** (string, optional): Display name for the segment
- **`startSpeed`** (number): Starting speed in km/h (1.0 - 6.0)
- **`endSpeed`** (number): Ending speed in km/h (1.0 - 6.0)
- **`duration`** (number): Duration in seconds
- **`rampType`** (string): Type of speed progression
  - `"linear"`: Constant rate of change
  - `"exponential"`: Slow start, fast finish
  - `"logarithmic"`: Fast start, slow finish
  - `"easeInOut"`: Slow start and end, fast middle

## Global Settings

```json
"globalSettings": {
  "maxDuration": null,
  "autoStopOnCompletion": true,
  "allowManualOverride": true,
  "pauseBehavior": "holdPosition",
  "warmupSpeed": null,
  "cooldownSpeed": null,
  "emergencyStopEnabled": true
}
```

**Properties:**
- **`maxDuration`** (number or null): Maximum plan duration in seconds (null = no limit)
- **`autoStopOnCompletion`** (boolean): Stop treadmill when plan completes
- **`allowManualOverride`** (boolean): Allow user to change speed during execution
- **`pauseBehavior`** (string): How pausing affects timing
  - `"holdPosition"`: Pause both timer and segment progression
  - `"continueTimer"`: Keep timer running, hold segment
  - `"resetSegment"`: Reset current segment when resumed
- **`warmupSpeed`** (number or null): Optional speed before plan starts
- **`cooldownSpeed`** (number or null): Optional speed after plan ends
- **`emergencyStopEnabled`** (boolean): Enable emergency stop functionality

## Complete Example

```json
{
  "id": "beginner-walk",
  "name": "Beginner Walk",
  "description": "A gentle 20-minute walk perfect for beginners",
  "segments": [
    {
      "type": "fixed",
      "data": {
        "id": "warmup",
        "name": "Warm-up",
        "speed": 1.5,
        "duration": 300,
        "transitionType": "immediate"
      }
    },
    {
      "type": "ramp",
      "data": {
        "id": "buildup",
        "name": "Build Up",
        "startSpeed": 1.5,
        "endSpeed": 3.0,
        "duration": 180,
        "rampType": "linear"
      }
    },
    {
      "type": "fixed",
      "data": {
        "id": "steady",
        "name": "Steady Walk",
        "speed": 3.0,
        "duration": 600,
        "transitionType": "immediate"
      }
    },
    {
      "type": "ramp",
      "data": {
        "id": "cooldown-ramp",
        "name": "Cool Down",
        "startSpeed": 3.0,
        "endSpeed": 1.5,
        "duration": 180,
        "rampType": "easeInOut"
      }
    },
    {
      "type": "fixed",
      "data": {
        "id": "final",
        "name": "Final Cool Down",
        "speed": 1.5,
        "duration": 120,
        "transitionType": "immediate"
      }
    }
  ],
  "globalSettings": {
    "maxDuration": null,
    "autoStopOnCompletion": true,
    "allowManualOverride": true,
    "pauseBehavior": "holdPosition",
    "warmupSpeed": null,
    "cooldownSpeed": null,
    "emergencyStopEnabled": true
  },
  "tags": ["beginner", "gentle", "20min"]
}
```

## Validation Rules

### Speed Limits
- All speeds must be between 1.0 and 6.0 km/h
- Speed changes should be reasonable for safety

### Duration Limits
- Minimum segment duration: 10 seconds
- Recommended maximum: 30 minutes per segment
- Recommended total plan duration: 5 minutes to 2 hours

### Segment IDs
- Must be unique within the plan
- Use lowercase letters, numbers, and hyphens
- No spaces or special characters

### Plan IDs
- Must be unique across all plans
- Use lowercase letters, numbers, and hyphens
- Descriptive and concise (e.g., "hiit-beginner", "endurance-long")

## Tips for Creating Plans

### Progressive Structure
1. **Warm-up**: Start with low speed (1.5-2.0 km/h) for 2-5 minutes
2. **Main workout**: Your primary training segments
3. **Cool-down**: End with low speed (1.5-2.0 km/h) for 2-5 minutes

### Speed Transitions
- Use `"gradual"` transitions between significantly different speeds
- Use `"immediate"` for small speed changes or same speeds
- Avoid abrupt changes > 2.0 km/h for safety

### Segment Naming
- Use descriptive names: "Warm-up", "Sprint", "Recovery", "Cool-down"
- Keep names short (< 20 characters) for UI display
- Be consistent across similar segments

### Testing
- Enable Simulator Mode in settings for faster testing
- Plans run 60x faster in simulator mode
- Start with short durations while testing

## File Management

### Adding Custom Plans
1. Create your JSON file following this specification
2. Save to `~/Documents/BTreadmillData/plans/yourplan.json`
3. Restart BTreadmill app
4. Your plan will appear in the workout plan dropdown

### Troubleshooting
- Check Console.app for validation errors
- Ensure JSON syntax is valid (use a JSON validator)
- Verify all required fields are present
- Check that speeds are within 1.0-6.0 km/h range

## Advanced Features (Future)

The following features are planned for future versions:

- **Interval Segments**: Repeating patterns of multiple speeds
- **Heart Rate Zones**: Speed based on target heart rate
- **User Variables**: Personalized speed recommendations
- **Plan Templates**: Reusable patterns for creating new plans
- **Import/Export**: Share plans between devices

For questions or examples, refer to the bundled sample plans in the app bundle.