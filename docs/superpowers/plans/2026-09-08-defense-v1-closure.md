# Defense v1 Closure Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Formally close the Defense v1 contract in the combat pipeline, establishing the deterministic order `Raw Damage -> Block -> Physical/Magic Mitigation -> Minimum Damage` with zero mutations and full contract test coverage.

**Architecture:** Solidify defense constants in `DamageConstants` (including `MAGIC_PIERCING_CAP`), verify `DamageCalculator` conforms strictly to the two-tier mitigation pipeline (flat block followed by percentage resilience/resistance), and expand `test_combat_defense.gd` to test all defense contract invariants without introducing unneeded mechanics.

**Tech Stack:** Godot 4.6.1 GDScript, RefCounted combat services, SceneTree test runners.

**Spec:** User specification for Defense v1:
- Pipeline order: `Critical -> Hit / Miss -> Block -> Physical/Magic Mitigation -> Minimum Damage`
- Armor / Physical Defense: `physical_resilience` applied strictly after `blocked_amount`.
- Magic Resistance: `magic_resistance` applied after `blocked_amount`, with `magic_piercing` strictly for magic.
- Block: `BlockResolver.resolve(defender_stats) -> float` without `BlockResult`.
- Out of scope: armor penetration, parry, dodge, block chance, equipment, status effects, lifesteal, threat.

## Global Constraints

- GDScript static typing enabled throughout.
- Do not mutate `DerivedStats` during combat resolution.
- `MIN_DAMAGE` constant remains `1.0`.
- Caps: `PHYSICAL_RESILIENCE_CAP = 0.75`, `MAGIC_RESISTANCE_CAP = 0.75`, `MAGIC_PIERCING_CAP = 0.50`.
- All tests must run cleanly via `Godot_v4.6.1-stable_win64_console.exe --headless -s`.

---

### Task 1: Standardize Defense Constants

**Files:**
- Modify: `src/gameplay/combat/damage/damage_constants.gd:1-12`
- Modify: `src/gameplay/combat/damage/damage_calculator.gd:105-115`
- Test: `src/gameplay/combat/tests/test_damage.gd`

**Interfaces:**
- Consumes: None
- Produces: `DamageConstants.MAGIC_PIERCING_CAP: float = 0.50`

- [x] **Step 1: Write the failing test assertion in test_damage.gd**

Add an assertion checking `DamageConstants.MAGIC_PIERCING_CAP == 0.50` in `test_magical_damage_caps`:

```gdscript
_assert_approx(DamageConstants.MAGIC_PIERCING_CAP, 0.50, "DamageConstants.MAGIC_PIERCING_CAP is defined as 0.50")
```

- [x] **Step 2: Run test to verify it fails**

Run:
```powershell
& "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe" --headless -s "c:\Users\olivereld\Documents\dungeon-divers\src\gameplay\combat\tests\test_damage.gd"
```
Expected: FAIL with `Invalid get index 'MAGIC_PIERCING_CAP'`.

- [x] **Step 3: Implement MAGIC_PIERCING_CAP in DamageConstants and use it in DamageCalculator**

In `src/gameplay/combat/damage/damage_constants.gd`:
```gdscript
class_name DamageConstants
extends RefCounted


const MIN_DAMAGE := 1.0

const PHYSICAL_RESILIENCE_CAP := 0.75
const MAGIC_RESISTANCE_CAP := 0.75
const MAGIC_PIERCING_CAP := 0.50

const CRITICAL_DAMAGE_MULTIPLIER := 1.5
```

In `src/gameplay/combat/damage/damage_calculator.gd`:
```gdscript
	var piercing := clampf(
		request.attacker_stats.magic_piercing,
		0.0,
		DamageConstants.MAGIC_PIERCING_CAP
	)
```

- [x] **Step 4: Run test to verify it passes**

Run:
```powershell
& "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe" --headless -s "c:\Users\olivereld\Documents\dungeon-divers\src\gameplay\combat\tests\test_damage.gd"
```
Expected: PASS (0 failures).

