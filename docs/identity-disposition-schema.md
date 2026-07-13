# Identity, disposition, and self-concept schema boundary

Power & Proximity should model identity as context, not as a behavior score. Identity can be lived, expressed, discovered, concealed, misread, affirmed, rejected, or socially contested, but repeated behavior must not rewrite protected identity categories.

## Design law

```text
Behavior does not rewrite protected identity.
Behavior rewrites disposition, habits, reputation, and self-concept.
```

This keeps character simulation human without making it deterministic in the wrong direction. A character's identity may evolve through story, discovery, expression, relationships, or social context. The system must not infer that acting in a particular way changes race, gender, sexuality, disability, religion, or comparable identity/context fields.

## Schema split

### 1. Identity and context

Identity/context describes who someone is, how they are seen, and where they stand socially. These fields may affect social interpretation, safety, access, pressure, belonging, or conflict, but they must not determine morality, intelligence, competence, trustworthiness, aggression, or other behavioral worth judgments.

Examples:

```text
genderIdentity
genderExpression
sexualOrientation
romanticOrientation
raceEthnicity
culture
classBackground
religion
language
disability
age
familyStatus
immigrationStatus
communityAffiliation
```

Implementation rule: identity/context fields are authored, discovered, expressed, concealed, or changed only through explicit narrative/state transitions. They are not updated by generic behavior scoring.

### 2. Disposition and traits

Disposition/trait fields are the living sliders. They can shift through repeated behavior, memories, incentives, stress, relationships, and social consequences.

Examples:

```text
willfulness
cunning
pragmatism
discipline
compassion
integrity
resentment
forgiveness
gravitas
courage
socialGrace
powerDrive
riskTolerance
```

Implementation rule: behavior may adjust disposition/traits when the behavior evidence is relevant and repeated enough to justify a change.

### 3. Self-concept

Self-concept is where identity/context and behavior can meet. It tracks how a character understands their role, compromises, loyalties, wounds, and aspirations.

Examples:

```text
protector
sellout
workerAdvocate
survivor
leader
coward
professional
caretaker
rebel
reformer
loyalist
```

Implementation rule: self-concept can evolve based on repeated choices, remembered events, social feedback, and personal reflection. It must not be used as a covert path to rewrite protected identity.

## Canonical JSON shape

```json
{
  "identity": {
    "genderIdentity": "woman",
    "sexualOrientation": "asexual",
    "raceEthnicity": ["Latina"],
    "visibility": {
      "sexualOrientation": "trusted_circle",
      "raceEthnicity": "public"
    }
  },
  "traits": {
    "discipline": 82,
    "compassion": 69,
    "integrity": 70,
    "riskTolerance": 31,
    "resentment": 44
  },
  "selfConcept": {
    "protector": 61,
    "survivor": 74,
    "reluctantActivist": 38
  }
}
```

## Simulation pipeline

```text
Identity gives context.
Traits drive behavior.
Behavior creates memories.
Memories shift traits.
Repeated traits form character.
Public stories form reputation.
Reputation changes how identity is interpreted by others.
```

Reputation can change how others interpret identity/context, but it is still not identity. For example, public stories may change whether a community reads someone as respectable, threatening, loyal, assimilated, rebellious, or safe. Those interpretations belong to reputation, social memory, bias, and relationship state—not to protected identity values.

## Guardrails for future implementation

- Keep protected identity/context fields in a separate object from behavior-derived traits.
- Do not give identity fields positive or negative trait weights.
- Do not let trait deltas write to identity fields.
- Do not use self-concept labels as hidden proxies for protected identity changes.
- Store visibility and social interpretation separately from the underlying identity/context value.
- When a story intentionally changes identity expression, discovery, concealment, or affiliation, represent that as an explicit narrative event with provenance.
- When behavior changes how others respond to a character, write to memories, reputation, relationship state, traits, habits, or self-concept.
