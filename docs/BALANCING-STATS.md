# Balancing and Stats

## Index

- [Purpose](#purpose)
- [Current System](#current-system)
- [Current Stat Model](#current-stat-model)
- [Problems Observed](#problems-observed)
- [Future Ideas](#future-ideas)
- [Inspiration](#inspiration)
- [Open Questions](#open-questions)

## Purpose

This is the balancing notebook for Snap Battle. It documents the current implementation and captures future design ideas. Exploration items are not decisions.

## Current System

Status: Implemented in the PoC.

The current system creates four stats:

- Defense.
- Power.
- Agility.
- Energy.

Each creature has:

- Total budget: 240.
- Minimum per stat: 20.
- Maximum per stat: 100.

The calculator starts from role weights, applies a small material modifier, adds deterministic jitter from a stable seed, and distributes the fixed budget across the four stats.

## Current Stat Model

| Role | Primary Stat | Current Identity |
| --- | --- | --- |
| Guardian | Defense | Durable protector. |
| Striker | Power | Direct damage profile. |
| Trickster | Agility | Fast or evasive profile. |
| Channeler | Energy | Ability-focused profile. |

| Material | Current Modifier |
| --- | --- |
| Metallic | Defense +0.25 weight |
| Stone | Defense +0.20 weight |
| Organic | Power +0.15 weight |
| Aquatic | Energy +0.15 weight |
| Botanical | Energy +0.10 weight |
| Textile | Agility +0.20 weight |
| Unknown | No modifier |

## Problems Observed

Status: Observation.

- Low visual difference between creatures can lead to similar stat profiles.
- The budget is fixed for every creature.
- Rarity does not exist yet and cannot influence budget.
- Material modifiers are intentionally small.
- Statistical identity is mostly role-driven.
- Labels influence deterministic jitter, but not a strong gameplay identity.
- There are no combat formulas yet to test whether the stats are fun.

## Future Ideas

Status for all items: Exploration.

| Idea | Direction |
| --- | --- |
| Power Budget | Vary total budget by rarity, discovery quality, or progression. |
| Stat Shapes | Define recognizable distributions such as glass cannon, wall, sprinter, battery, or hybrid. |
| Object Modifiers | Let certain object categories push stats or abilities. |
| Controlled Variance | Add bounded variation while preserving role identity. |
| Image Fingerprint | Use stable image identity for reproducible uniqueness. |
| Rarity Budgets | Let rare creatures receive broader options without breaking balance. |
| Material Modifiers | Expand material into stronger identity and possible resistances. |
| Archetype Identity | Connect roles to abilities, passives, or battle behavior. |
| Critical Hits | Explore burst moments tied to agility, power, or abilities. |
| Elemental Resistances | Add matchup texture if materials or elements become meaningful. |
| Status Effects | Explore burn, stun, shield, poison, charge, sleep, or confusion analogs. |
| Special Skills | Give creatures active moves beyond base stats. |
| Energy System | Use energy as a resource for abilities. |
| Cooldowns | Pace strong abilities across turns or time. |
| Passives | Give creatures always-on identity. |
| Equipment | Let players modify identity without overwriting the creature. |
| Evolution | Let creatures grow while preserving origin. |

## Inspiration

| Reference | What To Study |
| --- | --- |
| Pokemon | Clear creature identity, types, evolution, collection fantasy. |
| Monster Hunter | Material fantasy, readable creature behavior, progression through mastery. |
| Persona | Personality, affinity systems, fusion, collection with emotional flavor. |
| Cassette Beasts | Creature capture, fusion-like experimentation, expressive monster identity. |
| Monster Sanctuary | Team synergy, skill trees, and build variety. |
| Slay the Spire | Tight resource loops, readable choices, controlled randomness. |
| Marvel Snap | Fast battles, lane tension, simple numbers with high strategic impact. |
| Magic: The Gathering | Keywords, archetypes, color identity, and long-term design vocabulary. |

These references are study material only. Snap Battle should not copy their systems directly.

## Open Questions

- Should Snap Battle use HP?
- Should Snap Battle use energy?
- Is there mana, charge, stamina, or another resource?
- How many attributes should combat actually need?
- How do creatures evolve?
- How does rarity influence power without creating automatic winners?
- How do we avoid power creep?
- Should stats be visible immediately or partially discovered?
- Should visual object type affect abilities more than stats?
- Should the same source object always imply the same archetype?
