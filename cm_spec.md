# CM Domain — Variable Derivation Specification
> Study: QLC7401-303 | Domain: CM | Date: 2026-06-10

## Source Data

| Source | Type | Key Columns Used |
|--------|------|------------------|
| raw.CM | EDC CRF (单表) | CMTRT, SN, CMSTDAT, CMENDAT, CMINDC, CMDSTXT, CMDOSU, CMDOSFRM, CMDOSFRQ, CMROUTE, CMONGO, CMAENO, CMMHNO, CMINPL, CMINOTH, CMDOSUO, CMFRMOTH, CMFRQOTH, CMROUTEO, SUBJID, TNAME |
| sdtm.dm | SDTM (pre-generated) | STUDYID, USUBJID, SUBJID |
| WHODrug外部编码 | xlsx → sheet "WhoDrug编码明细" | 首选语, ATC2名称/编码, ATC4名称/编码, 词典名称+版本 |

---

## Variable Derivation

### STUDYID
- **SDTM Type**: Char 20 | **Core**: 必需
- **Derivation**: `sdtm.dm.STUDYID`
- **Source trace**: `sdtm.dm` → `STUDYID`

### DOMAIN
- **SDTM Type**: Char 2 | **Core**: 必需
- **Derivation**: Fixed `"CM"`

### USUBJID
- **SDTM Type**: Char 30 | **Core**: 必需
- **Derivation**: `sdtm.dm.USUBJID`
- **Source trace**: `sdtm.dm` → `USUBJID`

### CMSEQ
- **SDTM Type**: Num | **Core**: 必需
- **Derivation**: `%ut_output_sdtm` 内部自动生成（不手写）

### CMSPID
- **SDTM Type**: Char 25 | **Core**: 可有
- **Derivation**: `put(raw.CM.SN, best.)`
- **Source trace**: `raw.CM` → `SN` (num)

### CMTRT
- **SDTM Type**: Char 200 | **Core**: 必需
- **Derivation**: `strip(raw.CM.CMTRT)`
- **Source trace**: `raw.CM` → `CMTRT`

### CMDECOD
- **SDTM Type**: Char 200 | **Core**: 可有
- **Derivation**: WHODrug 外部文件 — join on SUBJID+TNAME+SN+CMTRT → 取首选语
- **Source trace**: `&whodrug.` → `WhoDrug编码明细` sheet → Col J (首选语)

### CMCAT
- **SDTM Type**: Char 100 | **Core**: 可有
- **Derivation**: Fixed `"既往及合并用药"`
- **Source trace**: Hardcoded per Spec

### CMINDC
- **SDTM Type**: Char 100 | **Core**: 可有
- **Derivation**: `strip(raw.CM.CMINDC)`
- **Source trace**: `raw.CM` → `CMINDC` (char 300, text field)

### CMDOSTXT
- **SDTM Type**: Char 100 | **Core**: 可有
- **Derivation**: `strip(raw.CM.CMDSTXT)`
- **Source trace**: `raw.CM` → `CMDSTXT`

### CMDOSU
- **SDTM Type**: Char 20 | **Core**: 可有
- **Derivation**: raw.CM.CMDOSU 编码解码 → 毫克/克/毫升/微克/国际单位/其他
- **Source trace**: `raw.CM` → `CMDOSU` → 数据库编码 (CM组/CMDOSU名)

### CMDOSFRM
- **SDTM Type**: Char 20 | **Core**: 可有
- **Derivation**: raw.CM.CMDOSFRM 编码解码 → 片剂/胶囊剂/注射剂/...
- **Source trace**: `raw.CM` → `CMDOSFRM` → 数据库编码 (CM组/CMDOSFRM名, 21种)

### CMDOSFRQ
- **SDTM Type**: Char 20 | **Core**: 可有
- **Derivation**: raw.CM.CMDOSFRQ 编码解码 → qd/bid/tid/...
- **Source trace**: `raw.CM` → `CMDOSFRQ` → 数据库编码 (CM组/CMDOSFRQ名, 13种)

### CMROUTE
- **SDTM Type**: Char 20 | **Core**: 可有
- **Derivation**: raw.CM.CMROUTE 编码解码 → 口服/皮下注射/静脉滴注/...
- **Source trace**: `raw.CM` → `CMROUTE` → 数据库编码 (CM组/CMROUTE名, 14种)

### CMSTDTC
- **SDTM Type**: Char 20 | **Core**: 可有
- **Derivation**: `%ut_iso8601(raw.CM.CMSTDAT)` — CMSTDAT 已是 char(len=20)
- **Source trace**: `raw.CM` → `CMSTDAT`

### CMENDTC
- **SDTM Type**: Char 20 | **Core**: 可有
- **Derivation**: `%ut_iso8601(raw.CM.CMENDAT)` — CMENDAT 已是 char(len=20)
- **Source trace**: `raw.CM` → `CMENDAT`

### SUPPQUAL variables (kept in main domain)

| Variable | Source | Derivation |
|----------|--------|-----------|
| CMAENO | raw.CM.CMAENO | strip() |
| CMMHNO | raw.CM.CMMHNO | strip() |
| CMINPL | raw.CM.CMINPL | strip() |
| CMINOTH | raw.CM.CMINOTH | strip() |
| CMDOSUO | raw.CM.CMDOSUO | strip() |
| CMFRMOTH | raw.CM.CMFRMOTH | strip() |
| CMFRQOTH | raw.CM.CMFRQOTH | strip() |
| CMROUTEO | raw.CM.CMROUTEO | strip() |
| CMONGO | raw.CM.CMONGO | strip() |
| ATC2 | WHODrug外部 | Col L (ATC2名称) |
| ATC2CD | WHODrug外部 | Col M (ATC2编码) |
| ATC4 | WHODrug外部 | Col N (ATC4名称) |
| ATC4CD | WHODrug外部 | Col O (ATC4编码) |
| CMDVER | WHODrug外部 | Col R (词典名称) + Col S (词典版本) |

---

## Join Flow

```
raw.CM (_cm0)
  │ %ut_remove_formats
  ▼
cm_raw
  │ left join WHODrug外部 (on SUBJID + TNAME + SN + CMTRT)
  ▼
cm_whodrug
  │ left join sdtm.dm (on SUBJID)
  ▼
cm_dm
  │ decode CMDOSU/CMDOSFRM/CMDOSFRQ/CMROUTE
  │ %ut_iso8601 on CMSTDAT/CMENDAT
  ▼
cm_derived → %ut_output_sdtm
```

## ⚠️ WHODrug 列映射说明

WHODrug 外部编码文件列映射（按 `references/style.md` 标准结构）：

| 列 | 内容 | SAS变量 | 用于 |
|----|------|---------|------|
| C | SUBJID | subjid | join key |
| D | 表名称 | tname | join key |
| E | SN | sn_num | join key |
| F | SPID | spid | join key |
| G | 逐词术语 | cmtrt_term | join key |
| J | 首选语 | prefcname | → CMDECOD |
| L | ATC2名称 | atc2name | → ATC2 (SUPP) |
| M | ATC2编码 | atc2code | → ATC2CD (SUPP) |
| N | ATC4名称 | atc4name | → ATC4 (SUPP) |
| O | ATC4编码 | atc4code | → ATC4CD (SUPP) |
| R | 词典名称 | dictname | → CMDVER (SUPP) |
| S | 词典版本 | dictver | → CMDVER (SUPP) |

> ⚠️ 列字母为预估，收到实际 WHODrug 文件后需调整 `data whodrug` 步的列映射。
