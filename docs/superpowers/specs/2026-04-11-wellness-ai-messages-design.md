# Wellness AI Messages — Design Spec

## Context
Hero header-ul arată un mesaj wellness static ("Take it easy today", "Your energy is rising"). Mesajele se repetă și nu sunt personalizate. Vrem mesaje generate de AI, personalizate, addictive, care cresc retenția.

## Overview
Un call API pe zi generează 3 mesaje scurte (morning/afternoon/evening) personalizate pe baza datelor ciclului. Ton: best friend — cald, casual, empatic. Mesajele se cache-uiesc în SwiftData și se afișează cu shimmer → fade-in.

## Backend

### Endpoint nou: `POST /api/wellness-message`

**Request:**
```json
{
  "cycle_phase": "luteal",
  "cycle_day": 21,
  "days_until_period": 5,
  "is_late": false,
  "recent_symptoms": ["cramps", "fatigue"],
  "mood_level": 3,
  "energy_level": 2,
  "cycles_tracked": 11
}
```

**Response:**
```json
{
  "morning": "Your body is working hard behind the scenes today — a warm drink and slow morning will feel like magic.",
  "afternoon": "If you're feeling a bit foggy, that's completely normal at day 21. Be kind to yourself.",
  "evening": "You made it through the day. Rest deep tonight — your body will thank you tomorrow."
}
```

**Implementation:**
- Model: `gpt-4.1-mini` (same as recap)
- System prompt: instructs tone (best friend), length (max 20 words), personalization based on context
- Rate limit: 1 call per user per day (check by anonymous_id)
- Timeout: 10s
- File: `internal/api/wellness_message.go`

### System Prompt (core)
```
You are a warm, caring best friend who understands menstrual cycles deeply.
Generate 3 short wellness messages (morning, afternoon, evening) for today.
Each message: max 20 words, personal, empathetic, never clinical/medical.
Make each message unique, surprising, and emotionally resonant — like a fortune cookie from someone who truly knows you.
Use "you/your" — speak directly to her.
Never repeat the same message twice across days.
```

## iOS

### Data Flow
1. App start → TodayFeature `.loadDashboard`
2. Check SwiftData for `WellnessMessageRecord` with today's date
3. **Cache hit** → show message instantly (no shimmer)
4. **Cache miss** → show shimmer on header message → call API → fade-in → cache
5. Time slot selection: before 12:00 = morning, 12:00-18:00 = afternoon, after 18:00 = evening

### SwiftData Model: `WellnessMessageRecord`
```swift
@Model
class WellnessMessageRecord {
    var dateKey: String          // "yyyy-MM-dd"
    var morning: String
    var afternoon: String
    var evening: String
    var createdAt: Date = .now
}
```

### TCA Integration
- New action: `wellnessMessageLoaded(WellnessMessageRecord?)`
- New action: `wellnessMessageGenerated(Result<WellnessMessageRecord, Error>)`
- State: `wellnessMessage: String?` + `isLoadingWellnessMessage: Bool`
- Effect: fetch from SwiftData → if nil, call API → cache → send loaded

### Networking
- New function in `MenstrualLocalClient` or separate `WellnessClient`:
  `fetchWellnessMessage(context: AriaEphemeralContext) async throws -> WellnessMessageResponse`
- Uses same base URL as recap: `https://dth-backend-277319586889.us-central1.run.app/api/wellness-message`
- Timeout: 10s

### CycleHeroView Changes
- `wellnessMessage` computed property replaced with state from TodayFeature
- Shimmer: reuse existing `ShimmerModifier` while `isLoadingWellnessMessage == true`
- Fade-in: `.transition(.opacity)` when message arrives
- Fallback: if API fails, use current static messages (user never sees error)
- **Typography:** Raleway-MediumItalic, 15pt — italic gives "quoted/paraphrased" feel, 15pt ensures accessibility (min 14pt per WCAG)

### Cache Strategy
- SwiftData record per day
- On app start: query today's record
- If exists: instant display
- If not: shimmer → API call → save → display
- Old records cleaned up after 7 days (keep history for potential insights)

## Fallback
Static messages (current wellnessMessage computed property) used when:
- No internet
- API error/timeout
- First app start ever (before first successful API call)

User never sees an error state — always gets a message.

## Cost
- 1 API call per user per day
- gpt-4.1-mini: ~$0.0001 per call
- 1000 users = $0.10/day = $3/month
