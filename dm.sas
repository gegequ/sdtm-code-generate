/*********************************************************
***  QILU PHARMACUETICAL LTD
***  Study:  QLC7401-303
***  Program: dm.sas
***  Programmer: SDTM Code Gen
***  Date: 2026-02-09
***  Description: Generation for SDTM.DM
**********************************************************
***  Macros called:
***    %ut_remove_formats
***    %ut_iso8601
***    %ut_dy
***    %ut_output_sdtm
**********************************************************
***  MODIFICATIONS:
***    2026-02-09  Initial version
*********************************************************/

proc datasets lib=work memtype=data kill nolist;
run;

/* ═══════════════════════════════════════════════════════
   Step 1: Import randomization list
   ═══════════════════════════════════════════════════════ */
proc import datafile="document/7401-303/QLC7401-303_RandomizationList_区组大小为6_Test1.0_07JAN26.csv"
    out=randlist
    dbms=csv
    replace;
    getnames=no;
    datarow=3;
run;

data randlist;
    set randlist;
    length randno $20 arm_group $200 armcd_tmp $20;
    randno    = strip(A);
    arm_group = strip(H);
    armcd_tmp = strip(G);
    keep randno arm_group armcd_tmp;
    where randno ne "";
run;

proc sort data=randlist;
    by randno;
run;

/* ═══════════════════════════════════════════════════════
   Step 2: Extract raw datasets — remove formats
   ═══════════════════════════════════════════════════════ */
%ut_remove_formats(lib=raw, dsin=SUBJECT, dsout=_subj);
%ut_remove_formats(lib=raw, dsin=DM,      dsout=_dm0);
%ut_remove_formats(lib=raw, dsin=ENROL,   dsout=_enrol);
%ut_remove_formats(lib=raw, dsin=DISP,    dsout=_disp);
%ut_remove_formats(lib=raw, dsin=EX,      dsout=_ex0);
%ut_remove_formats(lib=raw, dsin=IC,      dsout=_ic0);
%ut_remove_formats(lib=raw, dsin=DS,      dsout=_ds0);
%ut_remove_formats(lib=raw, dsin=AE,      dsout=_ae0);
%ut_remove_formats(lib=raw, dsin=EOT,     dsout=_eot0);

/* ═══════════════════════════════════════════════════════
   Step 3: SUBJECT → core demographics
   ═══════════════════════════════════════════════════════ */
data subj_info;
    set _subj;
    length STUDYID $20 USUBJID $30 SUBJID $8 SITEID $4 INVID $20 INVNAM $100 COUNTRY $6;
    STUDYID = strip(STUDYID);
    SUBJID  = strip(SUBJID);
    SITEID  = strip(SITEID);
    INVID   = strip(SITEID);          /* INVID = SITEID per spec */
    INVNAM  = strip(INVNAM);
    COUNTRY = "中国";
    USUBJID = catx('-', STUDYID, SITEID, SUBJID);

    /* SUPP variables from SUBJECT */
    length _sitename $200 _supp_siteid $200 _supp_invnam $200;
    _sitename    = strip(SITENAME);
    _supp_siteid = strip(SITEID);
    _supp_invnam = strip(INVNAM);

    keep SID STUDYID USUBJID SUBJID SITEID INVID INVNAM COUNTRY
         _sitename _supp_siteid _supp_invnam;
run;

proc sort data=subj_info;
    by SID;
run;

/* ═══════════════════════════════════════════════════════
   Step 4: DM (raw) → BRTHDTC, AGE, SEX, ETHNICC, etc.
   ═══════════════════════════════════════════════════════ */
data dm_info;
    set _dm0(rename=(AGE=_age_char));
    length BRTHDTC $20 AGE 8 AGEU $6 SEX $6;
    /* BRTHDAT is num → put to char → %ut_iso8601 */
    length _brthdat_c $10;
    if not missing(BRTHDAT) then _brthdat_c = put(BRTHDAT, yymmdd10.);
    %ut_iso8601(datevar=_brthdat_c, dtcvar=BRTHDTC);

    /* AGE is char → input to num */
    if not missing(_age_char) then AGE = input(_age_char, ??best.);
    else AGE = .;
    AGEU = "岁";

    /* SEX: encoded 1=男→M, 2=女→F */
    if SEX = "1" then SEX = "M";
    else if SEX = "2" then SEX = "F";

    /* SUPP variables from DM */
    length _ethnicc $200 _ethnoth $200 _rpyn $200 _rpreas $200;
    /* ETHNICC: 1=汉族, 99=其他 */
    if ETHNICC = "1" then _ethnicc = "汉族";
    else if ETHNICC = "99" then _ethnicc = "其他";
    else _ethnicc = strip(ETHNICC);

    _ethnoth = strip(ETHNICCO);
    _rpyn    = strip(RPYN);
    _rpreas  = strip(RPREAS);

    keep SID BRTHDTC AGE AGEU SEX _ethnicc _ethnoth _rpyn _rpreas;