- [x] **Step 5: Commit**

```bash
git add src/gameplay/combat/damage/damage_constants.gd src/gameplay/combat/damage/damage_calculator.gd src/gameplay/combat/tests/test_damage.gd
git commit -m "feat(combat): standardize MAGIC_PIERCING_CAP in DamageConstants"
```

---

### Task 2: Complete Contract Tests for Physical Defense and Block Pipeline

**Files:**
- Modify: `src/gameplay/combat/tests/test_combat_defense.gd`

**Interfaces:**
- Consumes: `CombatResolver`, `AttackRequest`, `AttackData`, `DamageType`, `DerivedStats`, `DamageConstants`
- Produces: Contract verification suite covering all physical defense invariants

- [x] **Step 1: Write test_physical_block_and_resilience_combined**

In `src/gameplay/combat/tests/test_combat_defense.gd`, add `_test_physical_block_and_resilience_combined()`:
- Attacker: `physical_power = 20.0`
- AttackData: `base_damage = 80.0`, `DamageType.PHYSICAL` -> `raw_damage = 100.0`
- Defender: `shield_block_value = 20.0`, `physical_resilience = 0.25`
- Calculation expectation:
  - `raw_damage == 100.0`
  - `damage_after_block == 80.0`
  - `resistance_mitigation == 80.0 * 0.25 = 20.0`
  - `final_damage == 60.0`
  - `mitigated_damage == 40.0` (20 block + 20 resilience)
  - `was_blocked == true`

```gdscript
func _test_physical_block_and_resilience_combined() -> void:
	_test_count += 1

	var attacker := _create_stats()
	var defender := _create_stats()

	attacker.physical_power = 20.0
	defender.shield_block_value = 20.0
	defender.physical_resilience = 0.25

	var attack_data := AttackData.new(80.0, DamageType.Type.PHYSICAL)
	var resolver := _create_resolver(12345)

	var result := resolver.resolve_attack(AttackRequest.new(attacker, defender, attack_data))

	_assert(result.did_hit(), "Physical combined attack hits.")
	_assert(result.damage_result.raw_damage == 100.0, "Raw damage is 100.")
	_assert(result.damage_result.final_damage == 60.0, "Final damage is 60 after block and resilience.")
	_assert(result.damage_result.mitigated_damage == 40.0, "Mitigated damage is 40.")
	_assert(result.damage_result.was_blocked, "was_blocked is true.")
```

- [x] **Step 2: Add call in _run_tests() and run to verify execution**

Run:
```powershell
& "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe" --headless -s "c:\Users\olivereld\Documents\dungeon-divers\src\gameplay\combat\tests\test_combat_defense.gd"
```
Expected: PASS.

- [x] **Step 3: Commit**

```bash
git add src/gameplay/combat/tests/test_combat_defense.gd
git commit -m "test(combat): add physical block and resilience combined contract test"
```

---

### Task 3: Complete Contract Tests for Magical Defense, Block, and Piercing

**Files:**
- Modify: `src/gameplay/combat/tests/test_combat_defense.gd`

**Interfaces:**
- Consumes: `CombatResolver`, `AttackRequest`, `AttackData`, `DamageType`, `DerivedStats`
- Produces: Contract verification suite covering magic resistance + block + magic piercing invariants

- [x] **Step 1: Write test_magical_block_resistance_and_piercing_combined**

In `src/gameplay/combat/tests/test_combat_defense.gd`, add `_test_magical_block_resistance_and_piercing_combined()`:
- Attacker: `spell_power = 50.0`, `magic_piercing = 0.25`
- AttackData: `base_damage = 50.0`, `DamageType.MAGICAL` -> `raw_damage = 100.0`
- Defender: `shield_block_value = 20.0`, `magic_resistance = 0.40`
- Calculation expectation:
  - `raw_damage == 100.0`
  - `damage_after_block == 80.0`
  - `effective_resistance = 0.40 * (1.0 - 0.25) = 0.30`
  - `resistance_mitigation = 80.0 * 0.30 = 24.0`
  - `final_damage = 80.0 - 24.0 = 56.0`
  - `mitigated_damage = 100.0 - 56.0 = 44.0`
  - `was_blocked == true`

