/*********************************************************
***  QILU PHARMACUETICAL LTD
***  Study:  QLC7401-303
***  Program: ie.sas
***  Programmer: SDTM Code Gen
***  Date: 2026-02-09
***  Description: Generation for SDTM.IE
**********************************************************
***  Macros called:
***    %ut_remove_formats
***    %ut_output_sdtm
**********************************************************
***  MODIFICATIONS:
***    2026-02-09  Initial version
*********************************************************/

proc datasets lib=work memtype=data kill nolist;
run;

/* ═══════════════════════════════════════════════════════
   Step 1: Import IETEST mapping from SDTM Spec
   ═══════════════════════════════════════════════════════ */
proc import datafile="document/7401-303/QLC7401-303 SDTM Datasets Programming Specifications.xlsx"
    out=ietest_spec
    dbms=xlsx
    replace;
    sheet="IETEST";
    getnames=no;
    datarow=2;
run;

/* Parse IETEST spec: extract raw IETESTCD from Conversion Definition */
data ietest_map;
    set ietest_spec;
    length sdtm_iecat $100 sdtm_iespid $10 sdtm_ietestcd $8 sdtm_ietest $200 raw_ietestcd $10;

    sdtm_iecat    = strip(B);
    sdtm_iespid   = strip(C);
    sdtm_ietestcd = strip(D);
    sdtm_ietest   = strip(E);

    /* Extract raw code from Conversion Definition column F:
       e.g. "[RAW]CM.CMTESTCD=""INCL01""" → "INCL01"
            "[RAW]CM.CMTESTCD=""EXCL01""" → "EXCL01" */
    raw_ietestcd = strip(F);
    /* Remove prefix and quotes */
    raw_ietestcd = tranwrd(raw_ietestcd, '[RAW]CM.CMTESTCD="', '');
    raw_ietestcd = tranwrd(raw_ietestcd, '"', '');
    raw_ietestcd = strip(raw_ietestcd);

    if raw_ietestcd ne "" and sdtm_ietestcd ne "";
    keep sdtm_iecat sdtm_iespid sdtm_ietestcd sdtm_ietest raw_ietestcd;
run;

proc sort data=ietest_map;
    by raw_ietestcd;
run;

/* ═══════════════════════════════════════════════════════
   Step 2: Extract raw IE data
   ═══════════════════════════════════════════════════════ */
%ut_remove_formats(lib=raw, dsin=IE, dsout=_ie0);

/* IE has parent-child structure via SUBTRID/CSN.
   Parent: IEYN (overall yes/no), SUBTRID
   Child:  IECAT, IETESTCD for each failed criterion
   Filter: only subjects where IEYN='2' (not met) */
data ie_raw;
    set _ie0;
    length ieyn_clean $5 iecat_raw $5 ietestcd_raw $10;
    ieyn_clean    = strip(IEYN);
    iecat_raw     = strip(IECAT);
    ietestcd_raw  = strip(IETESTCD);

    /* Keep only records with a criterion (child records or parent with child data) */
    if iecat_raw ne "" and ietestcd_raw ne "" then do;
        keep SID SUBJID ieyn_clean iecat_raw ietestcd_raw;
    end;
    /* Also keep parent record IEYN for filtering per subject */
    else if ieyn_clean ne "" then do;
        keep SID SUBJID ieyn_clean iecat_raw ietestcd_raw;
    end;
    else delete;
run;

/* Get list of subjects where IEYN='2' (not meeting all criteria) */
proc sql;
    create table ie_subj as
    select distinct SID
    from ie_raw
    where ieyn_clean = "2";
quit;

/* Filter child records for those subjects */
proc sql;
    create table ie_child as
    select a.SID, a.SUBJID, a.iecat_raw, a.ietestcd_raw
    from ie_raw a, ie_subj b
    where a.SID = b.SID
      and a.iecat_raw ne ""
      and a.ietestcd_raw ne "";
quit;

/* ═══════════════════════════════════════════════════════
   Step 3: Join with IETEST mapping to get SDTM codes
   ═══════════════════════════════════════════════════════ */
proc sql;
    create table ie_mapped as
    select a.*,
           b.sdtm_iecat,
           b.sdtm_iespid,
           b.sdtm_ietestcd,
           b.sdtm_ietest
    from ie_child a
    left join ietest_map b
        on a.ietestcd_raw = b.raw_ietestcd;
quit;

/* ═══════════════════════════════════════════════════════
   Step 4: Join with DM for STUDYID, USUBJID
   ═══════════════════════════════════════════════════════ */
/* Build DM lookup from raw SUBJECT */
%ut_remove_formats(lib=raw, dsin=SUBJECT, dsout=_subj_ie);

data dm_lookup;
    set _subj_ie;
    length STUDYID $20 USUBJID $30;
    STUDYID = strip(STUDYID);
    USUBJID = catx('-', STUDYID, strip(SITEID), strip(SUBJID));
    keep SID STUDYID USUBJID SUBJID SITEID;
run;

proc sort data=dm_lookup; by SID; run;
proc sort data=ie_mapped; by SID; run;

data ie_with_dm;
    merge ie_mapped(in=a) dm_lookup(in=b);
    by SID;
    if a and b;
run;

/* ═══════════════════════════════════════════════════════
   Step 5: Derive IE variables
   ═══════════════════════════════════════════════════════ */
proc sort data=ie_with_dm;
    by USUBJID sdtm_iecat sdtm_ietestcd;
run;

data ie_derived;
    set ie_with_dm;
    by USUBJID;

    length DOMAIN $2 IESPID $25 IETESTCD $8 IETEST $200
           IECAT $100 IEORRES $10 IESTRESC $10
           VISITNUM 8 VISIT $100;

    DOMAIN = "IE";

    /* SDTM IETESTCD — use mapped value, fallback to raw */
    if sdtm_ietestcd ne "" then IETESTCD = sdtm_ietestcd;
    else IETESTCD = ietestcd_raw;

    /* SDTM IETEST — use mapped value */
    if sdtm_ietest ne "" then IETEST = sdtm_ietest;
    else IETEST = "";

    /* SDTM IESPID */
    if sdtm_iespid ne "" then IESPID = sdtm_iespid;
    else IESPID = "";

    /* IECAT: decode from raw (1=入选标准, 2=排除标准) or use mapped */
    if sdtm_iecat ne "" then IECAT = sdtm_iecat;
    else if iecat_raw = "1" then IECAT = "入选标准";
    else if iecat_raw = "2" then IECAT = "排除标准";

    /* IEORRES: 入选标准=否, 排除标准=是 */
    if IECAT = "入选标准" then IEORRES = "否";
    else if IECAT = "排除标准" then IEORRES = "是";

    /* IESTRESC = IEORRES */
    IESTRESC = IEORRES;

    /* VISIT: IE collected at screening */
    VISITNUM = 1;
    VISIT    = "筛选期V1";

    keep STUDYID DOMAIN USUBJID IESPID IETESTCD IETEST IECAT
         IEORRES IESTRESC VISITNUM VISIT;
run;

/* ═══════════════════════════════════════════════════════
   Step 6: Output SDTM dataset
   ═══════════════════════════════════════════════════════ */
%ut_output_sdtm(domain=IE, dsin=ie_derived);

proc printto; run;
