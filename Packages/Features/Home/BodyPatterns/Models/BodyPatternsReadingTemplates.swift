import Foundation

// MARK: – Body Patterns Reading Templates
//
// Pure content. The engine (`BodyPatternsReadingEngine`) picks one
// variant per scenario via a deterministic hash of the pattern set,
// then fills the placeholders. Each scenario has 12-25 variants -
// enough that a user logging monthly takes years to see them all.
//
// Editorial discipline (cycle.app voice):
//   • Warm, attentive, anti-clinical.
//   • Present tense for active rhythms; soft uncertainty for
//     emerging signals.
//   • Lowercase symptom names mid-sentence; phase names lowercase
//     in copy ("luteal", not "Luteal").
//   • Numbers in copy stay short ("3 cycles", not "three cycles").
//   • One sentence = one breath. The card formatter splits on `. `
//     so each thought owns its own line.
//
// Placeholders by scenario:
//   • overviewCluster:        {phase}, {list}, {cycles}
//   • overviewMultiPhase:     {phase}, {list}
//   • overviewSingleActive:   {phase}, {name}, {cycles}
//   • overviewSingleEmerging: {name}, {occurrences}
//   • overviewMultiEmerging:  {list}
//   • detailOccurrence:       {name}, {occurrences}, {total}
//   • detailMostActiveDay:    {day}
//   • detailCoOccurrence:     {coname}, {cocount}
//   • detailTrendEasing:      (none)
//   • detailTrendStrengthening: (none)
//
// Adding more variants over time: just append to the array. The
// deterministic seed will start surfacing them automatically as
// the modulo space grows.

enum BodyPatternsReadingTemplates {

    // MARK: – Overview · Phase cluster (≥2 active in same phase)

    static let overviewCluster: [String] = [
        "Your {phase} patterns are clustering. {list} tend to ride together this cycle. {cycles} cycles running.",
        "{phase} is running thick – {list} keep arriving paired. {cycles} cycles deep.",
        "Your {phase} phase is holding a tight cluster: {list}. {cycles} cycles of the same shape.",
        "{list} are moving together in your {phase} again. {cycles} cycles into the rhythm.",
        "{phase} carries a cluster this cycle – {list}. {cycles} months in a row.",
        "Your body groups them in {phase}: {list}. {cycles} cycles confirming the address.",
        "There's a {phase} signature you keep tracing – {list}. {cycles} cycles in.",
        "{phase} weather settles in as {list}. Same forecast for {cycles} cycles.",
        "Your {phase} runs as a chord, not a note: {list}. {cycles} cycles holding it.",
        "{list} live in your {phase}, and they keep good company. {cycles} cycles strong.",
        "{phase} returns with {list} as a pack. {cycles} cycles of the same arrival.",
        "There's a familiar shape to your {phase}: {list} all together. {cycles} cycles of it.",
        "Your {phase} keeps the same residents: {list}. {cycles} cycles of the same neighbourhood.",
        "{phase} stitches them into one fabric: {list}. {cycles} cycles weaving the same pattern.",
        "Your {phase} reads as a set: {list}. Going on {cycles} cycles.",
        "{phase} is where {list} live this cycle. {cycles} cycles of the same gathering.",
        "{list} are companion patterns in your {phase}. {cycles} cycles of riding side by side.",
        "There's a knot in your {phase} this cycle – {list} arriving together. {cycles} cycles running.",
        "Your {phase} carries a cluster: {list}. Same shape for {cycles} cycles now.",
        "{phase} keeps gathering its weight: {list} all show up. {cycles} cycles steady.",
        "Your body has a {phase} signature: {list}. {cycles} cycles strong.",
        "{phase} this cycle reads as one piece, not three: {list}. {cycles} months in.",
        "{list} keep showing up paired in your {phase}. {cycles} cycles of the same pairing.",
        "Your {phase} holds them as one: {list}. {cycles} cycles of the same gathering.",
        "{phase} brings {list} together again. {cycles} cycles into this pattern."
    ]

    // MARK: – Overview · Multi-phase (≥2 active across phases, one loudest)