```gdscript
func _test_magical_block_resistance_and_piercing_combined() -> void:
	_test_count += 1

	var attacker := _create_stats()
	var defender := _create_stats()

	attacker.spell_power = 50.0
	attacker.magic_piercing = 0.25
	defender.shield_block_value = 20.0
	defender.magic_resistance = 0.40

	var attack_data := AttackData.new(50.0, DamageType.Type.MAGICAL)
	var resolver := _create_resolver(12345)

	var result := resolver.resolve_attack(AttackRequest.new(attacker, defender, attack_data))

	_assert(result.did_hit(), "Magical combined attack hits.")
	_assert(result.damage_result.raw_damage == 100.0, "Raw damage is 100.")
	_assert(result.damage_result.final_damage == 56.0, "Final damage is 56 after block and pierced resistance.")
	_assert(result.damage_result.mitigated_damage == 44.0, "Mitigated damage is 44.")
	_assert(result.damage_result.was_blocked, "was_blocked is true.")
```

- [x] **Step 2: Add call in _run_tests() and run to verify execution**

Run:
```powershell
& "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe" --headless -s "c:\Users\olivereld\Documents\dungeon-divers\src\gameplay\combat\tests\test_combat_defense.gd"
```
Expected: PASS.

- [x] **Step 3: Commit**

```bash
git add src/gameplay/combat/tests/test_combat_defense.gd
git commit -m "test(combat): add magical block, resistance, and piercing contract test"
```

---

### Task 4: Complete Contract Tests for Critical + Block + Defense, Minimum Damage, Miss, and Immutability

**Files:**
- Modify: `src/gameplay/combat/tests/test_combat_defense.gd`

**Interfaces:**
- Consumes: `CombatResolver`, `DerivedStats`, `AttackRequest`, `AttackData`
- Produces: Complete Defense v1 verification suite

- [x] **Step 1: Write critical block with defense test**

`_test_critical_block_and_resilience_combined()`:
- Attacker: `critical_chance = 1.0`, `physical_power = 60.0`, Base damage = 40.0 -> Raw = (40 + 60) * 1.5 = 150.0
- Defender: `shield_block_value = 50.0`, `physical_resilience = 0.50`
- Expectation:
  - `raw_damage == 150.0`
  - `damage_after_block == 100.0`
  - `resistance_mitigation == 50.0`
  - `final_damage == 50.0`
  - `was_critical() == true`
  - `was_blocked == true`

```gdscript
func _test_critical_block_and_resilience_combined() -> void:
	_test_count += 1

	var attacker := _create_stats()
	var defender := _create_stats()

	attacker.critical_chance = 1.0
	attacker.physical_power = 60.0
	defender.shield_block_value = 50.0
	defender.physical_resilience = 0.50

	var attack_data := AttackData.new(40.0, DamageType.Type.PHYSICAL)
	var resolver := _create_resolver(12345)

	var result := resolver.resolve_attack(AttackRequest.new(attacker, defender, attack_data))

	_assert(result.was_critical(), "Attack is confirmed critical.")
	_assert(result.damage_result.raw_damage == 150.0, "Critical raw damage is 150.")
	_assert(result.damage_result.final_damage == 50.0, "Final damage is 50 after block and resilience.")
	_assert(result.damage_result.was_blocked, "Critical attack was blocked.")
```

- [x] **Step 2: Write minimum damage boundaries contract test**

