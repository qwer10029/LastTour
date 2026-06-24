# Real Music Generation Prompts

Use these prompts to replace the remaining placeholder music in `game/assets/music/`.
`day_exploration` and `night_combat` are already real tracks, so this sheet focuses on
the remaining placeholder or likely-regenerated cues.

## Global Direction

Game tone: lonely post-apocalyptic road survival, cold terminals, ruined cities,
night defense pressure, and a final human/AI truth reveal. Keep the music restrained,
loop-friendly, and usable under dialogue/UI. Avoid big pop hooks.

Default generation constraints:

- No vocals, no lyrics, no spoken words.
- No direct imitation of a real artist, movie score, game score, or copyrighted theme.
- Keep arrangements sparse enough for gameplay.
- For looped cues, avoid a hard ending, final cymbal crash, or long fade-out.
- Export stereo, 44.1 kHz or 48 kHz. Normalize moderately; leave headroom.
- Use the exact filename/extension listed for the current `MusicManager` path.

Reusable negative prompt:

```text
No vocals, no lyrics, no rap, no EDM drop, no upbeat pop melody, no heroic trailer brass, no comedy, no chiptune, no busy lead solo, no sudden loud ending, no copyrighted melody, no artist imitation.
```

## Prompt Sheet

### `menu_main.wav` - Main Menu

- Length: 32s minimum
- Loop: yes
- Scene: main menu
- Mood: cold, lonely, inviting, ruined-world calm

```text
Seamless loop, 32 seconds, post-apocalyptic sci-fi main menu theme for a lonely road survival game. Sparse felt piano notes, soft analog synth pad, distant radio static, very low bowed string drone, subtle glass bell accents. Cold and melancholy but not hopeless, slow 72 BPM pulse, minimal percussion, wide stereo ambience, restrained cinematic game music, suitable under menu UI.
```

### `menu_select.wav` - Difficulty / Squad Select

- Length: 24s minimum
- Loop: yes
- Scene: difficulty select, squad select, run loading
- Mood: focused, tactical, quietly tense

```text
Seamless loop, 24 seconds, subdued tactical selection screen music for a post-apocalyptic survival game. Muted synth bass pulse, soft mechanical ticks, distant filtered percussion, thin icy pads, small metallic bell motif. Focused and anticipatory, 78 BPM, restrained and clean, no big melody, no combat intensity, designed to sit under UI choices and loading screens.
```

### `opening_prologue.wav` - Opening Prologue

- Length: 32s minimum
- Loop: yes
- Scene: opening story images / prologue
- Mood: desolate, narrative, human

```text
Seamless loop, 32 seconds, cinematic prologue music for a bleak post-apocalyptic journey. Lonely felt piano, soft cello harmonics, low wind-like synth texture, distant metallic resonance, slow fragile chord movement. Desolate but intimate, 70 BPM, quiet emotional storytelling, no percussion except faint heartbeat-like low pulses, leaves space for narration and image transitions.
```

### `evening_warning.wav` - Evening Warning Stinger

- Length: 7s
- Loop: no
- Scene: dusk warning before night phase
- Mood: urgent warning, not a jump scare

```text
Short 7 second warning stinger for sunset turning into danger in a post-apocalyptic tower defense survival game. Low synthetic alarm swell, two restrained terminal beeps, descending icy bell tones, a dark sub-bass hit, then unresolved tension. Urgent and serious, not horror, not explosive, clean ending with no long reverb tail.
```

### `night_setup.wav` - Night Defense Preparation

- Length: 28s minimum
- Loop: yes
- Scene: night tower placement / setup phase
- Mood: preparation, pressure, machinery waking up

```text
Seamless loop, 28 seconds, night defense preparation music for a post-apocalyptic tower defense phase. Low industrial drone, muted clockwork percussion, soft synth bass pulses, distant machine hum, sparse metallic plucks. Tense but controlled, 86 BPM, strategic planning mood before combat, no aggressive drums, no heroic melody, loop must feel steady and usable while placing defenses.
```

### `terminal.mp3` - Follow Terminal Orders / Top Floor Shot

- Length: 28s minimum
- Loop: yes
- Scene: communication terminal opens, player obeys terminal instruction, "being shot" story beat
- Mood: controlled, cold, mechanical, dominated by the machine

```text
Seamless loop, 28 seconds, cold terminal-control music for a post-apocalyptic sci-fi story scene. Restrained synthetic low-frequency pulse, dry terminal ticking, faint modem-like textures, narrow icy pad, tiny irregular beeps, almost no melody. The feeling is being ordered by a machine and losing agency: clinical, tense, obedient, unsettling but not loud. 72 BPM, minimal, dialogue-friendly, no emotional release.
```

### `truth_reveal.mp3` - Truth Reveal / Regain Terminal Control

- Length: 34s minimum
- Loop: yes
- Scene: final ceremony, truth known, player controls the terminal
- Mood: pressure lifting into clarity, grief, awakening

```text
Seamless loop, 34 seconds, emotional truth-reveal music for a post-apocalyptic sci-fi game. Begin with sparse felt piano and a cold low drone, then gradually add warm string pad and soft cello tones, shifting from oppression to clarity and quiet grief. Slow 68 BPM, bittersweet awakening, fragile hope, cinematic but restrained, no big trailer climax, no final cadence, loopable under an important story choice.
```

### `final_choice.wav` - Final Ending Choice

- Length: 32s minimum
- Loop: yes
- Scene: final outcome / ending choice screen
- Mood: moral weight, unresolved consequence

```text
Seamless loop, 32 seconds, final decision music for a bleak sci-fi survival game. Slow minor-key piano motif, deep warm strings, distant synthetic choir pad without voices, soft sub-bass movement, faint electronic shimmer. Heavy moral weight, grief, responsibility, and unresolved consequence, 64 BPM, restrained cinematic ending atmosphere, no triumphant resolution, no dramatic drum build.
```

### `run_reset.wav` - Loop Reset Stinger

- Length: 6.5s
- Loop: no
- Scene: run reset / cycle restarts
- Mood: rewind, failure, system reset

```text
Short 6.5 second reset stinger for a post-apocalyptic time-loop survival game. Reverse piano swell, five descending metallic notes, low synth drop, glitchy terminal reset click, brief cold silence at the end. Feels like memory collapsing and the run restarting, serious and clean, no horror scream, no long fade, no musical resolution.
```

## Optional Future Cues

These are not wired as current `MusicManager` cues, but they match the earlier soundtrack notes.

### `boss_thunder` - Thunder Boss Fight

```text
Seamless loop, 36 seconds, boss battle music for an undefeated shield/Thunder war machine in a post-apocalyptic tower defense game. Heavy metallic percussion, distorted low synth ostinato, grinding machine rhythm, warning siren fragments, tense brass-like synth stabs. High pressure and militarized, 104 BPM, intense but still readable under gameplay, no vocals, no heroic melody.
```

### `elevator_ascend` - Elevator Repaired / Ascending

```text
Short 10 second transition stinger for a repaired elevator ascending through a ruined sci-fi tower. Rising warm synth chord, small mechanical lift rhythm, soft bell glints, low rumble turning into fragile hope. Clean ending, hopeful but restrained, no big triumphant fanfare, no vocals.
```