run;

/* ═══════════════════════════════════════════════════════
   Step 5: ENROL → RANDYN, RAND_ID for ARM derivation
   ═══════════════════════════════════════════════════════ */
data enrol_info;
    set _enrol;
    length enrol_randyn $5 enrol_rand_id $10;
    enrol_randyn  = strip(RANDYN);
    enrol_rand_id = strip(RAND_ID);
    keep SID enrol_randyn enrol_rand_id;
run;

/* ═══════════════════════════════════════════════════════
   Step 6: DISP → DISPLOT for ACTARM derivation
   ⚠️ KitList CSV 缺失，ACTARM 暂用随机列表推导
   ═══════════════════════════════════════════════════════ */
proc sort data=_disp;
    by SID DISPDAT;
run;

data disp_info;
    set _disp;
    by SID;
    length disp_lot $200;
    disp_lot = strip(DISPLOT);
    keep SID disp_lot DISPDAT;
run;

/* ═══════════════════════════════════════════════════════
   Step 7: EX → RFSTDTC, RFENDTC
   ═══════════════════════════════════════════════════════ */
data ex_dates;
    set _ex0;
    length _exstdtc $20 _exendtc $20;

    /* EXSTDAT is num → put to char */
    length _exstdat_c $10;
    if not missing(EXSTDAT) then _exstdat_c = put(EXSTDAT, yymmdd10.);

    /* EXSTTIM is num → put to char time */
    length _exsttim_c $8;
    if not missing(EXSTTIM) then _exsttim_c = put(EXSTTIM, hhmm8.);

    %ut_iso8601(datevar=_exstdat_c, timevar=_exsttim_c, dtcvar=_exstdtc);

    /* For RFENDTC: EXENDTC not collected per raw, use EXSTDTC as end */
    _exendtc = _exstdtc;

    keep SID _exstdtc _exendtc;
run;

proc sort data=ex_dates;
    by SID _exstdtc;
run;

data ex_summary;
    set ex_dates;
    by SID;
    length RFSTDTC RFENDTC RFXSTDTC RFXENDTC $20;
    retain RFSTDTC RFENDTC;

    if first.SID then do;
        RFSTDTC = "";
        RFENDTC = "";
    end;

    /* First non-missing EXSTDTC = RFSTDTC */
    if RFSTDTC = "" and _exstdtc ne "" then RFSTDTC = _exstdtc;

    /* Last non-missing EXSTDTC/EXENDTC = RFENDTC */
    if _exendtc ne "" then RFENDTC = _exendtc;
    else if _exstdtc ne "" then RFENDTC = _exstdtc;

    if last.SID then do;
        /* If RFSTDTC is empty, RFENDTC should also be empty */
        if RFSTDTC = "" then RFENDTC = "";
        RFXSTDTC = RFSTDTC;
        RFXENDTC = RFENDTC;
        output;
    end;
    keep SID RFSTDTC RFENDTC RFXSTDTC RFXENDTC;
run;

/* ═══════════════════════════════════════════════════════
   Step 8: IC → RFICDTC (earliest non-missing among RFICDAT, IC1DAT)
   ═══════════════════════════════════════════════════════ */
data ic_all;
    set _ic0;

    length _icdatc $20;
    /* RFICDAT is num → put to char */
    length _rficdat_c $10;
    if not missing(RFICDAT) then _rficdat_c = put(RFICDAT, yymmdd10.);
    %ut_iso8601(datevar=_rficdat_c, dtcvar=_icdatc);
    output;

    /* IC1DAT from sub-table: also num → put to char */
    if not missing(IC1DAT) then do;
        length _ic1dat_c $10;
        _ic1dat_c = put(IC1DAT, yymmdd10.);
        %ut_iso8601(datevar=_ic1dat_c, dtcvar=_icdatc);
        output;
    end;
    keep SID _icdatc;
run;

proc sort data=ic_all;
    by SID _icdatc;
run;

data ic_summary;
    set ic_all;
    by SID;
    length RFICDTC $20;
    retain RFICDTC;
    if first.SID then RFICDTC = "";
    /* Take earliest non-missing date */
    if RFICDTC = "" and _icdatc ne "" then RFICDTC = _icdatc;
    if last.SID then output;
    keep SID RFICDTC;
run;

/* ═══════════════════════════════════════════════════════
   Step 9: DS → DSDAT, DSREAS (for DTHDTC & RFPENDTC)
   ═══════════════════════════════════════════════════════ */