`_test_minimum_damage_boundaries()`:
- Case A: Overwhelming block (`shield_block_value = 500.0`) against 20 raw damage -> `final_damage == DamageConstants.MIN_DAMAGE` (1.0), `mitigated_damage == 19.0`.
- Case B: Overwhelming resilience cap (0.75) against low damage -> `final_damage >= DamageConstants.MIN_DAMAGE`.
- Case C: Zero raw damage (`base_damage = 0.0, physical_power = 0.0`) -> `final_damage == 1.0`, `mitigated_damage == 0.0`.

```gdscript
func _test_minimum_damage_boundaries() -> void:
	_test_count += 1

	var attacker := _create_stats()
	var defender := _create_stats()

	attacker.physical_power = 0.0
	defender.shield_block_value = 500.0
	defender.physical_resilience = 0.75

	var attack_data := AttackData.new(10.0, DamageType.Type.PHYSICAL)
	var resolver := _create_resolver(12345)

	var result := resolver.resolve_attack(AttackRequest.new(attacker, defender, attack_data))

	_assert(result.damage_result.final_damage == DamageConstants.MIN_DAMAGE, "Excessive defense clamps to MIN_DAMAGE.")
	_assert(result.damage_result.mitigated_damage >= 0.0, "Mitigated damage is non-negative.")
```

- [x] **Step 3: Write miss does not evaluate defense test**

Verify that when an attack misses (`accuracy = 0.0`, `evasion = 1.0`, `critical_chance = 0.0`):
- `result.hit_outcome == CombatTypes.HitOutcome.MISS`
- `result.damage_result == null`
- `result.has_damage() == false`
- No block or mitigation is applied or evaluated.

- [x] **Step 4: Write stat immutability contract test**

`_test_defense_stat_immutability()`:
- Record all initial fields of `attacker` and `defender` before `resolve_attack()`.
- Execute attack.
- Assert every field of `attacker` and `defender` is strictly equal to the initial value.

```gdscript
func _test_defense_stat_immutability() -> void:
	_test_count += 1

	var attacker := _create_stats()
	var defender := _create_stats()

	attacker.accuracy = 0.85
	attacker.physical_power = 35.0
	defender.shield_block_value = 15.0
	defender.physical_resilience = 0.30

	var initial_block := defender.shield_block_value
	var initial_resilience := defender.physical_resilience
	var initial_atk_power := attacker.physical_power

	var attack_data := AttackData.new(25.0, DamageType.Type.PHYSICAL)
	var resolver := _create_resolver(12345)

	var _result := resolver.resolve_attack(AttackRequest.new(attacker, defender, attack_data))

	_assert(defender.shield_block_value == initial_block, "Defender shield_block_value unmodified.")
	_assert(defender.physical_resilience == initial_resilience, "Defender physical_resilience unmodified.")
	_assert(attacker.physical_power == initial_atk_power, "Attacker physical_power unmodified.")
```

- [x] **Step 5: Run all test suites across the project to verify 100% pass**

Run:
```powershell
& "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe" --headless -s "c:\Users\olivereld\Documents\dungeon-divers\src\gameplay\combat\tests\test_combat_defense.gd"
& "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe" --headless -s "c:\Users\olivereld\Documents\dungeon-divers\src\gameplay\combat\tests\test_combat_core.gd"
& "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe" --headless -s "c:\Users\olivereld\Documents\dungeon-divers\src\gameplay\combat\tests\test_combat_pipeline.gd"
& "C:\Users\olivereld\Documents\Godot_v4.6.1-single_win64.exe\Godot_v4.6.1-stable_win64_console.exe" --headless -s "c:\Users\olivereld\Documents\dungeon-divers\src\gameplay\combat\tests\test_damage.gd"
& "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe" --headless -s "c:\Users\olivereld\Documents\dungeon-divers\src\gameplay\stats\tests\test_stat_calculator.gd"
```
Expected: All suites PASS with 0 failures.

- [x] **Step 6: Commit**

```bash
git add src/gameplay/combat/tests/test_combat_defense.gd
git commit -m "test(combat): finalize Defense v1 contract test suite"
```
