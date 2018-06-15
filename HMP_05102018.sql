-- Healthy Michigan- eligibility for the month of April, client open at any point in the month of April and services Provided to those clients in the month of April
-- Excluded the M2M and SUD ASAM Level 1- OP folks
--also need the cost for the services delivered.

USE DATAWMC;
WITH HMP AS
(
SELECT 
MEF_CLTID as HMPID,
CL_MAIDNO AS 'MCAID NO',
CL_LNAME + ' '+ CL_FNAME AS 'Client Name',
PR_NAME AS 'Level of care',
AD_FRMDT as 'Admission_Date',
ST_LNAME + ', ' + ST_FNAME as 'Case_Manager',
ME_ELGTP as 'Eligibility_type' 

FROM EDIMCEPF --Medicaid Eligibility table
LEFT JOIN PCHCLTPF ON MEF_CLTID = CL_RCDID -- Client table
LEFT JOIN PCHADMPF ON CL_RCDID = ADF_CLTID -- admissions table to get active admission
LEFT JOIN PCHALAPF ON ADF_ALAID = LA_RCDID -- location assignment related to admission
LEFT JOIN PCHPRVPF ON LAF_PRVID = PR_RCDID -- Provider to get Level of care
LEFT JOIN WMCPRVPF ON PRP_PRVID = PR_RCDID -- Local provider table to exclude M2M and SUD LOC's
LEFT JOIN PCHASAPF ON ADF_ASAID = SA_RCDID 
LEFT JOIN PCHSTFPF CASEMGR ON SAF_STFID = CASEMGR.ST_RCDID -- Staff Table to get primary staff , case manager
WHERE ME_ELGTP in ('G') -- healthy michigan
AND ME_OKUSE = 'Y'
  and ME_FRMDT >= '2018-04-01'  -- Only April Eligiblity 
  and ME_THRDT <= '2018-04-30'  -- Only April Eligiblity 
  and AD_FRMDT <= '2018-04-01'  -- Admission Open at any point in April
  and (AD_THRDT >= '2018-04-30' or AD_THRDT is null)
  and  (PR_DIRSUD is null or PR_DIRSUD = 'N') --- Excludes SUD Levels of Care 
  and  (PR_EXCENC is null or PR_EXCENC = 'N') --- Excludes Mild to Moderate Levels of Care

 ),
 Services_Provided AS (
SELECT 
funding.CO_SDESCR as 'Funding Source',
SAF_CLTID ,
SAF_PRVID,
SA_RCDID ,
SA_SRVDATE as 'Service Date', 
srv.CO_LDESCR as 'Service Description',
SA_UNITS as 'Units'
FROM PCHSALPF --SAL table
LEFT JOIN PCHCLTPF ON SAF_CLTID = CL_RCDID --Client table
LEFT JOIN PCHXSPPF ON  SAF_XSPID = XP_RCDID --CPT table
LEFT JOIN CODCODPF srv ON XPF_XWKID = srv.CO_RCDID
LEFT JOIN CODCODPF funding ON SAF_ACTMAP = funding.CO_RCDID
WHERE SA_SRVDATE BETWEEN '2018-04-01' AND '2018-04-30'
AND SA_OKTOUSE = 'Y'
AND SAF_ACTMAP = '15459' --healthy Michigan


),
Charges As(
SELECT 
PR_RCDID as ChargeID,
MAX(AD_FRMDT) as LastAdmDate,
SUM(CA_ADJQTY) as Units_Paid, 
CASE WHEN SUM(CA_ADJQTY) > 0 THEN SUM(CA_PAYAMT)/SUM(CA_ADJQTY)ELSE 0 END as UnitRate, 
sum(CA_PAYAMT) as Total_Paid

FROM EDICLDPF 
JOIN EDICLMPF A ON CDF_CLMID = A.CH_RCDID 
JOIN EDIBICPF ON CHF_BICID = BI_RCDID and BI_STS  in ('P') 
JOIN EDICLAPF ON CAF_CLDID = CD_RCDID 
LEFT JOIN  PCHAUDPF ON CDF_AUDID = AD_RCDID 
LEFT JOIN   EDICLMPF B ON A.CHF_CLMID = B.CH_RCDID 
LEFT JOIN   EDIBATPF on B.CHF_BATID = EB_RCDID 
LEFT JOIN   EDICAIPF ON  EDICLAPF.CAF_CAIID = EDICAIPF.CI_RCDID --claim account information 
LEFT JOIN PCHADMPF ON CDF_CLTID = ADF_CLTID 
	JOIN PCHCLTPF ON CDF_CLTID = CL_RCDID
LEFT JOIN PCHALAPF ON ADF_ALAID =LA_RCDID 
LEFT JOIN PCHPRVPF PRI ON LAF_PRVID = PRI.PR_RCDID
LEFT JOIN WMCPRVPF ON PRI.PR_RCDID = PRP_PRVID
GROUP BY PR_RCDID
)

select 
CL_CASENO,
[Client Name],
[Level of care],
[Admission_Date],
[Case_Manager],
CASE WHEN Eligibility_type = 'G' THEN 'Healthy Michigan'
	 WHEN Eligibility_type = 'J' THEN 'Healthy Michigan MCO'
END AS 'Eligibility_type',
CASE WHEN CL_STATUS = 'O' THEN 'Open'
     WHEN CL_STATUS = 'c' THEN 'Closed'
END AS 'Client_Status' ,
[Service Date],
[Service Description],
[Units],
Units_Paid,
UnitRate, 
Total_Paid 
--count(distinct CL_RCDID) as Count_of_Clients
from HMP
LEFT JOIN PCHCLTPF on HMPID = CL_RCDID
LEFT JOIN Services_Provided on CL_RCDID = SAF_CLTID
left JOIN Charges on SAF_PRVID = ChargeID
LEFT JOIN PCHPRVPF PRI ON ChargeID = PRI.PR_RCDID
LEFT JOIN WMCPRVPF ON PRI.PR_RCDID = PRP_PRVID
where CL_STATUS = 'O'
and  (PR_DIRSUD is null or PR_DIRSUD = 'N') --- Excludes SUD Levels of Care 
  and  (PR_EXCENC is null or PR_EXCENC = 'N') --- Excludes Mild to Moderate Levels of Care
