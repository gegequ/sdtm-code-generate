# IE Domain — Variable Derivation Specification
> Study: QLC7401-303 | Domain: IE | Date: 2026-06-10

## Source Data

| Source | Type | Key Columns Used |
|--------|------|------------------|
| raw.IE | EDC CRF | IEYN, IECAT, IETESTCD, VISITNAME, SUBJID |
| sdtm.dm | SDTM (pre-generated) | STUDYID, USUBJID, SUBJID |
| SDTM Spec → IETEST sheet | Mapping | IETESTCD, IETEST, IESPID, IECAT (B), IE_META (G) |
| SDTM Spec → VISIT sheet | Mapping | VISIT (C), VISITNUM (D) |
| raw.ENROL | EDC CRF | RANDDAT (for PROVER) |
| raw.IC | EDC CRF | RFICDAT, IC1DAT, PROVER, PRO1VER (for PROVER) |

---

## Variable Derivation

### STUDYID
- **SDTM Type**: Char 20
- **Core**: 必需
- **Derivation**: `sdtm.dm.STUDYID`
- **Source trace**: `sdtm.dm` → `STUDYID`

### DOMAIN
- **SDTM Type**: Char 2
- **Core**: 必需
- **Derivation**: Fixed `"IE"`
- **Source trace**: Hardcoded

### USUBJID
- **SDTM Type**: Char 30
- **Core**: 必需
- **Derivation**: `sdtm.dm.USUBJID`
- **Source trace**: `sdtm.dm` → `USUBJID`

### IESEQ
- **SDTM Type**: Num
- **Core**: 必需
- **Derivation**: 按 STUDYID, USUBJID, IECAT, IETESTCD 排序，每个 USUBJID 从 1 递增
- **Source trace**: Computed in data step (retain counter)

### IESPID
- **SDTM Type**: Char 25
- **Core**: 可有
- **Derivation**: IETEST sheet column C (IESPID)
- **Source trace**: `SDTM Spec → IETEST sheet → Col C`

### IETESTCD
- **SDTM Type**: Char 8
- **Core**: 必需
- **Derivation**: IETEST sheet column D (IETESTCD), matched via cat1+cat2 positional join
- **Source trace**: `SDTM Spec → IETEST sheet → Col D`
- **Mapping logic**: raw.IETESTCD → extract cat1+cat2 → join IETEST sheet by IECAT+cat1+cat2 → get SDTM IETESTCD

### IETEST
- **SDTM Type**: Char 200
- **Core**: 必需
- **Derivation**: IETEST sheet column E (IETEST)
- **Source trace**: `SDTM Spec → IETEST sheet → Col E`

### IECAT
- **SDTM Type**: Char 100
- **Core**: 必需
- **Derivation**: raw IE.IECAT (stored as Chinese text: "入选标准" / "排除标准")
- **Source trace**: `raw.IE` → `IECAT`

### IEORRES
- **SDTM Type**: Char 10
- **Core**: 必需
- **Derivation**: 
  - 当 IECAT="入选标准" → `"否"`
  - 当 IECAT="排除标准" → `"是"`
- **Source trace**: Computed from IECAT

### IESTRESC
- **SDTM Type**: Char 10
- **Core**: 必需
- **Derivation**: `= IEORRES`
- **Source trace**: Computed

### VISITNUM
- **SDTM Type**: Num
- **Core**: 可有
- **Derivation**: VISIT sheet column D (VISITNUM), joined by raw VISITNAME
- **Source trace**: `raw.IE` → `VISITNAME` → `SDTM Spec → VISIT sheet → Col C (VISIT) match → Col D (VISITNUM)`

### VISIT
- **SDTM Type**: Char 100
- **Core**: 可有
- **Derivation**: VISIT sheet column C (VISIT), joined by raw VISITNAME
- **Source trace**: `raw.IE` → `VISITNAME` → `SDTM Spec → VISIT sheet → Col C (VISIT)`

### PROVER (supplementary, not in SDTM IE core)
- **Derivation**: Complex logic based on IC dates vs randomization date
  - If RANDDAT present and RFICDAT ≤ RANDDAT < IC1DAT → use PROVER
  - If RANDDAT present and RFICDAT ≤ RANDDAT ≥ IC1DAT → use PRO1VER
  - If RANDDAT missing and IC1DAT > RFICDAT → use PRO1VER
  - Otherwise → use PROVER
- **Source trace**: `raw.IC` (RFICDAT, IC1DAT, PROVER, PRO1VER) + `raw.ENROL` (RANDDAT)

---

## Filter Logic

| Condition | Rationale |
|-----------|-----------|
| `IEYN = "否"` | 仅保留不满足入选/排除标准的记录（Spec: IE.IEYN='2'，实际raw存储中文"是"/"否"） |
| `IECAT ne "" and IETESTCD ne ""` | 排除空记录 |

---

## Join Flow

```
raw.IE (_ie0)
  │ filter IEYN="否", extract cat1/cat2 from IETESTCD
  ▼
ie01
  │ left join IETEST sheet (on IECAT + cat1 + cat2)
  │ left join sdtm.dm (on SUBJID)
  │ left join raw.ENROL (on SUBJID)
  │ left join raw.IC (on SUBJID)
  ▼
ie02
  │ left join VISIT sheet (on VISITNAME)
  ▼
ie03 → %ut_output_sdtm
```
