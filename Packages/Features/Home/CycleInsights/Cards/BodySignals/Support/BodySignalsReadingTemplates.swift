import Foundation

// MARK: - Body Signals Reading Templates
//
// Pure content for the Reading section that sits beneath each
// metric chart on `BodySignalsDetailView`'s focused screens. The
// engine (`BodySignalsReadingEngine`) picks one variant per metric
// via a deterministic seed so the same screen reads the same way
// within a session, but cross-cycles the variant rotates so the
// voice doesn't feel canned.
//
// Editorial discipline (cycle.app voice):
//   • Plain language. No clinical jargon, no fitness-influencer
//     prescriptions.
//   • Explain what the chart shows AND what the metric means in
//     daily terms. The user is here because they tapped a tile;
//     they want context.
//   • Acknowledge variability. "Two-to-five beats is typical" —
//     not "your resting heart rate should be X".
//   • Permission language. "Worth noticing", "the body asking for
//     rest" — not "you should do Y".
//   • Numbers in copy stay short ("3 cycles", not "three cycles").
//   • One sentence = one breath. The card formatter splits on
//     `. ` so each thought owns its own line.
//
// Adding more variants over time: just append to the array. The
// deterministic seed will start surfacing them automatically as
// the modulo space grows.

enum BodySignalsReadingTemplates {

    // MARK: - Wrist temperature

    static let wristTemperature: [String] = [
        "Wrist temperature shifts up around ovulation and stays warmer through luteal. It's a quiet biological signal, not something you control.",
        "Each dot is a single night's reading from your watch. The pattern across the cycle tells you more than any one number.",
        "What you're seeing: how warm or cool you ran each night, plotted against your personal baseline. Higher in the second half is normal.",
        "The shift is small – fractions of a degree. Read the shape, not the numbers.",
        "Your body warms a touch after ovulation. The graph traces that arc across your cycle.",
        "Apple Watch reads wrist temperature while you sleep. cycle.app charts the rhythm, not absolute values.",
        "Above the baseline = warmer than your usual night. Below = cooler. Both are normal at different phases.",
        "Temperature stays elevated until just before menstruation, then settles back. That dip is the reset.",
        "You'll see the most movement around ovulation and right before your period.",
        "What this isn't: a fertility test. What this is: a window into your body's monthly rhythm.",
        "The line worth reading is the trend, not any single dot.",
        "Wrist temperature isn't body temperature. It's the surface signal – useful for patterns, not for fevers.",
        "Higher in luteal, lower in follicular. That's the cadence to listen for.",
        "The pattern smooths out over two or three cycles. Give your body a few months before reading it tightly.",
        "A cooler night here and there is part of life. The arc is what matters."
    ]

    // MARK: - Heart rate variability

    static let hrv: [String] = [
        "Heart rate variability is the spacing between your heartbeats. More variation usually means more recovery capacity.",
        "HRV tends to drop in late luteal and recover in follicular. The dip isn't a problem – it's the body asking for rest.",
        "What you're seeing: your nightly HRV plotted across phases. The differences between phases tell you more than any single night.",
        "Higher numbers = more parasympathetic activity = more rest available. Lower = stress, fatigue, or just a cycle phase.",
        "Your HRV will look different than someone else's. Compare it to your own baseline, not anyone else's.",
        "Late luteal HRV often runs 5-15 ms below your follicular average. That's typical, not concerning.",
        "What you're seeing: how your nervous system rides the cycle. Calmer in follicular, more reactive in luteal.",
        "Read the trend, not the single number. One bad night isn't a story.",
        "If HRV stays low across several phases in a row, that's a signal worth noticing.",
        "Apple Watch measures HRV during sleep. cycle.app shows you how it shifts with your phases.",
        "HRV is one of the most variable readings on your watch. Use it as a soft compass, not a verdict.",
        "What HRV isn't: a fitness score. What it is: a mirror of how your body is handling the day.",
        "Higher in follicular, lower in luteal. That's the typical arc.",
        "The number alone isn't useful. The shape across your cycle is.",
        "Some women see clear HRV phases, others don't. Both are normal."
    ]

    // MARK: - Resting heart rate

    static let restingHR: [String] = [
        "Resting heart rate climbs a few beats in luteal and settles back in early follicular. Two to five beats is typical.",
        "The hump in the second half of your cycle isn't effort – it's hormonal. Progesterone raises your baseline heart rate.",
        "What you're seeing: your nightly resting heart rate plotted across the cycle. The gentle rise and fall is the rhythm to read.",
        "Apple Watch measures resting heart rate while you sleep. cycle.app charts it across your phases.",
        "A stable resting heart rate cycle to cycle is a good sign of consistency, not perfection.",
        "Higher in luteal, lower in follicular. That's the cadence to expect.",
        "The shift is small but real. Read the trend across cycles, not single days.",
        "Your resting heart rate has its own normal. Compare it to your own pattern, not anyone else's.",
        "Sudden jumps without an obvious cause are worth noting. Gradual changes across the cycle are not.",
        "What this isn't: cardio fitness. What this is: how your nervous system responds to the cycle.",
        "If your resting heart rate runs 5+ beats above your baseline for several days, your body might be fighting something.",
        "The dot worth reading is the average across the phase, not any single morning.",
        "Cycle phase, sleep quality, hydration, alcohol – all of these move the needle. The cycle pattern is one input among many.",
        "Two to five extra beats around your period is the body, not a problem.",
        "The shape across the month is more telling than the absolute numbers."
    ]

