# USM Anti-Cheat Documentation

## Overview

Universal Security Module (USM) v2026.2 is an advanced server-side anti-exploit framework for Roblox developers. This modular system provides comprehensive protection against common exploits while remaining easy to implement and customize.

## Installation

### Quick Start (Simple)

1. Download `usm-v2026.2.lua`
2. Place in `ServerScriptService`
3. Rename to `USM_AntiExploit.server.lua`
4. Done!

### Advanced Setup (Recommended)

1. Download all USM modules from the downloads folder
2. Place in `ServerScriptService`:
   - `USM_Configuration.lua`
   - `USM_Main_AntiCheat.lua`
   - `USM_Movement_Validator.lua`
   - `USM_Remote_Protection.lua`
3. Place `USM_Client_Validator.lua` in `StarterPlayerScripts`
4. Customize `USM_Configuration.lua` for your game

## Module Descriptions

### USM_Configuration.lua
**Purpose:** Centralized configuration for all USM modules

**Key Settings:**
- Punishment thresholds (kick/ban scores)
- Movement validation parameters
- Remote event protection settings
- Whitelist system
- Grace periods
- Logging configuration

**Customization:** Edit the values in the returned table to adjust behavior for your game.

### USM_Main_AntiCheat.lua
**Purpose:** Main anti-cheat engine with suspicion scoring and BanAsync integration

**Features:**
- Suspicion scoring system (0-100)
- Automatic punishment escalation
- Universe-wide banning via BanAsync
- Grace period management
- Behavioral analysis
- DataStore logging

**Best Practices:**
- Adjust thresholds in configuration before deployment
- Test with whitelist enabled first
- Monitor logs for false positives
- Use suspicion scoring rather than immediate bans

### USM_Movement_Validator.lua
**Purpose:** Specialized movement validation with advanced physics analysis

**Features:**
- Trajectory prediction
- Acceleration analysis
- Ground detection
- Speed validation
- Teleportation detection
- Jump validation
- Pattern recognition

**Use Cases:**
- Parkour games
- PvP games
- Racing games
- Any game with movement mechanics

### USM_Remote_Protection.lua
**Purpose:** Remote event protection with rate limiting and argument validation

**Features:**
- Automatic remote protection
- Rate limiting per player
- Blacklisted pattern detection
- Argument size validation
- Call history tracking
- Custom blacklist patterns

**Best Practices:**
- Add game-specific patterns to blacklist
- Monitor call statistics
- Adjust rate limits based on game needs

### USM_Client_Validator.lua
**Purpose:** Client-side data collection for server verification

**Features:**
- Position/velocity reporting
- Input device detection
- Session tracking
- Camera data collection

**Important:** This script does NOT make security decisions on the client. All validation happens server-side.

## Configuration Guide

### Punishment System

```lua
Punishment = {
    KickThreshold = 80,      -- Suspicion score to kick
    BanThreshold = 95,      -- Suspicion score to ban
    ScoreDecayRate = 0.5,   -- Points lost per second
    CooldownBetweenPunishments = 30,  -- Seconds
    UseBanAsync = true,     -- Use universe-wide bans
    BanDuration = 604800,   -- 7 days (nil = permanent)
}
```

### Movement Validation

```lua
Movement = {
    MaxSpeedMultiplier = 2.5,      -- Multiplier of WalkSpeed
    MaxTeleportDistance = 50,       -- Studs
    MaxAirTime = 3.0,              -- Seconds in air
    MaxJumpHeight = 50,            -- Studs
    MaxAcceleration = 100,          -- Studs/second²
}
```

### Remote Events

```lua
RemoteEvents = {
    MaxCallsPerSecond = 20,
    RateLimitWindow = 1.0,
    MaxArgumentSize = 1000,
    BlacklistedPatterns = {
        "require",
        "getfenv",
        "setfenv",
        "loadstring",
    },
}
```

### Whitelist System

```lua
Whitelist = {
    Enabled = false,
    UserIds = {12345678, 87654321},  -- Whitelisted user IDs
    GroupIds = {1234567},            -- Whitelisted group IDs
    GamePassIds = {123456789},       -- Whitelisted game passes
}
```

## Best Practices

### 1. Never Trust the Client
All security decisions must be made server-side. The client validator is only for data collection.

### 2. Use Suspicion Scoring
Don't auto-ban for single detections. Build up evidence over time using the suspicion scoring system.

### 3. Implement Grace Periods
Allow time for legitimate game mechanics (teleports, respawns, etc.) before checking.

### 4. Test Thoroughly
- Test with whitelist enabled first
- Monitor logs for false positives
- Adjust thresholds based on your game's mechanics
- Have team members test with various network conditions

### 5. Monitor and Adjust
- Review detection logs regularly
- Adjust thresholds based on real gameplay
- Update blacklist patterns as new exploits emerge
- Keep scripts updated with latest USM releases

### 6. Handle Appeals
- Provide a way for players to appeal bans
- Review suspicious cases manually
- Consider softer punishments (kick) for uncertain cases

## Common Issues

### False Positives on Speed Checks
**Solution:** Increase `MaxSpeedMultiplier` or add grace periods for specific game mechanics.

### Legitimate Teleports Flagged
**Solution:** Use `SetGracePeriod(player, "teleport", duration)` after scripted teleports.

### Remote Events Blocked
**Solution:** Add legitimate patterns to whitelist or adjust `MaxCallsPerSecond`.

### High Server Load
**Solution:** Increase detection intervals or disable non-essential modules.

## API Reference

### Main Anti-Cheat

```lua
-- Manually add suspicion
AddSuspicion(player, amount, reason)

-- Set grace period
SetGracePeriod(player, graceType, duration)

-- Check if whitelisted
IsWhitelisted(player)
```

### Movement Validator

```lua
-- Initialize for player
MovementValidator.Initialize(player)

-- Validate movement
local anomalies = MovementValidator.Validate(player)

-- Check if grounded
local grounded = MovementValidator.IsGrounded(character)

-- Predict trajectory
local predictedPos = MovementValidator.PredictTrajectory(rootPart, deltaTime)
```

### Remote Protection

```lua
-- Protect specific remote
RemoteProtection.Protect(remote)

-- Get player stats
local stats = RemoteProtection.GetPlayerStats(player)

-- Add blacklist pattern
RemoteProtection.AddBlacklistPattern("pattern")

-- Enable auto-protection
RemoteProtection.EnableAutoProtect()
```

## Security Principles

Based on Roblox Dev Forum best practices:

1. **Server Authority Only** - Never trust client-side values
2. **Behavioral Analysis** - Detect patterns, not specific exploits
3. **Soft Punishment First** - Kick before ban for uncertain cases
4. **Evidence Accumulation** - Build suspicion over time
5. **Grace Periods** - Allow for legitimate game mechanics
6. **Manual Review** - Review suspicious cases before permanent bans
7. **Defensive Design** - Reduce exploit value through game design

## Support

For issues, questions, or contributions:
- Review the Roblox Dev Forum security documentation
- Check detection logs for specific cases
- Test in a controlled environment first
- Adjust configuration based on your game's needs

## License

MIT License - See LICENSE file for details.

## Version History

### v2026.2 (Current)
- Modular architecture
- Advanced suspicion scoring
- BanAsync integration
- Movement validation with trajectory prediction
- Remote event protection
- Client-side data collection
- Comprehensive configuration system

### v2026.1 (Legacy)
- Single-file implementation
- Basic movement checks
- Simple strike system
- See `usm-v2026.2.lua` for legacy version
