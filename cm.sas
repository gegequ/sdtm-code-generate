/*********************************************************
***  QILU PHARMACUETICAL LTD
***  Study:  QLC7401-303
***  Program: cm.sas
***  Programmer: SDTM Code Gen
***  Date: 2026-06-10
***  Description: Generation for SDTM.CM
**********************************************************
***  Macros called:
***    %ut_remove_formats
***    %ut_iso8601
***    %ut_dy
***    %ut_output_sdtm
**********************************************************
***  MODIFICATIONS:
***    2026-06-10  Initial version
*********************************************************/

proc datasets lib=work memtype=data kill nolist;
run;

proc import datafile="&whodrug."
    out=whodrug0
    dbms=xlsx
    replace;
    sheet="WhoDrug编码明细";
    getnames=no;
run;

data whodrug;
    set whodrug0;
    length subjid $30 tname $200 sn_num 8 spid $25 cmtrt_term $200
           prefcname $200 atc2name $200 atc2code $200
           atc4name $200 atc4code $200 dictname $200 dictver $200;

    subjid     = strip(C);
    tname      = strip(D);
    sn_num     = input(strip(E), ??best.);
    spid       = strip(F);
    cmtrt_term = strip(G);
    prefcname  = strip(J);
    atc2name   = strip(L);
    atc2code   = strip(M);
    atc4name   = strip(N);
    atc4code   = strip(O);
    dictname   = strip(R);
    dictver    = strip(S);

    if subjid ne "";
    keep subjid tname sn_num spid cmtrt_term
         prefcname atc2name atc2code atc4name atc4code
         dictname dictver;
run;

proc sort data=whodrug;
    by subjid tname sn_num spid cmtrt_term;
run;

%ut_remove_formats(lib=raw, dsin=CM, dsout=_cm0);

data cm_raw;
    set _cm0;
    length cmtrt_clean $200 cmstdat_c $20 cmendat_c $20;

    cmtrt_clean = strip(CMTRT);
    cmstdat_c   = strip(CMSTDAT);
    cmendat_c   = strip(CMENDAT);

    keep SID SUBJID TNAME SN CMTRT_clean
         CMSTDAT CMENDAT CMONGO
         CMINDC CMDSTXT CMDOSU CMDOSUO
         CMDOSFRM CMFRMOTH CMDOSFRQ CMFRQOTH
         CMROUTE CMROUTEO
         CMAENO CMMHNO CMINPL CMINOTH
         cmstdat_c cmendat_c;
run;

proc sort data=cm_raw;
    by SUBJID TNAME SN;
run;

proc sql;
    create table cm_whodrug as
    select a.*,
           b.prefcname as _cmdecod,
           b.atc2name  as _atc2,
           b.atc2code  as _atc2cd,
           b.atc4name  as _atc4,
           b.atc4code  as _atc4cd,
           catx(' ', b.dictname, b.dictver) as _cmdver
    from cm_raw a
    left join whodrug b
        on  a.SUBJID      = b.subjid
        and a.TNAME       = b.tname
        and a.SN          = b.sn_num
        and a.CMTRT_clean = b.cmtrt_term;
quit;

proc sql;
    create table cm_dm as
    select a.*, b.STUDYID, b.USUBJID
    from cm_whodrug a
    left join sdtm.dm b
        on a.SUBJID = b.SUBJID;
quit;

data cm_derived;
    set cm_dm;

    length DOMAIN $2 CMSPID $25 CMTRT $200 CMDECOD $200
           CMCAT $100 CMINDC $200 CMDOSTXT $100
           CMDOSU $20 CMDOSFRM $20 CMDOSFRQ $20 CMROUTE $20
           CMSTDTC $20 CMENDTC $20;

    DOMAIN = "CM";
    CMSPID = put(SN, best.);
    CMTRT  = cmtrt_clean;
    CMDECOD = _cmdecod;
    CMCAT   = "既往及合并用药";
    CMINDC  = strip(CMINDC);
    CMDOSTXT = strip(CMDSTXT);
    CMDOSU   = strip(CMDOSU);
    CMDOSFRM = strip(CMDOSFRM);
    CMDOSFRQ = strip(CMDOSFRQ);
    CMROUTE  = strip(CMROUTE);

    if not missing(cmstdat_c) then do;
        %ut_iso8601(datevar=cmstdat_c, dtcvar=CMSTDTC);
    end;
    if not missing(cmendat_c) then do;
        %ut_iso8601(datevar=cmendat_c, dtcvar=CMENDTC);
    end;

    length _cmaeno $200 _cmmhno $200 _cminpl $200 _cminoth $200
           _cmdosuo $200 _cmfrmoth $200 _cmfrqoth $200 _cmrouot $200
           _atc2 $200 _atc2cd $200 _atc4 $200 _atc4cd $200 _cmdver $200
           _cmongo $200;

    _cmaeno   = strip(CMAENO);
    _cmmhno   = strip(CMMHNO);
    _cminpl   = strip(CMINPL);
    _cminoth  = strip(CMINOTH);
    _cmdosuo  = strip(CMDOSUO);
    _cmfrmoth = strip(CMFRMOTH);
    _cmfrqoth = strip(CMFRQOTH);
    _cmrouot  = strip(CMROUTEO);
    _cmongo   = strip(CMONGO);
    _atc2     = _atc2;
    _atc2cd   = _atc2cd;
    _atc4     = _atc4;
    _atc4cd   = _atc4cd;
    _cmdver   = _cmdver;

    keep STUDYID DOMAIN USUBJID CMSPID CMTRT CMDECOD CMCAT
         CMINDC CMDOSTXT CMDOSU CMDOSFRM CMDOSFRQ CMROUTE
         CMSTDTC CMENDTC
         _cmaeno _cmmhno _cminpl _cminoth
         _cmdosuo _cmfrmoth _cmfrqoth _cmrouot _cmongo
         _atc2 _atc2cd _atc4 _atc4cd _cmdver;
run;

%ut_output_sdtm(domain=CM, dsin=cm_derived);

proc printto; run;