data ds_info;
    set _ds0;
    length _dsdatc $20 dsreas_clean $5;
    dsreas_clean = strip(DSREAS);
    /* DSDAT is char(len=20), may already be ISO8601 or date string */
    if not missing(DSDAT) then do;
        %ut_iso8601(datevar=DSDAT, dtcvar=_dsdatc);
    end;
    keep SID _dsdatc dsreas_clean;
run;

/* ═══════════════════════════════════════════════════════
   Step 10: AE → AEOUT, AEENDAT (for DTHDTC)
   ═══════════════════════════════════════════════════════ */
data ae_dth;
    set _ae0;
    length _aeendtc $20 aeout_clean $5;
    aeout_clean = strip(AEOUT);
    /* AEENDAT is char(len=20) */
    if not missing(AEENDAT) then do;
        %ut_iso8601(datevar=AEENDAT, dtcvar=_aeendtc);
    end;
    keep SID _aeendtc aeout_clean;
run;

/* ═══════════════════════════════════════════════════════
   Step 11: EOT → EOTDAT (for RFPENDTC)
   ═══════════════════════════════════════════════════════ */
data eot_dates;
    set _eot0;
    length _eotdatc $20;
    if not missing(EOTDAT) then do;
        %ut_iso8601(datevar=EOTDAT, dtcvar=_eotdatc);
    end;
    keep SID _eotdatc;
run;

/* ═══════════════════════════════════════════════════════
   Step 12: MERGE all sub-domain info by SID
   ═══════════════════════════════════════════════════════ */
proc sort data=subj_info;   by SID; run;
proc sort data=dm_info;     by SID; run;
proc sort data=enrol_info;  by SID; run;
proc sort data=disp_info;   by SID; run;
proc sort data=ex_summary;  by SID; run;
proc sort data=ic_summary;  by SID; run;
proc sort data=ds_info;     by SID; run;
proc sort data=ae_dth;      by SID; run;
proc sort data=eot_dates;   by SID; run;

/* Merge all into dm_pre */
data dm_pre;
    merge subj_info  (in=a)
          dm_info    (in=b)
          enrol_info (in=c)
          disp_info  (in=d)
          ex_summary (in=e)
          ic_summary (in=f)
          ds_info    (in=g)
          ae_dth     (in=h)
          eot_dates  (in=i);
    by SID;
    if a;
run;

/* ═══════════════════════════════════════════════════════
   Step 13: Derive ARM, ACTARM, ARMNRS
   ═══════════════════════════════════════════════════════ */
proc sort data=dm_pre;
    by enrol_rand_id;
run;

data dm_arm;
    merge dm_pre(in=a) randlist(in=b rename=(randno=enrol_rand_id));
    by enrol_rand_id;
    if a;

    length ARM $100 ARMCD $20 ACTARM $100 ACTARMCD $20 ARMNRS $100;

    /* --- ARM / ARMCD derivation --- */
    if enrol_randyn = "1" then do;  /* 1=是 → randomized */
        if arm_group = "QLC7401 300mg组" then do;
            ARM   = "QLC7401";
            ARMCD = "QLC7401";
        end;
        else if arm_group = "QLC7401 300mg安慰剂组" then do;
            ARM   = "安慰剂组";
            ARMCD = "PLACEBO";
        end;
        else do;
            ARM   = "";
            ARMCD = "";
        end;
    end;
    else if enrol_randyn = "2" then do;  /* 2=否 → screen failure */
        ARM   = "";
        ARMCD = "";
    end;
    else do;  /* missing → not assigned */
        ARM   = "";
        ARMCD = "";
    end;

    /* --- ACTARM / ACTARMCD derivation --- */
    /* ⚠️ KitList CSV 缺失，暂以随机列表 + RFSTDTC 推导:
       已随机 + 已给药 → ACTARM = ARM; 否则为空 */
    if enrol_randyn = "2" then do;  /* not randomized */
        ACTARM   = "";
        ACTARMCD = "";
    end;
    else if enrol_randyn = "" then do;  /* missing */
        ACTARM   = "";
        ACTARMCD = "";
    end;
    else if enrol_randyn = "1" and RFSTDTC = "" then do;  /* randomized but not treated */
        ACTARM   = "";
        ACTARMCD = "";
    end;
    else if enrol_randyn = "1" and RFSTDTC ne "" then do;  /* randomized and treated */
        ACTARM   = ARM;
        ACTARMCD = ARMCD;
    end;

    /* --- ARMNRS derivation --- */
    if ARM = "" and enrol_randyn = "2" then
        ARMNRS = "SCREEN FAILURE";
    else if ARM = "" and enrol_randyn = "" then
        ARMNRS = "NOT ASSIGNED";
    else if ACTARM = "" and enrol_randyn = "1" and RFSTDTC = "" then
        ARMNRS = "ASSIGNED, NOT TREATED";
    else
        ARMNRS = "";

    drop arm_group armcd_tmp;