    static let overviewMultiPhase: [String] = [
        "{phase} is your loudest phase right now. {list} all confirmed.",
        "Your {phase} is doing most of the talking this cycle. {list} all logged.",
        "{phase} is carrying the volume – {list} all there.",
        "Your loudest phase this cycle is {phase}. {list} all confirmed.",
        "{list} are all logged. Your {phase} is the centre of the cluster.",
        "Patterns are spread across phases, with {phase} at the centre. {list}.",
        "{phase} is the busy phase right now. {list} all there.",
        "Your body's noisiest stretch is {phase}. {list} confirmed.",
        "{phase} is where most of your patterns live. {list} all there.",
        "Things are moving across phases, but {phase} is the headliner. {list}.",
        "{phase} runs loud this cycle – {list} all show up.",
        "Your {phase} holds the most signal. {list} confirmed.",
        "Patterns landed across phases. {phase} carries the most. {list}.",
        "{phase} is the part of the cycle you're feeling most. {list}.",
        "Your active patterns: {list}. {phase} is the loudest of the bunch.",
        "{phase} is busy this cycle. {list} all there.",
        "Your patterns spread across phases – {phase} carries the most weight. {list}.",
        "{list} all confirmed. {phase} is the room they're loudest in.",
        "Cycle's signal lives in {phase}: {list}.",
        "{phase} is where things gather this cycle. {list}.",
        "Your {phase} is the heaviest stretch. {list}.",
        "{phase} reads as the noisy phase. {list} all confirmed.",
        "Your patterns sit across phases, but {phase} carries the most. {list}.",
        "{list} are all in. {phase} is the focus this cycle.",
        "{phase} is leading the pattern set. {list} all confirmed."
    ]

    // MARK: – Overview · Single active pattern

    static let overviewSingleActive: [String] = [
        "Your {phase} is showing one steady rhythm: {name}. {cycles} cycles tracked.",
        "{name} is your {phase} signature. {cycles} cycles running.",
        "One pattern in your {phase}: {name}. {cycles} cycles deep.",
        "Your {phase} carries {name}, and only {name}. {cycles} cycles of it.",
        "{name} keeps showing up in your {phase}. {cycles} cycles in a row.",
        "{name} in {phase}, and nothing else. {cycles} cycles holding.",
        "Your {phase} has one resident: {name}. {cycles} cycles confirmed.",
        "There's one knot in your {phase}: {name}. {cycles} cycles deep.",
        "{name} holds the {phase} alone. {cycles} cycles tracked.",
        "Your {phase} reads as one note: {name}. {cycles} cycles strong.",
        "{name} is the only pattern your {phase} carries. {cycles} cycles in.",
        "{phase} brings {name} every time. {cycles} cycles confirmed.",
        "{name} is your {phase} steady. {cycles} cycles in.",
        "{phase} is quiet apart from {name}. {cycles} cycles of it.",
        "Your {phase} has a signature, and it's {name}. {cycles} cycles strong.",
        "{name} lives in your {phase}. {cycles} cycles into the rhythm.",
        "{phase} returns with {name} alone. {cycles} cycles of the same arrival.",
        "Your one {phase} pattern is {name}. {cycles} cycles confirmed.",
        "{name} is the {phase} story this cycle. {cycles} cycles into it.",
        "Your {phase} keeps {name} as its only resident. {cycles} cycles of it.",
        "{phase} carries {name}. Just {name}. {cycles} cycles steady.",
        "There's one familiar shape in your {phase}: {name}. {cycles} cycles confirmed.",
        "Your {phase} is {name}'s home. {cycles} cycles into it.",
        "{name} keeps your {phase} company. {cycles} cycles in.",
        "{phase} is consistent – {name} every time. {cycles} cycles of it."
    ]

    // MARK: – Overview · Single emerging pattern

    static let overviewSingleEmerging: [String] = [
        "{name} just started showing up – {occurrences} cycles in. Not enough to call it a pattern yet, but worth watching.",
        "{name} is a fresh signal – {occurrences} cycles so far. Watching.",
        "{name} appeared this cycle. {occurrences} cycles in. Could become a pattern.",
        "Something new: {name}. Showed up {occurrences} cycles in a row. Worth noticing.",
        "{name} is just starting to show – {occurrences} cycles. Not confirmed yet, just watching.",
        "{name} is on the radar. {occurrences} cycles in. Time will tell.",
        "{name} keeps showing up – {occurrences} cycles now. Could be the start of something.",
        "Worth watching: {name}. {occurrences} cycles deep.",
        "{name} is a young signal. {occurrences} cycles in, still gathering.",
        "{name} popped up again – {occurrences} cycles running. One more might confirm a pattern.",
        "Something stirring: {name}. {occurrences} cycles in.",
        "{name} is starting to repeat. {occurrences} cycles. Watching for one more.",
        "{name} arrived. {occurrences} cycles so far. Not a pattern yet.",
        "An emerging signal: {name}. {occurrences} cycles in.",
        "{name} keeps coming back – {occurrences} cycles. Worth keeping an eye on.",
        "{name} is in early days. {occurrences} cycles in. Not confirmed.",
        "{name} just started repeating – {occurrences} cycles. Could become a rhythm.",
        "{name} surfaced again. {occurrences} cycles in a row. Watching.",
        "Worth a note: {name}. {occurrences} cycles, building.",
        "{name} keeps making appearances – {occurrences} cycles in. One to watch."
    ]