    // MARK: - Empty-state copy
    //
    // Used when `metric.hasData == false` – the chart shows
    // "No Data" / "Soon" and the with-data templates ("each dot
    // is…") would reference visuals that aren't on screen yet.
    // These read forward instead: what the metric is, why it's
    // worth wearing the watch, what the chart will show once
    // samples land.

    static let wristTemperatureSoon: [String] = [
        "Wear your Apple Watch overnight to start collecting wrist temperature. After a few nights, the chart will show how your body warms after ovulation and settles before menstruation.",
        "No wrist temperature samples yet. Once your watch has a few nights of sleep data, you'll see the cycle's gentle warming arc.",
        "Wrist temperature is the overnight skin reading from your Apple Watch. Sleep with it on for a few nights and the pattern starts to surface.",
        "Once samples arrive, this chart will trace how your overnight temperature shifts across the cycle – a fraction of a degree warmer after ovulation, cooler before your period.",
        "Your watch hasn't logged wrist temperature yet. After a few nights it will – warmer in luteal, cooler in follicular is what you'll see.",
        "Wear your watch to bed for a week or two. Wrist temperature is a quiet biological signal that shows up in the pattern, not in any single night.",
        "Wrist temperature isn't body temperature. It's the surface signal from your watch, useful for reading the cycle's rhythm once samples land.",
        "Apple Watch reads wrist temperature while you sleep. cycle.app will chart that rhythm here once a few nights have been logged.",
        "Once you've worn your watch overnight a handful of times, this chart fills in. You'll see the small shift around ovulation and the reset before menstruation.",
        "Your body warms a touch after ovulation. The chart will trace that arc here – give it a few nights of sleep with your watch on.",
        "No samples yet. Wear your watch overnight; the cycle's warming pattern usually shows up within two to three weeks.",
        "Wrist temperature is one of the most useful soft signals on your watch. After a few nights, you'll start to see how your body rides the cycle."
    ]

    static let hrvSoon: [String] = [
        "Wear your Apple Watch overnight to start collecting HRV. Once a few nights are logged, the chart will show how your nervous system rides the cycle – calmer in follicular, more reactive in luteal.",
        "No HRV samples yet. After a few nights with your watch on, you'll see the per-phase arc.",
        "Heart rate variability is the spacing between your heartbeats. More variation usually means more recovery capacity. The chart will show that pattern once samples land.",
        "Your watch measures HRV during sleep. Wear it overnight and the cycle's recovery pattern starts to surface here.",
        "Once data lands, this chart will show how HRV shifts across your phases. Higher in follicular, lower in late luteal is the typical arc.",
        "HRV is a soft signal, not a fitness score. Sleep with your watch on for a couple weeks and you'll see the cycle's rhythm.",
        "Apple Watch reads HRV while you sleep. cycle.app will plot it here per phase once a few nights are recorded.",
        "Wear your watch to bed. HRV is one of the most useful overnight signals for understanding how your body's handling the cycle.",
        "No HRV in this window yet. Once samples arrive, you'll see how recovery capacity shifts with your phases.",
        "Higher HRV usually means more parasympathetic activity – more rest available. The chart will show how that moves with your cycle once data lands.",
        "Once you've slept with your watch a few nights, this chart fills in. The differences between phases are what reads, not any single night.",
        "HRV usually drops 5-15 ms between follicular and late luteal. After a few cycles of overnight data, you'll see your own version of that arc."
    ]

    static let restingHRSoon: [String] = [
        "Wear your Apple Watch overnight to start collecting resting heart rate. Once a few nights are logged, the chart will show how it rises a few beats in luteal and settles back in early follicular.",
        "No resting heart rate samples yet. After a few nights with your watch on, you'll see the cycle's gentle rise and fall.",
        "Resting heart rate is captured while you sleep or during calm moments. The chart will trace its movement across your cycle once your watch has logged a few nights.",
        "Once samples land, this chart will show your resting heart rate across the cycle – two to five beats higher in luteal is typical.",
        "Apple Watch reads resting heart rate at rest. Wear it overnight and the cycle's pattern starts to surface here.",
        "No data here yet. Once your watch has a couple weeks of sleep, you'll see the small hormonal hump in the second half of the cycle.",
        "The chart will show your nightly resting heart rate plotted against your personal baseline. That arc takes a few nights to appear.",
        "Wear your watch to bed for a couple of weeks. Resting heart rate is one of the most readable cycle signals once samples arrive.",
        "Progesterone raises baseline heart rate in luteal. Once your watch has a few nights of data, you'll see that gentle climb here.",
        "Your resting heart rate has its own normal. Wear your watch overnight and the chart will surface yours – your own pattern, not anyone else's.",
        "Two to five extra beats around your period is the body, not a problem. The chart shows that rhythm once a few nights are logged.",
        "Once samples land, this chart fills in. Read the shape across the month, not any single night."
    ]
}
