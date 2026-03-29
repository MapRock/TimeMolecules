/*
With a list of cases that match to other cases via common event properties, we can
analyze whether two different case TYPES are related.
*/
;WITH ttl AS
(
	SELECT
		c.CaseTypeID,
		COUNT(*) AS TotalCaseCount
	FROM
		dbo.Cases c
	WHERE
		c.CaseTypeID IN (SELECT DISTINCT t.CaseTypeID FROM #tmp t)
	GROUP BY
		c.CaseTypeID
),
lnk AS
(
	SELECT
		t.CaseTypeID,
		MAX(t.CaseTypeDescription) AS CaseTypeDescription,
		t.LinkedCaseTypeID,
		MAX(t.LinkedCaseTypeDescription) AS LinkedCaseTypeDescription,
		COUNT(DISTINCT LinkedCaseID) AS LinkedCount,
		SUM(CASE WHEN t.CasesOverlap = 1 THEN 1 ELSE 0 END) AS OverlapCount,
		SUM(CASE WHEN t.CasesOverlap = 0 THEN 1 ELSE 0 END) AS NonOverlapCount
	FROM
		#tmp t
	GROUP BY
		t.CaseTypeID,
		t.LinkedCaseTypeID
)
SELECT
	l.CaseTypeID,
	l.CaseTypeDescription,
	ttl.TotalCaseCount,
	l.LinkedCaseTypeID,
	l.LinkedCaseTypeDescription,
	l.LinkedCount,
	ROUND(CAST(l.LinkedCount AS FLOAT) / NULLIF(ttl.TotalCaseCount,0),3)*100 AS LinkedPctOfCaseType,
	l.OverlapCount,
	l.NonOverlapCount,
	CAST(l.OverlapCount AS FLOAT) / NULLIF(l.LinkedCount,0) AS OverlapPctWithinLinkType
FROM
	lnk l
	JOIN ttl
		ON ttl.CaseTypeID = l.CaseTypeID
ORDER BY
	l.CaseTypeID,
	l.LinkedCount DESC,
	l.LinkedCaseTypeID;