run;

/* ═══════════════════════════════════════════════════════
   Step 14: Derive DTHDTC, DTHFL
   ═══════════════════════════════════════════════════════ */
data dm_dth;
    set dm_arm;
    length DTHDTC $20 DTHFL $3;

    /* DSREAS=4 → 参与者死亡 → DTHDTC from DS.DSDAT */
    if dsreas_clean = "4" and _dsdatc ne "" then
        DTHDTC = _dsdatc;

    /* AEOUT=5 → 死亡 → DTHDTC from AE.AEENDAT */
    if aeout_clean = "5" and _aeendtc ne "" then do;
        /* Take AE date only if DS didn't already set it, or if AE is later */
        if DTHDTC = "" then DTHDTC = _aeendtc;
        else if _aeendtc > DTHDTC then DTHDTC = _aeendtc;
    end;

    if DTHDTC ne "" then DTHFL = "Y";
    else DTHFL = "";
run;

/* ═══════════════════════════════════════════════════════
   Step 15: Derive RFPENDTC
   遍历所有采集的日期变量取最大值（排除DS失访情况）
   ⚠️ 当前仅从已读取数据集的日期变量中取 max;
   如需完整实现，应扩展至全部 raw 数据集
   ═══════════════════════════════════════════════════════ */
data dm_rfp;
    set dm_dth;
    length RFPENDTC $20;

    /* Collect all candidate dates */
    /* Exclude DS.DSDAT when DSREAS=5 (participant lost to follow-up) */
    if dsreas_clean ne "5" and _dsdatc > RFPENDTC then
        RFPENDTC = _dsdatc;

    /* EOT date */
    if _eotdatc > RFPENDTC then
        RFPENDTC = _eotdatc;

    /* AE end date */
    if _aeendtc > RFPENDTC then
        RFPENDTC = _aeendtc;

    /* RFENDTC (last dose) */
    if RFENDTC > RFPENDTC then
        RFPENDTC = RFENDTC;

    /* ⚠️ Additional raw datasets NOT yet included (add as needed):
       LB.LBDAT, VS.VSDAT, EG.EGDAT, PE.PEDAT, CM.CMSTDAT/CMENDAT,
       MH.MHSTDAT/MHENDAT, PR.PRSTDAT/PRENDAT, SU.SUDAT, etc. */
run;

/* ═══════════════════════════════════════════════════════
   Step 16: Final DM dataset assembly
   ═══════════════════════════════════════════════════════ */
data dm_final;
    set dm_rfp;

    length DOMAIN $2 RACE $20;

    DOMAIN = "DM";
    RACE   = "亚裔";   /* per spec: fixed value */

    /* Standard SDTM variable order */
    keep STUDYID DOMAIN USUBJID SUBJID RFSTDTC RFENDTC RFXSTDTC RFXENDTC
         RFICDTC RFPENDTC DTHDTC DTHFL
         SITEID INVID INVNAM BRTHDTC AGE AGEU SEX RACE
         ARMCD ARM ACTARMCD ACTARM ARMNRS COUNTRY
         /* SUPPQUAL variables — %ut_output_sdtm auto-splits */
         _sitename _supp_siteid _supp_invnam
         _ethnicc _ethnoth _rpyn _rpreas;

    label
        STUDYID  = "研究标识符"
        DOMAIN   = "域名缩写"
        USUBJID  = "受试者唯一标识符"
        SUBJID   = "受试者标识符"
        RFSTDTC  = "受试者参照开始日期/时间"
        RFENDTC  = "受试者参照结束日期/时间"
        RFXSTDTC = "首次研究治疗日期/时间"
        RFXENDTC = "末次研究治疗日期/时间"
        RFICDTC  = "知情同意日期/时间"
        RFPENDTC = "参与结束日期/时间"
        DTHDTC   = "死亡日期/时间"
        DTHFL    = "死亡标帜"
        SITEID   = "研究中心标识符"
        INVID    = "研究者标识符"
        INVNAM   = "研究者姓名"
        BRTHDTC  = "出生日期/时间"
        AGE      = "年龄"
        AGEU     = "年龄单位"
        SEX      = "性别"
        RACE     = "种族"
        ARMCD    = "计划分组编码"
        ARM      = "计划分组描述"
        ACTARMCD = "实际分组编码"
        ACTARM   = "实际分组描述"
        ARMNRS   = "分组/实际分组为空描述"
        COUNTRY  = "国家"
    ;
run;

/* ═══════════════════════════════════════════════════════
   Step 17: Output SDTM dataset
   ═══════════════════════════════════════════════════════ */
%ut_output_sdtm(domain=DM, dsin=dm_final);

proc printto; run;