    // MARK: – Overview · Multiple emerging patterns

    static let overviewMultiEmerging: [String] = [
        "Just starting to show: {list}. Worth watching across the next cycle or two.",
        "Fresh signals this cycle: {list}. Not patterns yet, just emerging.",
        "{list} are all showing for the first few cycles. Watching.",
        "New on the radar: {list}. Building, not confirmed.",
        "{list} just started repeating. Worth keeping an eye on.",
        "Several emerging signals: {list}. Not patterns yet.",
        "{list} are all in early days. Time will tell.",
        "Things stirring: {list}. Still gathering.",
        "{list} keep showing up – a couple cycles each. Emerging.",
        "Watch list: {list}. Each one a few cycles in.",
        "Several young signals: {list}. Not confirmed.",
        "{list} are starting to repeat. Watching all of them.",
        "Quiet build: {list}. Each one showing for a few cycles.",
        "Fresh patterns showing: {list}. Worth a follow-up.",
        "{list} are all in the early stretch. Building."
    ]

    // MARK: – Detail · S1 Occurrence (always rendered)

    static let detailOccurrence: [String] = [
        "{name} shows up in {occurrences} of {total} cycles.",
        "{name} appears in {occurrences} of your last {total} cycles.",
        "{occurrences} of {total} cycles carry {name}.",
        "{name} hits in {occurrences} of {total} cycles tracked.",
        "{name} is logged in {occurrences} of your {total} cycles.",
        "{name} surfaces in {occurrences} of {total} cycles.",
        "Across {total} cycles, {name} arrives in {occurrences}.",
        "{name} repeats in {occurrences} of {total} cycles.",
        "{occurrences} cycles out of {total} carry {name}.",
        "{name} comes around in {occurrences} of {total} cycles.",
        "Tracked: {name} in {occurrences} of {total} cycles.",
        "Of your {total} cycles, {occurrences} carry {name}.",
        "{name} is part of {occurrences} of your {total} cycles.",
        "{name} returns in {occurrences} of {total} cycles.",
        "{occurrences} of {total} cycles include {name}."
    ]

    // MARK: – Detail · S2 Most active day

    static let detailMostActiveDay: [String] = [
        "Most often on day {day}.",
        "Almost always on day {day}.",
        "Day {day} is when it hits hardest.",
        "Day {day} carries the bulk of it.",
        "Lands on day {day} more than anywhere else.",
        "Day {day} is the usual landing.",
        "Most cycles, it shows up on day {day}.",
        "Day {day} is the regular arrival.",
        "It tends to land on day {day}.",
        "Day {day} is its home.",
        "Hits on day {day} most cycles.",
        "Day {day} is the consistent day."
    ]

    // MARK: – Detail · S3 Co-occurrence

    static let detailCoOccurrence: [String] = [
        "{coname} comes along in {cocount} of those.",
        "{coname} usually rides with it – {cocount} cycles.",
        "{cocount} of those cycles also carry {coname}.",
        "{coname} keeps it company {cocount} cycles out of those.",
        "Pairs with {coname} in {cocount} of those.",
        "{coname} shows up alongside it {cocount} times.",
        "{coname} is the co-pilot {cocount} of those cycles.",
        "{coname} arrives in {cocount} of the same cycles.",
        "{coname} doubles up {cocount} times.",
        "{coname} comes with it in {cocount} cycles.",
        "{cocount} of those cycles also bring {coname}.",
        "{coname} runs alongside it {cocount} times."
    ]

    // MARK: – Detail · S4 Trend (easing)

    static let detailTrendEasing: [String] = [
        "Severity has eased lately.",
        "Lately, it's been lighter.",
        "Severity is easing across recent cycles.",
        "It's been quieter recently.",
        "The intensity has dropped recently.",
        "Lately, the severity has been softer.",
        "Recent cycles have been gentler with it.",
        "It's eased off in the last few cycles.",
        "Severity has been retreating.",
        "Lately, less of it."
    ]

    // MARK: – Detail · S4 Trend (strengthening)

    static let detailTrendStrengthening: [String] = [
        "Severity has been climbing.",
        "It's been louder lately.",
        "Recent cycles have intensified.",
        "Severity is on the rise.",
        "It's been heavier in recent cycles.",
        "The intensity has been growing.",
        "Lately, it's been turning up the volume.",
        "Recent cycles have been more intense.",
        "It's been climbing in severity.",
        "The recent run has been heavier."
    ]
}
